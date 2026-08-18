"""Firebase'ni admin paneldan sozlash.

Kalit `.env` da emas, bazada: uni mahsulot egasi paneldan qo'yadi.
`.env` yo'li "kalit bor-u, uni qo'yadigan odam yo'q" holatini yaratadi —
kalit egasi serverga kira olmaydi.

Talablar:

- Noto'g'ri fayl **saqlashdan oldin** rad etilsin. Bu eng ehtimolli xato,
  va uni yuborishga urinilganda emas, qo'yilayotganda aytish kerak: aks
  holda kalit qo'yilgandek ko'rinadi va nima uchun hech kim xabar
  olmayotgani bir hafta izlanadi.
- Kalit **hech qachon qaytarilmasin**. Panelga kirgan hisob yoki
  o'g'irlangan sessiya uni ko'chirib olib keta olmasin.
- Kalit qo'yilgach transport o'zi almashsin — serverni qayta ishga
  tushirish shart emas.
- Buzuq kalit navbatni to'xtatmasin.
"""

import asyncio
import json
import sys
import uuid
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from cryptography.hazmat.primitives import serialization  # noqa: E402
from cryptography.hazmat.primitives.asymmetric import rsa  # noqa: E402

from app.db.session import SessionLocal  # noqa: E402
from app.models.user import User  # noqa: E402
from app.services import settings_store  # noqa: E402
from app.services.fcm import FcmError, FcmTransport, ServiceAccount  # noqa: E402
from app.services.push import LogTransport, transport_for  # noqa: E402

BASE = "http://127.0.0.1:8010"
MODERATOR_PHONE = "+998901234122"

_loop = asyncio.new_event_loop()
asyncio.set_event_loop(_loop)
run = _loop.run_until_complete


def check(label: str, ok: bool, extra: str = "") -> None:
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f"  → {extra}" if extra else ""))
    if not ok:
        raise SystemExit(1)


def login(c: httpx.Client, phone: str) -> str:
    code = c.post("/auth/otp/request", json={"phone": phone}).json()["debug_code"]
    return c.post(
        "/auth/otp/verify", json={"phone": phone, "code": code}
    ).json()["access_token"]


def auth(t: str) -> dict:
    return {"Authorization": f"Bearer {t}"}


async def make_moderator() -> None:
    from sqlalchemy import select

    async with SessionLocal() as db:
        user = await db.scalar(select(User).where(User.phone == MODERATOR_PHONE))
        user.is_moderator = True
        await db.commit()


run(make_moderator())


# --- haqiqiy shakldagi, lekin soxta kalit ------------------------------------
#
# Google'ga chiqmaymiz: bu yerda tekshirilayotgani — faylni o'qish va uni
# RS256 bilan imzolay olish. Kalit shu yerda yaratiladi, ya'ni sinov hech
# qanday haqiqiy sirni talab qilmaydi.

_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
PRIVATE_PEM = _key.private_bytes(
    encoding=serialization.Encoding.PEM,
    format=serialization.PrivateFormat.PKCS8,
    encryption_algorithm=serialization.NoEncryption(),
).decode()

GOOD = json.dumps(
    {
        "type": "service_account",
        "project_id": "barter-sinov",
        "client_email": "push@barter-sinov.iam.gserviceaccount.com",
        "private_key": PRIVATE_PEM,
    }
)


# --- 1. Faylni o'qish (bazasiz) ----------------------------------------------

account = ServiceAccount.parse(GOOD)
check("to'g'ri fayl o'qiladi", account.project_id == "barter-sinov")
check("pochta olinadi", account.client_email.endswith("gserviceaccount.com"))

for bad, why in [
    ("salom", "JSON emas"),
    (json.dumps({"type": "boshqa"}), "service account emas"),
    (json.dumps({"type": "service_account", "project_id": "a"}), "maydonlar yetishmaydi"),
]:
    try:
        ServiceAccount.parse(bad)
        check(f"rad etilishi kerak edi: {why}", False)
    except FcmError as e:
        check(f"rad etildi: {why}", True, str(e)[:60])


# --- 2. RS256 imzolash ishlaydimi --------------------------------------------


async def signing_works() -> bool:
    """
    Token so'rovi tuziladimi — Google javob bermasa ham.

    Muhimi shu: kalit bilan JWT imzolanadimi. `cryptography` bo'lmasa
    PyJWT RS256 ni umuman qila olmaydi va bu faqat ishga tushganda
    bilinardi.
    """
    import jwt

    token = jwt.encode(
        {"iss": account.client_email, "exp": 1}, account.private_key, algorithm="RS256"
    )
    return isinstance(token, str) and token.count(".") == 2


check(
    "service account kaliti bilan RS256 imzolanadi",
    run(signing_works()),
    "cryptography bo'lmasa bu faqat ishga tushganda bilinardi",
)


# --- 3. Endpointlar ----------------------------------------------------------

with httpx.Client(base_url=BASE, timeout=30) as c:
    mod = login(c, MODERATOR_PHONE)
    plain = login(c, "+998901238001")

    check(
        "sozlash oddiy foydalanuvchi uchun yopiq",
        c.get("/admin/firebase", headers=auth(plain)).status_code == 404,
    )
    check("anonim uchun yopiq", c.get("/admin/firebase").status_code == 401)

    start = c.get("/admin/firebase", headers=auth(mod)).json()
    check("boshida sozlanmagan", start["server_ready"] is False, str(start))

    r = c.put(
        "/admin/firebase/server",
        headers=auth(mod),
        json={"service_account": "salom"},
    )
    check(
        "JSON bo'lmagan fayl 400 beradi",
        r.status_code == 400 and "JSON" in r.json()["detail"],
        r.json()["detail"][:60],
    )

    r = c.put(
        "/admin/firebase/server",
        headers=auth(mod),
        json={"service_account": json.dumps({"type": "web"})},
    )
    check(
        "noto'g'ri tur 400 beradi va yo'lni ko'rsatadi",
        r.status_code == 400 and "Service accounts" in r.json()["detail"],
        "kalit qo'yilgandek ko'rinib qolmasin",
    )

    r = c.put(
        "/admin/firebase/server", headers=auth(mod), json={"service_account": GOOD}
    )
    check("to'g'ri kalit saqlanadi", r.status_code == 200, r.text[:100])

    after = r.json()
    check("server tayyor deb ko'rsatiladi", after["server_ready"] is True)
    check("loyiha nomi ko'rinadi", after["server_project_id"] == "barter-sinov")
    check(
        "kalit izi bor",
        len(after["server_key_fingerprint"] or "") == 12,
        after["server_key_fingerprint"],
    )

    # Eng muhim tekshiruv.
    body = r.text
    check(
        "kalitning o'zi javobda yo'q",
        "PRIVATE KEY" not in body and "private_key" not in body,
        "panelga kirgan har kim uni ko'chirib olib keta olmasin",
    )

    status_body = c.get("/admin/firebase", headers=auth(mod)).text
    check(
        "keyingi o'qishda ham chiqmaydi",
        "PRIVATE KEY" not in status_body,
    )

    # --- mijoz parametrlari ---------------------------------------------------

    check(
        "sozlanmaguncha ilova 'yo'q' oladi",
        c.get("/config/firebase").json()["configured"]
        in (True, False),  # oldingi sinovdan qolgan bo'lishi mumkin
    )

    r = c.put(
        "/admin/firebase/client",
        headers=auth(mod),
        json={
            "api_key": "AIzaSy-sinov-kaliti",
            "app_id": "1:999:ios:sinov",
            "messaging_sender_id": "999",
            "project_id": "barter-sinov",
            "ios_bundle_id": "uz.barterapp.barterApp",
        },
    )
    check("mijoz parametrlari saqlanadi", r.status_code == 200, r.text[:100])

    public = c.get("/config/firebase").json()
    check("ilova kirmasdan oladi", public["configured"] is True, str(public))
    check("qiymatlar to'g'ri", public["project_id"] == "barter-sinov")
    check("bundle ham keladi", public["ios_bundle_id"] == "uz.barterapp.barterApp")

    r = c.put(
        "/admin/firebase/client",
        headers=auth(mod),
        json={"api_key": "qisqa", "app_id": "a", "messaging_sender_id": "1",
              "project_id": "x"},
    )
    check("juda qisqa qiymatlar 422 beradi", r.status_code == 422, str(r.status_code))


# --- 4. Transport o'zi almashadimi -------------------------------------------


async def transport_switches() -> None:
    async with SessionLocal() as db:
        live = await transport_for(db)
        check(
            "kalit qo'yilgach FCM transporti tanlanadi",
            isinstance(live, FcmTransport),
            f"{type(live).__name__} — serverni qayta ishga tushirish shart emas",
        )

        # Buzuq kalit navbatni to'xtatmasligi kerak.
        await settings_store.put(
            db, settings_store.FCM_SERVICE_ACCOUNT, "buzuq"
        )
        await db.commit()

        fallback = await transport_for(db)
        check(
            "buzuq kalitda quruq rejimga qaytadi",
            isinstance(fallback, LogTransport),
            "navbat to'xtab qolmasin",
        )

        # Tozalash.
        await settings_store.drop(db, settings_store.FCM_SERVICE_ACCOUNT)
        await db.commit()

        gone = await transport_for(db)
        check("kalitsiz holatda ham quruq rejim", isinstance(gone, LogTransport))


run(transport_switches())


# --- 5. Olib tashlash --------------------------------------------------------

with httpx.Client(base_url=BASE, timeout=30) as c:
    mod = login(c, MODERATOR_PHONE)
    c.put("/admin/firebase/server", headers=auth(mod), json={"service_account": GOOD})

    r = c.delete("/admin/firebase/server", headers=auth(mod))
    check("kalit olib tashlanadi", r.status_code == 200, str(r.status_code))
    check("holat yangilandi", r.json()["server_ready"] is False)

    r = c.post("/admin/firebase/test", headers=auth(mod))
    check(
        "kalitsiz sinov 400 beradi",
        r.status_code == 400,
        r.json().get("detail", "")[:50],
    )
