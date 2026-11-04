"""Eskiz va Google'ni admin paneldan sozlash.

Talablar:

- Panelda qo'yilgan Eskiz hisobi serverni qayta ishga tushirmasdan keyingi
  OTP'dan boshlab ishlasin — `.env` dagi hisob yo'q bo'lsa ham.
- Noto'g'ri hisob yoki Eskiz bilan aloqa yo'qligi **saqlashdan oldin**
  aytilsin va hech narsa saqlanmasin.
- Parol hech qachon qaytarilmasin.
- Eskiz ulangach productionda telefon orqali kirish hamma uchun ochilsin.
- Google: Android ID yolg'iz tugmani yoqmasin; web ID mijozlarga beriladi,
  Android ID faqat qabul qilinadigan auditoriyada turadi.

Ilova jarayon ichida (ASGI) chaqiriladi, chunki Eskiz soxta server bilan
almashtiriladi. Baza — umumiy sinov bazasi; oxirida sozlamalar tozalanadi.
"""

import asyncio
import sys
from pathlib import Path
from urllib.parse import parse_qs

import httpx
from sqlalchemy import select

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.core.config import settings  # noqa: E402
from app.db.session import SessionLocal, engine  # noqa: E402
from app.main import app  # noqa: E402
from app.models.user import User  # noqa: E402
from app.services import google_clients, settings_store, sms  # noqa: E402

MODERATOR_PHONE = "+998901234122"
USER_PHONE = "+998901234123"
ANDROID_ID = "299383835355-bpv12h6ija8ju4gnuakr5o2v6et9jhv6.apps.googleusercontent.com"
WEB_ID = "299383835355-webclientabc123.apps.googleusercontent.com"

failures = 0


def check(name: str, ok: bool, detail: str = "") -> None:
    global failures
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else f" — {detail}"))
    if not ok:
        failures += 1


class FakeEskiz:
    def __init__(self, *, refuse_login: bool = False, offline: bool = False) -> None:
        self.refuse_login = refuse_login
        self.offline = offline
        self.logins: list[dict] = []
        self.sends: list[dict] = []

    def handler(self, request: httpx.Request) -> httpx.Response:
        if self.offline:
            raise httpx.ConnectError("offline", request=request)
        body = {k: v[0] for k, v in parse_qs(request.content.decode()).items()}
        if request.url.path.endswith("/auth/login"):
            self.logins.append(body)
            if self.refuse_login:
                return httpx.Response(401, json={"message": "Invalid credentials"})
            return httpx.Response(200, json={"data": {"token": f"tok-{len(self.logins)}"}})
        if request.url.path.endswith("/message/sms/send"):
            self.sends.append(body)
            return httpx.Response(200, json={"status": "waiting"})
        return httpx.Response(404)


def use(fake: FakeEskiz) -> FakeEskiz:
    sms.TRANSPORT = httpx.MockTransport(fake.handler)
    return fake


async def clean() -> None:
    async with SessionLocal() as db:
        await settings_store.drop(db, settings_store.ESKIZ)
        await settings_store.drop(db, settings_store.GOOGLE_CLIENT)
        await db.commit()


ESKIZ = {
    "email": "ops@mab.uz",
    "password": "very-secret-eskiz-password",
    "sender": "MAB",
    "otp_template": "MAB kodi: {code}",
}


async def run() -> None:
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://admin") as c:
        r = await c.post("/auth/otp/request", json={"phone": MODERATOR_PHONE})
        code = r.json()["debug_code"]
        r = await c.post("/auth/otp/verify", json={"phone": MODERATOR_PHONE, "code": code})
        h = {"Authorization": "Bearer " + r.json()["access_token"]}
        async with SessionLocal() as db:
            mod = await db.scalar(select(User).where(User.phone == MODERATOR_PHONE))
            mod.is_moderator = True
            await db.commit()

        # --- ruxsat -----------------------------------------------------
        r = await c.get("/admin/sms")
        check("tokensiz /admin/sms yopiq", r.status_code in (401, 403), str(r.status_code))

        r = await c.get("/admin/sms", headers=h)
        check("boshlanishida Eskiz ulanmagan", r.status_code == 200 and r.json()["ready"] is False, r.text)

        # --- saqlashdan oldingi tekshiruvlar --------------------------------
        r = await c.put("/admin/sms", headers=h, json={**ESKIZ, "otp_template": "kod yo'q"})
        check("{code}siz shablon rad etiladi", r.status_code == 422, r.text)

        r = await c.put("/admin/sms", headers=h, json={**ESKIZ, "otp_template": "{code} " + "x" * 200})
        check("160 belgidan uzun shablon rad etiladi", r.status_code == 422, r.text)

        refusing = use(FakeEskiz(refuse_login=True))
        r = await c.put("/admin/sms", headers=h, json=ESKIZ)
        check("noto'g'ri parol 400", r.status_code == 400, r.text)
        check("Eskiz'ga login qilib ko'rildi", len(refusing.logins) == 1)
        r = await c.get("/admin/sms", headers=h)
        check("rad etilgan hisob saqlanmadi", r.json()["ready"] is False, r.text)

        use(FakeEskiz(offline=True))
        r = await c.put("/admin/sms", headers=h, json=ESKIZ)
        check("Eskiz bilan aloqa yo'q — 502", r.status_code == 502, r.text)
        r = await c.get("/admin/sms", headers=h)
        check("aloqasiz holatda saqlanmadi", r.json()["ready"] is False, r.text)

        # --- saqlash ----------------------------------------------------------
        fake = use(FakeEskiz())
        r = await c.put("/admin/sms", headers=h, json=ESKIZ)
        check("to'g'ri hisob saqlandi", r.status_code == 200 and r.json()["ready"] is True, r.text)
        check("manba — panel", r.json()["source"] == "panel", r.text)
        check("parol javobda yo'q", ESKIZ["password"] not in r.text, r.text)
        check("email yashirilgan", ESKIZ["email"] not in r.text and r.json()["email_hint"], r.text)
        check("login email bilan ketdi", fake.logins[-1]["email"] == ESKIZ["email"])

        r = await c.get("/admin/sms", headers=h)
        check("GET da ham parol yo'q", ESKIZ["password"] not in r.text, r.text)

        # --- OTP endi panel hisobi bilan ketadi --------------------------------
        r = await c.post("/auth/otp/request", json={"phone": USER_PHONE})
        check("OTP so'rovi ishlaydi", r.status_code == 200, r.text)
        check("sent=true", r.json()["sent"] is True, r.text)
        check("SMS Eskiz'ga ketdi", len(fake.sends) == 1, str(fake.sends))
        sent = fake.sends[-1] if fake.sends else {}
        check("raqam plyussiz", sent.get("mobile_phone") == USER_PHONE.lstrip("+"), str(sent))
        check("panel jo'natuvchisi", sent.get("from") == "MAB", str(sent))
        debug = r.json().get("debug_code") or ""
        check("panel shabloni", sent.get("message") == f"MAB kodi: {debug}", str(sent))

        await c.post("/auth/otp/request", json={"phone": "+998901234124"})
        check("ikkinchi SMS qayta login qilmaydi", len(fake.logins) == 1, str(len(fake.logins)))

        # --- sinov SMS ----------------------------------------------------------
        r = await c.post("/admin/sms/test", headers=h, json={"phone": "+998901112233"})
        check("sinov SMS yuborildi", r.status_code == 200 and fake.sends[-1]["mobile_phone"] == "998901112233", r.text)
        r = await c.post("/admin/sms/test", headers=h, json={"phone": "901112233"})
        check("noto'g'ri raqam rad etiladi", r.status_code == 422, r.text)

        # --- hisob almashtirilsa yangi token olinadi ----------------------------
        new = use(FakeEskiz())
        await c.put("/admin/sms", headers=h, json={**ESKIZ, "password": "another-password"})
        await c.post("/auth/otp/request", json={"phone": "+998901234125"})
        check("yangi hisob bilan yuborildi", len(new.sends) == 1 and new.sends[0]["mobile_phone"] == "998901234125", str(new.sends))

        # --- productionda: panel kaliti bilan hamma uchun ochiq -----------------
        saved = (settings.app_env, settings.sms_optional, settings.sms_optional_phones)
        settings.app_env = "production"
        settings.sms_optional = True
        settings.sms_optional_phones = ()
        try:
            r = await c.get("/auth/methods")
            check("production + panel kaliti: telefon ochiq", r.json()["phone"] is True, r.text)
            r = await c.post("/auth/otp/request", json={"phone": "+998901234126"})
            check("production: istalgan raqamga kod ketadi", r.status_code == 200, r.text)

            use(FakeEskiz(offline=True))
            r = await c.post("/auth/otp/request", json={"phone": "+998901234127"})
            check("production: Eskiz yiqilsa 503, jim emas", r.status_code == 503, r.text)
            use(new)

            await c.delete("/admin/sms", headers=h)
            r = await c.get("/auth/methods")
            check("production, kalitsiz: telefon yopiq", r.json()["phone"] is False, r.text)
            r = await c.post("/auth/otp/request", json={"phone": "+998901234128"})
            check("production, kalitsiz: 503", r.status_code == 503, r.text)
        finally:
            settings.app_env, settings.sms_optional, settings.sms_optional_phones = saved

        r = await c.get("/admin/sms", headers=h)
        check("olib tashlangach ulanmagan", r.json()["ready"] is False, r.text)
        r = await c.post("/auth/otp/request", json={"phone": "+998901234129"})
        check("quruq rejimga qaytdi", r.status_code == 200 and r.json()["debug_code"], r.text)

        # --- Google -------------------------------------------------------------
        r = await c.get("/admin/google", headers=h)
        g = r.json()
        check("Android ID standart qo'yilgan", ANDROID_ID in g["android_client_ids"], r.text)
        check("web ID .env dan", g["web_client_id"] == settings.google_client_ids[0], r.text)

        r = await c.get("/auth/methods")
        check("mijozga Android ID berilmaydi", r.json()["google_client_id"] != ANDROID_ID, r.text)

        r = await c.put("/admin/google", headers=h, json={"web_client_id": "salom"})
        check("noto'g'ri ID rad etiladi", r.status_code == 422, r.text)
        r = await c.put("/admin/google", headers=h, json={"web_client_id": ANDROID_ID, "android_client_ids": [ANDROID_ID]})
        check("bir ID ham web, ham Android — rad", r.status_code == 422, r.text)

        r = await c.put("/admin/google", headers=h, json={"web_client_id": WEB_ID, "android_client_ids": [ANDROID_ID]})
        check("Google ID'lar saqlandi", r.status_code == 200 and r.json()["source"] == "panel", r.text)
        r = await c.get("/auth/methods")
        check("tugma panel web ID'si bilan", r.json()["google"] is True and r.json()["google_client_id"] == WEB_ID, r.text)

        async with SessionLocal() as db:
            clients = await google_clients.resolve(db)
        check("auditoriyada web va Android", WEB_ID in clients.audience and ANDROID_ID in clients.audience, str(clients))

        saved_ids = settings.google_client_ids
        settings.google_client_ids = ()
        try:
            await c.put("/admin/google", headers=h, json={"web_client_id": None, "android_client_ids": [ANDROID_ID]})
            r = await c.get("/auth/methods")
            check("faqat Android ID — tugma yo'q", r.json()["google"] is False, r.text)
            r = await c.post("/auth/google", json={"id_token": "x" * 40})
            check("faqat Android ID — /auth/google 503", r.status_code == 503, r.text)
        finally:
            settings.google_client_ids = saved_ids

    sms.TRANSPORT = None
    await clean()
    await engine.dispose()


async def main() -> None:
    await clean()
    try:
        await run()
    finally:
        sms.TRANSPORT = None
        await clean()


asyncio.run(main())
print(f"\n{'OK' if not failures else f'{failures} ta xato'}")
sys.exit(1 if failures else 0)
