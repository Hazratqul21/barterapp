from __future__ import annotations

import hashlib
import hmac
import secrets
from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
)
from app.db.session import get_db
from app.models.social import VerificationStep
from app.models.user import OtpChallenge, User
from app.schemas.user import (
    OtpRequest,
    OtpRequestResult,
    OtpVerify,
    RefreshRequest,
    TokenPair,
)

router = APIRouter(prefix="/auth", tags=["auth"])

MAX_ATTEMPTS = 5

# The steps every account starts with; weights add up to the trust score.
STARTER_STEPS = [
    ("phone", "SMS orqali tasdiqlangan", 20),
    ("passport", "Pasport yoki JSHSHIR", 25),
    ("business", "Korxona hujjatlari", 25),
    ("bank", "Escrow to‘lovlari uchun", 20),
    ("video", "30 soniyalik selfie video", 10),
]


def _hash_code(code: str) -> str:
    """Keyed hash of a login code, so the stored value is useless if leaked."""
    return hmac.new(
        settings.jwt_secret.encode(), code.encode(), hashlib.sha256
    ).hexdigest()


@router.post("/otp/request", response_model=OtpRequestResult)
async def request_otp(
    payload: OtpRequest, db: AsyncSession = Depends(get_db)
) -> OtpRequestResult:
    now = datetime.now(UTC)

    # Rate limit per phone. Count the codes already asked for in the window;
    # past the ceiling, refuse — this is what stops a caller from making the
    # server send unlimited SMS to a number, or from farming codes to guess.
    window_start = now - timedelta(seconds=settings.otp_rate_window_seconds)
    recent = await db.scalar(
        select(func.count())
        .select_from(OtpChallenge)
        .where(
            OtpChallenge.phone == payload.phone,
            OtpChallenge.created_at > window_start,
        )
    )
    if (recent or 0) >= settings.otp_rate_max:
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            "Juda ko‘p kod so‘raldi. Birozdan so‘ng qayta urining.",
            headers={"Retry-After": str(settings.otp_rate_window_seconds)},
        )

    code = f"{secrets.randbelow(1_000_000):06d}"

    db.add(
        OtpChallenge(
            phone=payload.phone,
            code_hash=_hash_code(code),
            created_at=now,
            expires_at=now + timedelta(seconds=settings.otp_ttl_seconds),
        )
    )
    await db.commit()

    # A real SMS gateway goes here. Until then the code comes back in the
    # response so the app can be driven end to end in development. Only the
    # hash is ever stored; the plaintext lives only in this response.
    return OtpRequestResult(
        sent=True,
        expires_in=settings.otp_ttl_seconds,
        debug_code=code if settings.otp_debug else None,
    )


@router.post("/otp/verify", response_model=TokenPair)
async def verify_otp(
    payload: OtpVerify, db: AsyncSession = Depends(get_db)
) -> TokenPair:
    now = datetime.now(UTC)

    challenge = await db.scalar(
        select(OtpChallenge)
        .where(
            OtpChallenge.phone == payload.phone,
            OtpChallenge.consumed_at.is_(None),
            OtpChallenge.expires_at > now,
        )
        .order_by(OtpChallenge.created_at.desc())
        .limit(1)
    )
    if challenge is None:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "Kod muddati tugagan yoki yuborilmagan. Yangi kod so‘rang.",
        )

    if challenge.attempts >= MAX_ATTEMPTS:
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            "Juda ko‘p urinish. Yangi kod so‘rang.",
        )

    if not secrets.compare_digest(challenge.code_hash, _hash_code(payload.code)):
        challenge.attempts += 1
        await db.commit()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Kod noto‘g‘ri.")

    challenge.consumed_at = now

    user = await db.scalar(select(User).where(User.phone == payload.phone))
    is_new = user is None
    if user is None:
        user = User(
            phone=payload.phone,
            first_name="",
            last_name="",
            trust_score=20,
            last_seen_at=now,
        )
        db.add(user)
        await db.flush()

        for step, hint, weight in STARTER_STEPS:
            db.add(
                VerificationStep(
                    user_id=user.id,
                    step=step,
                    hint=hint,
                    weight=weight,
                    state="done" if step == "phone" else "todo",
                )
            )
    else:
        user.last_seen_at = now

    await db.commit()

    return TokenPair(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
        is_new_user=is_new,
    )


@router.post("/refresh", response_model=TokenPair)
async def refresh(payload: RefreshRequest) -> TokenPair:
    user_id = decode_token(payload.refresh_token, "refresh")
    return TokenPair(
        access_token=create_access_token(user_id),
        refresh_token=create_refresh_token(user_id),
    )
