"""Xavfsizlik zondi — himoyani buzishga urinadi.

Bu sinov boshqalardan farq qiladi: qolganlari to'g'ri ishlashni
tekshiradi, bu esa **noto'g'ri ishlamasligini**. Har bir tekshiruv
haqiqiy hujum urinishi va u muvaffaqiyatsiz tugashi shart.

Qamrov: IDOR, mass assignment, JWT bilan o'ynash, huquq oshirish,
enumeratsiya, blokni chetlab o'tish, o'chirilgan hisob, admin chegarasi.
"""

import asyncio
import sys
import uuid
from pathlib import Path

import httpx
import jwt

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.core.config import settings  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402
from app.models.user import User  # noqa: E402

BASE = "http://127.0.0.1:8010"
MODERATOR_PHONE = "+998901234122"

_loop = asyncio.new_event_loop()
asyncio.set_event_loop(_loop)
run = _loop.run_until_complete

FAILURES: list[str] = []


def check(label: str, ok: bool, extra: str = "") -> None:
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f"  → {extra}" if extra else ""))
    if not ok:
        FAILURES.append(label)


def login(c: httpx.Client, phone: str) -> tuple[str, str, str]:
    code = c.post("/auth/otp/request", json={"phone": phone}).json()["debug_code"]
    body = c.post("/auth/otp/verify", json={"phone": phone, "code": code}).json()
    me = c.get(
        "/me", headers={"Authorization": f"Bearer {body['access_token']}"}
    ).json()
    return body["access_token"], body["refresh_token"], me["id"]


def auth(t: str) -> dict:
    return {"Authorization": f"Bearer {t}"}


def tri(v: str) -> dict:
    return {"uz": v, "ru": v, "en": v}


def new_listing(c: httpx.Client, token: str, title: str = "Zond") -> str:
    r = c.post(
        "/listings",
        headers=auth(token),
        json={
            "tag": "agri",
            "title": tri(title),
            "description": tri("Sinov"),
            "image_alt": tri("Sinov"),
            "category": tri("Sinov"),
            "condition": tri("Yangi"),
            "quantity": tri("1 dona"),
            "wants_summary": tri("Nimadir"),
            "wants": [tri("Nimadir")],
            "desires": [{"category": None, "will_add_cash": True, "wants_cash": False}],
            "photos": [],
            "value": {"minor": 100000000, "currency": "UZS"},
            "cash_ok": True,
        },
    )
    assert r.status_code == 201, r.text[:200]
    return r.json()["id"]


def phone(prefix: str) -> str:
    return f"+998{prefix}{uuid.uuid4().int % 10_000_000:07d}"


async def make_moderator() -> None:
    from sqlalchemy import select

    async with SessionLocal() as db:
        user = await db.scalar(select(User).where(User.phone == MODERATOR_PHONE))
        user.is_moderator = True
        await db.commit()


run(make_moderator())

ALICE = phone("90")
MALLORY = phone("91")

with httpx.Client(base_url=BASE, timeout=30) as c:
    alice, alice_refresh, alice_id = login(c, ALICE)
    mallory, mallory_refresh, mallory_id = login(c, MALLORY)
    mod, _, mod_id = login(c, MODERATOR_PHONE)

    print("\n--- 1. JWT bilan o'ynash ---")

    # `alg: none` — klassik hujum.
    forged = jwt.encode({"sub": alice_id, "typ": "access"}, "", algorithm="none")
    check(
        "alg=none rad etiladi",
        c.get("/me", headers=auth(forged)).status_code == 401,
    )

    # Boshqa kalit bilan imzolangan token.
    wrong = jwt.encode(
        {"sub": alice_id, "typ": "access", "exp": 9999999999},
        "boshqa-kalit",
        algorithm="HS256",
    )
    check(
        "boshqa kalit bilan imzolangan token rad etiladi",
        c.get("/me", headers=auth(wrong)).status_code == 401,
    )

    # Token turini almashtirish: refresh tokenni access sifatida ishlatish.
    check(
        "refresh token access o'rnida ishlamaydi",
        c.get("/me", headers=auth(alice_refresh)).status_code == 401,
        "typ tekshiruvi",
    )

    # Soket chiptasi ham access emas.
    ticket = c.get("/ws-ticket", headers=auth(alice)).json()["ticket"]
    check(
        "soket chiptasi API uchun ishlamaydi",
        c.get("/me", headers=auth(ticket)).status_code == 401,
    )

    # `sub` ni boshqa odamga almashtirib, haqiqiy kalit bilan imzolash
    # mumkin emasligini tasdiqlaymiz (kalit bizda yo'q — bu shunchaki
    # imzoning tekshirilishini isbotlaydi).
    payload = jwt.decode(alice, options={"verify_signature": False})
    payload["sub"] = mallory_id
    tampered = jwt.encode(payload, "taxmin", algorithm="HS256")
    check(
        "sub almashtirilgan token rad etiladi",
        c.get("/me", headers=auth(tampered)).status_code == 401,
    )

    print("\n--- 2. Mass assignment (huquq oshirish) ---")

    for field, value in [
        ("is_moderator", True),
        ("trust_score", 100),
        ("is_verified", True),
        ("free_listings_left", 9999),
        ("deleted_at", None),
    ]:
        c.patch("/me", headers=auth(mallory), json={field: value})

    me = c.get("/me", headers=auth(mallory)).json()
    check(
        "PATCH /me moderator huquqini bermaydi",
        c.get("/admin/reports", headers=auth(mallory)).status_code == 404,
    )
    check("trust_score o'zboshimchalik bilan o'zgarmaydi", me["trust_score"] < 100, str(me["trust_score"]))
    check("is_verified o'zboshimchalik bilan yoqilmaydi", me["is_verified"] is False)

    print("\n--- 3. IDOR: birovning ma'lumoti ---")

    alice_listing = new_listing(c, alice, "Alisa buyumi")
    mallory_listing = new_listing(c, mallory, "Mallori buyumi")

    # Birovning e'lonini tahrirlash.
    r = c.patch(
        f"/listings/{alice_listing}",
        headers=auth(mallory),
        json={"title": tri("O'g'irlandi")},
    )
    check("birovning e'loni tahrirlanmaydi", r.status_code == 404, str(r.status_code))

    r = c.delete(f"/listings/{alice_listing}", headers=auth(mallory))
    check("birovning e'loni o'chirilmaydi", r.status_code == 404, str(r.status_code))

    # Taklif yaratamiz va uchinchi tomon unga tegishga urinadi.
    offer = c.post(
        "/offers",
        headers=auth(mallory),
        json={
            "listing_id": alice_listing,
            "offered_listing_ids": [mallory_listing],
            "cash_delta_minor": 0,
            "currency": "UZS",
            "message": "Maxfiy xabar",
        },
    )
    check("taklif yaratildi", offer.status_code == 201, offer.text[:120])
    offer_id = offer.json()["id"]

    eve, _, eve_id = login(c, phone("92"))

    r = c.get(f"/offers/{offer_id}", headers=auth(eve))
    check("uchinchi tomon taklifni ko'ra olmaydi", r.status_code == 404, str(r.status_code))

    r = c.patch(f"/offers/{offer_id}", headers=auth(eve), json={"action": "accept"})
    check("uchinchi tomon taklifni qabul qila olmaydi", r.status_code == 404)

    # O'z taklifini o'zi qabul qilish.
    r = c.patch(f"/offers/{offer_id}", headers=auth(mallory), json={"action": "accept"})
    check(
        "yuboruvchi o'z taklifini qabul qila olmaydi",
        r.status_code == 409,
        f"{r.status_code} — aks holda savdo bir tomonlama yakunlanardi",
    )

    # Suhbat.
    threads = c.get("/conversations", headers=auth(alice)).json()
    thread_id = threads[0]["id"]

    r = c.get(f"/conversations/{thread_id}", headers=auth(eve))
    check("uchinchi tomon suhbatni o'qiy olmaydi", r.status_code == 404, str(r.status_code))

    r = c.post(
        f"/conversations/{thread_id}/messages",
        headers=auth(eve),
        json={"body": "Aralashdim"},
    )
    check("uchinchi tomon suhbatga yoza olmaydi", r.status_code == 404)

    # Bildirishnomalar — faqat o'ziniki.
    notes = c.get("/notifications", headers=auth(eve)).json()
    check(
        "bildirishnomalar aralashmaydi",
        all("Maxfiy" not in (n.get("body") or "") for n in notes),
        f"{len(notes)} ta",
    )

    print("\n--- 4. Sharh soxtalashtirish ---")

    r = c.post(
        "/reviews",
        headers=auth(eve),
        json={"offer_id": offer_id, "rating": 1, "body": "Yomon"},
    )
    check(
        "qatnashmagan savdoga sharh yozilmaydi",
        r.status_code == 404,
        f"{r.status_code} — reyting soxtalashtirilmasin",
    )

    r = c.post(
        "/reviews",
        headers=auth(alice),
        json={"offer_id": offer_id, "rating": 5, "body": "Yaxshi"},
    )
    check(
        "yakunlanmagan savdoga sharh yozilmaydi",
        r.status_code == 409,
        str(r.status_code),
    )

    print("\n--- 5. Blokni chetlab o'tish ---")

    c.post(f"/blocks/{mallory_id}", headers=auth(alice))

    r = c.post(
        "/offers",
        headers=auth(mallory),
        json={
            "listing_id": alice_listing,
            "offered_listing_ids": [mallory_listing],
            "cash_delta_minor": 0,
            "currency": "UZS",
        },
    )
    check("bloklangan tomon taklif yubora olmaydi", r.status_code == 403, str(r.status_code))

    r = c.post(
        f"/conversations/{thread_id}/messages",
        headers=auth(mallory),
        json={"body": "Blokdan keyin"},
    )
    check("bloklangan tomon xabar yoza olmaydi", r.status_code == 403, str(r.status_code))

    r = c.post(f"/listings/{alice_listing}/favorite", headers=auth(mallory))
    check("bloklangan tomon saqlay olmaydi", r.status_code == 403, str(r.status_code))

    c.delete(f"/blocks/{mallory_id}", headers=auth(alice))

    print("\n--- 6. Admin chegarasi ---")

    for path, method in [
        ("/admin/reports", "GET"),
        ("/admin/feed-blocks", "GET"),
        ("/admin/analytics/funnel", "GET"),
        ("/admin/push/status", "GET"),
        ("/admin/firebase", "GET"),
    ]:
        r = c.request(method, path, headers=auth(mallory))
        check(
            f"{path} moderatorsiz yopiq",
            r.status_code == 404,
            f"{r.status_code} — 403 API borligini oshkor qilardi",
        )

    # Kalit hech qachon qaytmasin.
    fb = c.get("/admin/firebase", headers=auth(mod))
    check(
        "Firebase kaliti javobda yo'q",
        "PRIVATE KEY" not in fb.text and '"private_key"' not in fb.text,
        "panelga kirgan hisob kalitni ololmasin",
    )

    print("\n--- 7. Enumeratsiya ---")

    known = c.post("/auth/otp/request", json={"phone": ALICE})
    unknown = c.post("/auth/otp/request", json={"phone": phone("93")})
    check(
        "mavjud va mavjud bo'lmagan raqam bir xil javob beradi",
        known.status_code == unknown.status_code,
        f"{known.status_code} / {unknown.status_code} — raqamni aniqlab bo'lmasin",
    )

    bad = c.post("/auth/otp/verify", json={"phone": ALICE, "code": "000000"})
    check(
        "noto'g'ri kod umumiy xato beradi",
        bad.status_code in (400, 429),
        str(bad.status_code),
    )

    print("\n--- 8. Kirish oqimi ---")

    r = c.post("/auth/otp/request", json={"phone": "12345"})
    check("noto'g'ri raqam shakli rad etiladi", r.status_code == 422, str(r.status_code))

    # Rate limit.
    codes = [
        c.post("/auth/otp/request", json={"phone": ALICE}).status_code
        for _ in range(8)
    ]
    check(
        "OTP so'rovi cheklanadi",
        429 in codes,
        f"{codes} — aks holda cheksiz SMS yuborish mumkin bo'lardi",
    )

    print("\n--- 9. O'chirilgan hisob ---")

    doomed, doomed_refresh, doomed_id = login(c, phone("94"))
    c.request("DELETE", "/me", headers=auth(doomed), json={"confirm": True})

    check(
        "o'chirilgan hisob tokeni ishlamaydi",
        c.get("/me", headers=auth(doomed)).status_code == 401,
    )
    check(
        "o'chirilgan hisob refresh qila olmaydi",
        c.post("/auth/refresh", json={"refresh_token": doomed_refresh}).status_code == 401,
    )
    check(
        "o'chirilgan hisob e'lon joylay olmaydi",
        c.post("/listings", headers=auth(doomed), json={}).status_code == 401,
    )

    print("\n--- 10. Kirish talab qiladigan yo'llar ---")

    protected = [
        ("GET", "/me"), ("PATCH", "/me"), ("GET", "/me/listings"),
        ("POST", "/listings"), ("GET", "/offers"), ("POST", "/offers"),
        ("GET", "/conversations"), ("GET", "/notifications"),
        ("GET", "/matches"), ("GET", "/favorites"), ("GET", "/blocks"),
        ("POST", "/reports"), ("POST", "/devices"),
        ("GET", "/notification-settings"), ("GET", "/ws-ticket"),
        ("POST", "/uploads"),
    ]
    leaks = [
        f"{m} {p}"
        for m, p in protected
        if c.request(m, p, json={}).status_code != 401
    ]
    check(
        "himoyalangan yo'llarning hammasi 401 beradi",
        not leaks,
        ", ".join(leaks) if leaks else f"{len(protected)} ta yo'l tekshirildi",
    )

    print("\n--- 11. Media va yo'l bilan o'ynash ---")

    for path in [
        "/media/../app/core/config.py",
        "/media/..%2F..%2Fetc%2Fpasswd",
        "/media/%2e%2e%2f%2e%2e%2fetc%2fpasswd",
    ]:
        r = c.get(path)
        check(
            f"yo'l bilan chiqib bo'lmaydi: {path[:34]}",
            r.status_code in (403, 404) or "DATABASE_URL" not in r.text,
            str(r.status_code),
        )

    print("\n--- 12. Kirish nazorati: boshqaning qurilmasi ---")

    token_a = f"probe-{uuid.uuid4().hex}"
    c.post("/devices", headers=auth(alice), json={"token": token_a, "platform": "ios"})
    r = c.delete(f"/devices/{token_a}", headers=auth(mallory))
    check("boshqaning qurilmasi o'chmaydi", r.status_code == 204)

    still = c.post(
        "/admin/push/status", headers=auth(mod)
    ) if False else c.get("/admin/push/status", headers=auth(mod)).json()
    check("qurilma joyida qoldi", still["devices"] >= 1, str(still["devices"]))


    print("\n--- 13. Resurs sarfi ---")

    import io as _io
    from PIL import Image as _Image

    _buf = _io.BytesIO()
    _Image.new("RGB", (50, 50)).save(_buf, format="JPEG")
    _img = _buf.getvalue()

    spam, _, _ = login(c, phone("95"))
    codes = [
        c.post(
            "/uploads",
            headers=auth(spam),
            files={"file": ("a.jpg", _img, "image/jpeg")},
        ).status_code
        for _ in range(65)
    ]
    check(
        "cheksiz surat yuklab bo'lmaydi",
        429 in codes,
        f"201: {codes.count(201)}, 429: {codes.count(429)} — aks holda disk to'ldirilardi",
    )

    huge = b"\xff\xd8\xff" + b"0" * (20 * 1024 * 1024)
    r = c.post(
        "/uploads",
        headers=auth(spam),
        files={"file": ("big.jpg", huge, "image/jpeg")},
    )
    check(
        "juda katta so'rov o'qilmasdan rad etiladi",
        r.status_code == 413,
        f"{r.status_code} — rad etilgan so'rov ham resurs yeyishi mumkin emas",
    )

    codes = [
        c.post(
            "/reports",
            headers=auth(spam),
            json={"target_type": "user", "target_id": alice_id, "reason": "spam"},
        ).status_code
        for _ in range(25)
    ]
    check(
        "shikoyat navbatini ko'mib bo'lmaydi",
        429 in codes or codes.count(201) <= 21,
        f"429: {codes.count(429)}",
    )


print("\n" + "=" * 60)
if FAILURES:
    print(f"XAVFSIZLIK: {len(FAILURES)} ta muammo topildi")
    for f in FAILURES:
        print(f"  ✗ {f}")
    raise SystemExit(1)
print("XAVFSIZLIK: hamma zond urinishi rad etildi")
