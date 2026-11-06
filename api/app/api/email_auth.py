"""Email orqali ro'yxatdan o'tish va parolni tiklash.

Oqim telefon OTP bilan bir xil, faqat kod emailga boradi:

1. `POST /auth/email/code` `{email, purpose}` — 6 xonali kod yuboriladi.
2. `POST /auth/email/register` `{email, code, password, first_name?}` — hisob
   ochiladi (email tasdiqlangan, parol bilan), sessiya qaytadi.
3. `POST /auth/email/reset` `{email, code, password}` — parol almashadi.

Himoya telefon oqimidagidek: kodning faqat HMAC'i saqlanadi, bir marta
ishlatiladi, kodga 5 urinish, kuniga 15 xato, bitta emailga 15 daqiqada 5
kod, bitta manzildan soatiga 10 so'rov.
"""

from __future__ import annotations

import logging
import re
import secrets
from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import Field, field_validator
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.auth import (
    MAX_ATTEMPTS,
    MAX_FAILED_PER_DAY,
    _create_user,
    _hash_code,
    _issue_tokens,
    _lock_identifier,
)
from app.core.config import settings
from app.core.locale import resolve_locale
from app.core.ratelimit import otp_request_ip, otp_verify_ip, sms_global, source
from app.db.session import get_db
from app.models.user import EmailChallenge, RefreshToken, User
from app.schemas.common import ApiModel
from app.schemas.user import OtpRequestResult, TokenPair
from app.services import mailer
from app.services.login_credentials import hash_password

router = APIRouter(prefix="/auth/email", tags=["auth"])

log = logging.getLogger("barter.auth")

#: Email kodi telefonnikidan uzoqroq yashaydi: xat kechikishi mumkin.
CODE_TTL = timedelta(minutes=10)


#: Oddiy shakl tekshiruvi; haqiqiyligini kod tasdiqlaydi.
EMAIL_SHAPE = r"^[^@\s]{1,64}@[^@\s]+\.[^@\s]{2,}$"


class EmailIn(ApiModel):
    email: str = Field(max_length=320)

    @field_validator("email")
    @classmethod
    def _normal(cls, value: str) -> str:
        value = value.strip().lower()
        if not re.match(EMAIL_SHAPE, value):
            raise ValueError("Email noto‘g‘ri yozilgan.")
        return value


class CodeRequest(EmailIn):
    purpose: str = Field(default="register", pattern="^(register|reset)$")


class EmailRegister(EmailIn):
    code: str = Field(pattern=r"^[0-9]{6}$")
    password: str = Field(min_length=12, max_length=128)
    first_name: str = Field(default="", max_length=80)


class EmailReset(EmailIn):
    code: str = Field(pattern=r"^[0-9]{6}$")
    password: str = Field(min_length=12, max_length=128)


async def _existing(db: AsyncSession, email: str) -> User | None:
    return await db.scalar(
        select(User).where(User.email == email, User.deleted_at.is_(None))
    )


@router.post("/code", response_model=OtpRequestResult)
async def request_code(
    payload: CodeRequest, request: Request, db: AsyncSession = Depends(get_db)
) -> OtpRequestResult:
    if not await mailer.email_signup_open(db):
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            "Email orqali ro'yxatdan o'tish hozircha yopiq. Google yoki telefon orqali kiring.",
        )
    now = datetime.now(UTC)
    email = payload.email
    await _lock_identifier(db, "email-code:" + email)
    if not settings.otp_debug:
        otp_request_ip.check(source(request, None))

    user = await _existing(db, email)
    if payload.purpose == "register" and user is not None:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "Bu email bilan hisob bor. «Kirish» orqali kiring yoki parolni tiklang.",
        )
    if payload.purpose == "reset" and (user is None or not user.password_hash):
        # Hisob yo'qligini ochiq aytamiz: ro'yxatdan o'tishda baribir ko'rinadi,
        # yashirish faqat odamni chalkashtiradi.
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Bu email bilan parolli hisob topilmadi.")

    recent = await db.scalar(
        select(func.count())
        .select_from(EmailChallenge)
        .where(
            EmailChallenge.email == email,
            EmailChallenge.created_at > now - timedelta(seconds=settings.otp_rate_window_seconds),
        )
    )
    if (recent or 0) >= settings.otp_rate_max:
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            "Juda ko‘p kod so‘raldi. Birozdan so‘ng qayta urining.",
            headers={"Retry-After": str(settings.otp_rate_window_seconds)},
        )
    sms_global.check("all")

    code = f"{secrets.randbelow(1_000_000):06d}"
    await db.execute(
        update(EmailChallenge)
        .where(
            EmailChallenge.email == email,
            EmailChallenge.purpose == payload.purpose,
            EmailChallenge.consumed_at.is_(None),
        )
        .values(consumed_at=now)
    )
    db.add(
        EmailChallenge(
            email=email,
            purpose=payload.purpose,
            code_hash=_hash_code(code),
            created_at=now,
            expires_at=now + CODE_TTL,
        )
    )
    await db.commit()

    subject, text = mailer.code_text(code, payload.purpose, resolve_locale(request.headers.get("accept-language")))
    try:
        await mailer.send(db, email, subject, text)
    except mailer.MailError as exc:
        log.warning("Email kodi yuborilmadi: %s", exc)
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            "Hozir xat yuborib bo'lmadi. Birozdan so'ng qayta urining.",
        ) from exc

    return OtpRequestResult(
        sent=True,
        expires_in=int(CODE_TTL.total_seconds()),
        debug_code=code if settings.otp_debug else None,
    )


async def _check_code(
    db: AsyncSession, request: Request, email: str, purpose: str, code: str
) -> None:
    now = datetime.now(UTC)
    await _lock_identifier(db, "email-code:" + email)
    if not settings.otp_debug:
        otp_verify_ip.check(source(request, None))

    failed_today = await db.scalar(
        select(func.coalesce(func.sum(EmailChallenge.attempts), 0)).where(
            EmailChallenge.email == email,
            EmailChallenge.created_at > now - timedelta(days=1),
        )
    )
    if (failed_today or 0) >= MAX_FAILED_PER_DAY:
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            "Juda ko‘p noto‘g‘ri urinish. Ertaga qayta urining.",
        )

    challenge = await db.scalar(
        select(EmailChallenge)
        .where(
            EmailChallenge.email == email,
            EmailChallenge.purpose == purpose,
            EmailChallenge.consumed_at.is_(None),
            EmailChallenge.expires_at > now,
        )
        .order_by(EmailChallenge.created_at.desc())
        .limit(1)
        .with_for_update()
    )
    if challenge is None:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "Kod muddati tugagan yoki yuborilmagan. Yangi kod so‘rang.",
        )
    if challenge.attempts >= MAX_ATTEMPTS:
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS, "Juda ko‘p urinish. Yangi kod so‘rang."
        )
    if not secrets.compare_digest(challenge.code_hash, _hash_code(code)):
        challenge.attempts += 1
        await db.commit()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Kod noto‘g‘ri.")
    challenge.consumed_at = now


@router.post("/register", response_model=TokenPair)
async def register(
    payload: EmailRegister, request: Request, db: AsyncSession = Depends(get_db)
) -> TokenPair:
    email = payload.email
    await _check_code(db, request, email, "register", payload.code)
    await _lock_identifier(db, "email:" + email)
    if await db.scalar(select(User.id).where(User.email == email)) is not None:
        await db.commit()
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "Bu email bilan hisob bor. «Kirish» orqali kiring yoki parolni tiklang.",
        )

    user = await _create_user(
        db,
        email=email,
        first_name=payload.first_name.strip()[:80],
        password_hash=await hash_password(payload.password),
    )
    pair = await _issue_tokens(db, user.id)
    await db.commit()
    return TokenPair(
        access_token=pair.access_token,
        refresh_token=pair.refresh_token,
        is_new_user=True,
    )


@router.post("/reset", response_model=TokenPair)
async def reset(
    payload: EmailReset, request: Request, db: AsyncSession = Depends(get_db)
) -> TokenPair:
    email = payload.email
    await _check_code(db, request, email, "reset", payload.code)
    user = await db.scalar(
        select(User).where(User.email == email, User.deleted_at.is_(None)).with_for_update()
    )
    if user is None:
        await db.commit()
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Bu email bilan hisob topilmadi.")
    user.password_hash = await hash_password(payload.password)
    await db.execute(
        update(RefreshToken)
        .where(RefreshToken.user_id == user.id)
        .values(revoked_at=datetime.now(UTC))
    )
    pair = await _issue_tokens(db, user.id)
    await db.commit()
    return pair
