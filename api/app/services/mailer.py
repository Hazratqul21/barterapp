"""Email yuborish — SMTP, sozlamasi admin paneldan.

Eskiz kabi: hisob ma'lumoti `.env` da emas, panelda qo'yiladi, saqlashdan
oldin serverga ulanib tekshiriladi va parol hech qachon qaytarilmaydi.

Har qanday SMTP ishlaydi: Google Workspace / Gmail («app password» bilan,
`smtp.gmail.com:465`), Yandex, Mail.ru, Resend, Brevo va h.k.

Sozlanmagan holatda ishlab chiqishda xat logga yoziladi (kod javobda
`debug_code` bo'lib ham qaytadi); productionda esa yuborish rad etiladi va
email orqali ro'yxatdan o'tish yopiq turadi (`/auth/methods` → `email: false`).
"""

from __future__ import annotations

import json
import logging
import smtplib
import ssl
from dataclasses import asdict, dataclass
from email.message import EmailMessage
from email.utils import formataddr
from typing import Callable

from sqlalchemy.ext.asyncio import AsyncSession
from starlette.concurrency import run_in_threadpool

from app.core.config import settings
from app.services import settings_store

log = logging.getLogger("barter.mail")

#: SMTP serveri shu vaqtgacha javob bermasa — xato, sahifa qotmaydi.
TIMEOUT = 15

#: Faqat sinovlar uchun: yuborilgan xatlarni ushlab qoladi.
TRANSPORT: Callable[[SmtpCredentials, EmailMessage], None] | None = None


class MailError(RuntimeError):
    """Yuborib bo'lmadi. Matni foydalanuvchiga ko'rsatsa bo'ladi."""


@dataclass(frozen=True)
class SmtpCredentials:
    host: str
    port: int
    username: str
    password: str
    from_email: str
    from_name: str = "MAB"
    #: "ssl" (odatda 465) yoki "starttls" (odatda 587).
    security: str = "ssl"

    def to_json(self) -> str:
        return json.dumps(asdict(self))

    @classmethod
    def from_json(cls, raw: str) -> "SmtpCredentials":
        return cls(**json.loads(raw))


async def credentials(db: AsyncSession) -> SmtpCredentials | None:
    raw = await settings_store.get(db, settings_store.SMTP)
    if not raw:
        return None
    try:
        return SmtpCredentials.from_json(raw)
    except (ValueError, TypeError):
        log.error("Bazadagi SMTP sozlamasi o'qilmadi — e'tiborsiz qoldirildi.")
        return None


async def ready(db: AsyncSession) -> bool:
    return await credentials(db) is not None


async def email_signup_open(db: AsyncSession) -> bool:
    """Email orqali ro'yxatdan o'tish ochiqmi: SMTP bor, yoki bu production emas."""
    return await ready(db) or not settings.is_production


def _connect(creds: SmtpCredentials) -> smtplib.SMTP:
    context = ssl.create_default_context()
    if creds.security == "ssl":
        server: smtplib.SMTP = smtplib.SMTP_SSL(
            creds.host, creds.port, timeout=TIMEOUT, context=context
        )
    else:
        server = smtplib.SMTP(creds.host, creds.port, timeout=TIMEOUT)
        server.starttls(context=context)
    server.login(creds.username, creds.password)
    return server


def _explain(exc: Exception) -> MailError:
    if isinstance(exc, smtplib.SMTPAuthenticationError):
        return MailError(
            "Pochta serveri login yoki parolni qabul qilmadi. Gmail/Workspace "
            "uchun oddiy parol emas, «App password» kerak."
        )
    if isinstance(exc, smtplib.SMTPRecipientsRefused):
        return MailError("Qabul qiluvchi manzil rad etildi.")
    if isinstance(exc, smtplib.SMTPSenderRefused):
        return MailError("Jo'natuvchi manzil rad etildi — u shu hisobga tegishlimi?")
    # Ulanish, TLS, vaqt tugashi va h.k. Tafsilot logga, foydalanuvchiga emas.
    log.warning("SMTP xatosi: %s", type(exc).__name__)
    return MailError("Pochta serveriga ulanib bo'lmadi. Host, port va xavfsizlik turini tekshiring.")


async def check(creds: SmtpCredentials) -> None:
    """Saqlashdan oldin: ulanib, login qilib ko'radi. Xat yubormaydi."""
    if TRANSPORT is not None:
        return

    def run() -> None:
        try:
            _connect(creds).quit()
        except Exception as exc:  # noqa: BLE001 — har biri _explain'da
            raise _explain(exc) from exc

    await run_in_threadpool(run)


def _message(creds: SmtpCredentials, to: str, subject: str, text: str) -> EmailMessage:
    message = EmailMessage()
    message["From"] = formataddr((creds.from_name, creds.from_email))
    message["To"] = to
    message["Subject"] = subject
    message.set_content(text)
    return message


async def send(db: AsyncSession, to: str, subject: str, text: str) -> None:
    creds = await credentials(db)
    if creds is None:
        if settings.is_production:
            raise MailError("Pochta xizmati sozlanmagan.")
        log.warning("email (quruq rejim) → %s: %s", to, text)
        return

    message = _message(creds, to, subject, text)
    if TRANSPORT is not None:
        TRANSPORT(creds, message)
        return

    def run() -> None:
        try:
            server = _connect(creds)
            try:
                server.send_message(message)
            finally:
                server.quit()
        except Exception as exc:  # noqa: BLE001
            raise _explain(exc) from exc

    await run_in_threadpool(run)


def code_text(code: str, purpose: str, locale: str = "uz") -> tuple[str, str]:
    """(mavzu, matn). Kod mavzuda ham bor — bildirishnomadan o'qish oson."""
    if purpose == "reset":
        texts = {
            "uz": ("MAB: parolni tiklash kodi {code}",
                   "Parolni tiklash kodingiz: {code}\n\nKod 10 daqiqa amal qiladi. "
                   "Agar buni siz so'ramagan bo'lsangiz, xatga e'tibor bermang."),
            "ru": ("MAB: код для сброса пароля {code}",
                   "Ваш код для сброса пароля: {code}\n\nКод действует 10 минут. "
                   "Если вы этого не запрашивали, просто проигнорируйте письмо."),
            "en": ("MAB: password reset code {code}",
                   "Your password reset code: {code}\n\nThe code is valid for 10 minutes. "
                   "If you did not ask for it, ignore this email."),
        }
    else:
        texts = {
            "uz": ("MAB: tasdiqlash kodi {code}",
                   "MAB'da ro'yxatdan o'tish kodingiz: {code}\n\nKod 10 daqiqa amal qiladi. "
                   "Hech kimga aytmang."),
            "ru": ("MAB: код подтверждения {code}",
                   "Ваш код для регистрации в MAB: {code}\n\nКод действует 10 минут. "
                   "Никому его не сообщайте."),
            "en": ("MAB: verification code {code}",
                   "Your MAB sign-up code: {code}\n\nThe code is valid for 10 minutes. "
                   "Do not share it with anyone."),
        }
    subject, body = texts.get(locale, texts["uz"])
    return subject.format(code=code), body.format(code=code)
