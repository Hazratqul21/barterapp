from __future__ import annotations

import hashlib
import hmac
import secrets
from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import (
    create_access_token,
    create_refresh_token,
    current_user,
    decode_refresh,
    refresh_lifetime,
)
from app.db.session import get_db
from app.models.social import VerificationStep
from app.models.user import OtpChallenge, RefreshToken, User
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

    pair = await _issue_tokens(db, user.id)
    await db.commit()
    return TokenPair(
        access_token=pair.access_token,
        refresh_token=pair.refresh_token,
        is_new_user=is_new,
    )


async def _issue_tokens(db: AsyncSession, user_id) -> TokenPair:
    """Mint an access token and a fresh, tracked refresh token."""
    now = datetime.now(UTC)
    row = RefreshToken(
        user_id=user_id,
        created_at=now,
        expires_at=now + refresh_lifetime(),
    )
    db.add(row)
    await db.flush()  # assigns row.id, which becomes the token's jti
    return TokenPair(
        access_token=create_access_token(user_id),
        refresh_token=create_refresh_token(user_id, row.id),
    )


@router.post("/refresh", response_model=TokenPair)
async def refresh(
    payload: RefreshRequest, db: AsyncSession = Depends(get_db)
) -> TokenPair:
    user_id, jti = decode_refresh(payload.refresh_token)
    now = datetime.now(UTC)

    row = await db.scalar(select(RefreshToken).where(RefreshToken.id == jti))

    # Unknown jti: the row was swept, or the token was forged around a real
    # signature it never had. Either way it is not a live session.
    if row is None or row.user_id != user_id:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Sessiya yaroqsiz.")

    # Already revoked, yet presented again — this is the reuse signal. A
    # rotating token is used exactly once; a second use means two copies exist,
    # so the safe move is to end every session for the account and force a fresh
    # sign-in.
    if row.revoked_at is not None:
        await db.execute(
            update(RefreshToken)
            .where(
                RefreshToken.user_id == user_id,
                RefreshToken.revoked_at.is_(None),
            )
            .values(revoked_at=now)
        )
        await db.commit()
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED,
            "Sessiyada xavfsizlik muammosi aniqlandi. Qaytadan kiring.",
        )

    if row.expires_at <= now:
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED, "Sessiya muddati tugagan. Qaytadan kiring."
        )

    # Rotate: retire this token, hand back a new pair.
    row.revoked_at = now
    pair = await _issue_tokens(db, user_id)
    await db.commit()
    return pair


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(payload: RefreshRequest, db: AsyncSession = Depends(get_db)) -> None:
    """End this one session. Best-effort: a token already gone is a no-op."""
    try:
        _, jti = decode_refresh(payload.refresh_token)
    except HTTPException:
        return
    await db.execute(
        update(RefreshToken)
        .where(RefreshToken.id == jti, RefreshToken.revoked_at.is_(None))
        .values(revoked_at=datetime.now(UTC))
    )
    await db.commit()


@router.post("/logout-all", status_code=status.HTTP_204_NO_CONTENT)
async def logout_all(
    me: User = Depends(current_user), db: AsyncSession = Depends(get_db)
) -> None:
    """End every session for the signed-in account — a stolen-device switch."""
    await db.execute(
        update(RefreshToken)
        .where(RefreshToken.user_id == me.id, RefreshToken.revoked_at.is_(None))
        .values(revoked_at=datetime.now(UTC))
    )
    await db.commit()
