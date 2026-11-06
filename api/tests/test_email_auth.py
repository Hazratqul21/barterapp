"""Email orqali ro'yxatdan o'tish, parolni tiklash va SMTP sozlamasi.

Talablar:

- Email kod bilan tasdiqlanmaguncha hisob ochilmaydi; kod bir marta ishlaydi,
  urinishlar cheklangan.
- Mavjud email bilan qayta ro'yxatdan o'tib bo'lmaydi.
- Parolni tiklash eski sessiyalarni bekor qiladi.
- SMTP admin paneldan qo'yiladi; parol qaytarilmaydi; kod xatda boradi.
- Productionda SMTP'siz email ro'yxatdan o'tish yopiq.
- Email bilan ochilgan hisobga o'sha email'li Google ulanadi (yangi hisob emas).

Ilova jarayon ichida chaqiriladi: pochta va Google soxta.
"""

import asyncio
import sys
import uuid
from pathlib import Path

import httpx
from sqlalchemy import select

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.api import auth as auth_module  # noqa: E402
from app.core.config import settings  # noqa: E402
from app.db.session import SessionLocal, engine  # noqa: E402
from app.main import app  # noqa: E402
from app.models.user import User  # noqa: E402
from app.services import mailer, settings_store  # noqa: E402

MODERATOR_PHONE = "+998901234122"
PASSWORD = "juda-uzun-parol-123"

failures = 0


def check(name: str, ok: bool, detail: str = "") -> None:
    global failures
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else f" — {detail}"))
    if not ok:
        failures += 1


async def clean() -> None:
    async with SessionLocal() as db:
        await settings_store.drop(db, settings_store.SMTP)
        await db.commit()


async def run() -> None:
    email = f"test-{uuid.uuid4().hex[:8]}@example.uz"
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://mail") as c:
        r = await c.get("/auth/methods")
        check("methods: email ochiq (dev)", r.json().get("email") is True, r.text)

        r = await c.post("/auth/email/code", json={"email": "salom"})
        check("noto'g'ri email 422", r.status_code == 422, r.text)

        r = await c.post("/auth/email/code", json={"email": email.upper()})
        check("kod so'raldi", r.status_code == 200 and r.json()["debug_code"], r.text)
        code = r.json()["debug_code"]

        r = await c.post("/auth/email/register", json={"email": email, "code": "000000" if code != "000000" else "111111", "password": PASSWORD})
        check("noto'g'ri kod 400", r.status_code == 400, r.text)

        r = await c.post("/auth/email/register", json={"email": email, "code": code, "password": "qisqa"})
        check("qisqa parol 422", r.status_code == 422, r.text)

        r = await c.post("/auth/email/register", json={"email": email, "code": code, "password": PASSWORD, "first_name": "Ali"})
        check("ro'yxatdan o'tildi", r.status_code == 200 and r.json()["is_new_user"] is True, r.text)
        token = r.json().get("access_token", "")
        me = await c.get("/me", headers={"Authorization": "Bearer " + token})
        check("/me ishlaydi", me.status_code == 200, me.text)

        r = await c.post("/auth/email/register", json={"email": email, "code": code, "password": PASSWORD})
        check("kod qayta ishlamaydi", r.status_code in (400, 409), r.text)

        r = await c.post("/auth/email/code", json={"email": email})
        check("mavjud email bilan qayta ro'yxat 409", r.status_code == 409, r.text)

        r = await c.post("/auth/password/login", json={"identifier": email, "password": PASSWORD})
        check("email va parol bilan kirish", r.status_code == 200, r.text)
        old_refresh = r.json().get("refresh_token")

        # --- parolni tiklash ------------------------------------------------
        r = await c.post("/auth/email/code", json={"email": "yoq-" + email, "purpose": "reset"})
        check("yo'q email uchun tiklash 404", r.status_code == 404, r.text)
        r = await c.post("/auth/email/code", json={"email": email, "purpose": "reset"})
        check("tiklash kodi", r.status_code == 200, r.text)
        reset_code = r.json()["debug_code"]
        r = await c.post("/auth/email/register", json={"email": "boshqa-" + email, "code": reset_code, "password": PASSWORD})
        check("tiklash kodi ro'yxatga yaramaydi", r.status_code == 400, r.text)
        r = await c.post("/auth/email/reset", json={"email": email, "code": reset_code, "password": PASSWORD + "x"})
        check("parol tiklandi", r.status_code == 200, r.text)
        r = await c.post("/auth/refresh", json={"refresh_token": old_refresh})
        check("eski sessiya bekor", r.status_code == 401, r.text)
        r = await c.post("/auth/password/login", json={"identifier": email, "password": PASSWORD + "x"})
        check("yangi parol bilan kirish", r.status_code == 200, r.text)

        # --- urinishlar cheklovi ----------------------------------------------
        other = f"lim-{uuid.uuid4().hex[:8]}@example.uz"
        r = await c.post("/auth/email/code", json={"email": other})
        good = r.json()["debug_code"]
        bad = "123456" if good != "123456" else "654321"
        codes = [(await c.post("/auth/email/register", json={"email": other, "code": bad, "password": PASSWORD})).status_code for _ in range(6)]
        check("5 xatodan keyin 429", codes[:5] == [400] * 5 and codes[5] == 429, str(codes))
        r = await c.post("/auth/email/register", json={"email": other, "code": good, "password": PASSWORD})
        check("bloklangan kod to'g'ri bo'lsa ham o'tmaydi", r.status_code == 429, r.text)

        # --- SMTP admin paneldan ---------------------------------------------------
        r = await c.post("/auth/otp/request", json={"phone": MODERATOR_PHONE})
        r = await c.post("/auth/otp/verify", json={"phone": MODERATOR_PHONE, "code": r.json()["debug_code"]})
        h = {"Authorization": "Bearer " + r.json()["access_token"]}
        async with SessionLocal() as db:
            mod = await db.scalar(select(User).where(User.phone == MODERATOR_PHONE))
            mod.is_moderator = True
            await db.commit()

        sent = []
        mailer.TRANSPORT = lambda creds, message: sent.append((creds, message))
        smtp = {"host": "smtp.gmail.com", "port": 465, "security": "ssl", "username": "no-reply@mab.uz", "password": "app-password-sir", "from_name": "MAB"}
        r = await c.put("/admin/email", headers=h, json=smtp)
        check("SMTP saqlandi", r.status_code == 200 and r.json()["ready"] is True, r.text)
        check("SMTP paroli qaytmaydi", "app-password-sir" not in r.text, r.text)
        r = await c.get("/admin/email")
        check("tokensiz /admin/email yopiq", r.status_code in (401, 403), str(r.status_code))

        third = f"smtp-{uuid.uuid4().hex[:8]}@example.uz"
        r = await c.post("/auth/email/code", json={"email": third}, headers={"Accept-Language": "ru"})
        check("SMTP orqali kod", r.status_code == 200 and len(sent) == 1, r.text)
        if sent:
            creds, message = sent[-1]
            body = message.get_content()
            check("xat to'g'ri manzilga", message["To"] == third, message["To"])
            check("jo'natuvchi panel'dan", "no-reply@mab.uz" in message["From"], message["From"])
            check("xatda kod bor", r.json()["debug_code"] in body and r.json()["debug_code"] in message["Subject"], body)
            check("xat rus tilida", "код" in message["Subject"], message["Subject"])

        r = await c.post("/admin/email/test", headers=h, json={"to": "admin@mab.uz"})
        check("sinov xati", r.status_code == 200 and sent[-1][1]["To"] == "admin@mab.uz", r.text)

        # --- production: SMTP'siz yopiq --------------------------------------------
        await c.delete("/admin/email", headers=h)
        saved_env = settings.app_env
        settings.app_env = "production"
        try:
            r = await c.get("/auth/methods")
            check("production, SMTP yo'q: email yopiq", r.json()["email"] is False, r.text)
            r = await c.post("/auth/email/code", json={"email": "p-" + third})
            check("production, SMTP yo'q: 503", r.status_code == 503, r.text)
        finally:
            settings.app_env = saved_env

        # --- Google o'sha email bilan: ulanadi --------------------------------
        async def fake_identity(*_):
            return {"sub": "g-" + uuid.uuid4().hex, "email": email, "given_name": "Ali", "family_name": "V"}

        real = auth_module.google_identity
        auth_module.google_identity = fake_identity
        try:
            r = await c.post("/auth/google", json={"id_token": "x" * 40})
            check("Google email hisobiga ulandi", r.status_code == 200 and r.json()["is_new_user"] is False, r.text)
            async with SessionLocal() as db:
                rows = (await db.scalars(select(User).where(User.email == email))).all()
            check("yangi hisob ochilmadi", len(rows) == 1 and rows[0].google_sub, str(len(rows)))
        finally:
            auth_module.google_identity = real

    mailer.TRANSPORT = None
    await engine.dispose()


async def main() -> None:
    await clean()
    try:
        await run()
    finally:
        mailer.TRANSPORT = None
        await clean()


asyncio.run(main())
print(f"\n{'OK' if not failures else f'{failures} ta xato'}")
sys.exit(1 if failures else 0)
