from __future__ import annotations

import hashlib
import hmac
import logging
import secrets
import httpx
from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import delete, func, or_, select, text, update
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
from app.models.user import LoginAttempt, OtpChallenge, RefreshToken, User
from app.services.login_credentials import check_password, hash_password, google_identity
from app.schemas.user import GoogleLogin, PasswordLogin, PasswordSet, PasswordReset
from app.services.sms import SmsError, get_sms, otp_text
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


log = logging.getLogger("barter.auth")


def _hash_code(code: str) -> str:
    """Keyed hash of a login code, so the stored value is useless if leaked."""
    return hmac.new(
        settings.jwt_secret.encode(), code.encode(), hashlib.sha256
    ).hexdigest()


@router.post("/otp/request", response_model=OtpRequestResult)
async def request_otp(
    payload: OtpRequest, db: AsyncSession = Depends(get_db)
) -> OtpRequestResult:
    if not settings.phone_login_enabled:
        raise HTTPException(503, "Telefon orqali kirish SMS xizmati ulangach ochiladi.")
    now = datetime.now(UTC)
    await _lock_identifier(db, payload.phone)

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

    await db.execute(update(OtpChallenge).where(
        OtpChallenge.phone == payload.phone, OtpChallenge.consumed_at.is_(None)
    ).values(consumed_at=now))
    db.add(
        OtpChallenge(
            phone=payload.phone,
            code_hash=_hash_code(code),
            created_at=now,
            expires_at=now + timedelta(seconds=settings.otp_ttl_seconds),
        )
    )
    await db.commit()

    # Faqat hash saqlanadi; ochiq kod shu yerdan nariga chiqmaydi.
    delivered = True
    try:
        await get_sms().send(payload.phone, otp_text(code))
    except (SmsError, httpx.HTTPError) as exc:
        # Sabab logda qoladi, foydalanuvchiga chiqmaydi: provayder xatosi
        # unga hech narsa demaydi, lekin xizmat haqidagi ma'lumot beradi.
        log.warning("OTP SMS delivery failed: %s", type(exc).__name__)
        delivered = False

        if settings.sms_required:
            # Ishlab chiqarishda jimgina davom etish eng yomon holat: odam
            # kod kutadi, kod kelmaydi va nima bo'lgani hech qayerda
            # ko'rinmaydi. Shuning uchun ochiq aytiladi.
            raise HTTPException(
                status.HTTP_503_SERVICE_UNAVAILABLE,
                "Hozir SMS yuborib bo'lmadi. Birozdan so'ng qayta urining.",
            ) from exc

    return OtpRequestResult(
        sent=delivered,
        expires_in=settings.otp_ttl_seconds,
        debug_code=code if settings.otp_debug else None,
    )


@router.post("/otp/verify", response_model=TokenPair)
async def verify_otp(
    payload: OtpVerify, db: AsyncSession = Depends(get_db)
) -> TokenPair:
    if not settings.phone_login_enabled:
        raise HTTPException(503, "Telefon orqali kirish SMS xizmati ulangach ochiladi.")
    now = datetime.now(UTC)
    await _lock_identifier(db, payload.phone)

    challenge = await db.scalar(
        select(OtpChallenge)
        .where(
            OtpChallenge.phone == payload.phone,
            OtpChallenge.consumed_at.is_(None),
            OtpChallenge.expires_at > now,
        )
        .order_by(OtpChallenge.created_at.desc())
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

    row = await db.scalar(select(RefreshToken).where(RefreshToken.id == jti).with_for_update())

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

    user = await db.scalar(select(User).where(User.id == user_id))
    if user is None or user.is_deleted:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Hisob mavjud emas.")

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


async def _lock_identifier(db: AsyncSession, identifier: str) -> None:
    # Serialize checks across workers; an in-process counter is insufficient.
    key = int.from_bytes(hashlib.sha256(identifier.encode()).digest()[:8], 'big', signed=True)
    await db.execute(text('SELECT pg_advisory_xact_lock(:key)'), {'key': key})


@router.get('/methods')
async def login_methods():
    return {'phone': settings.phone_login_enabled, 'password': True,
            'google': bool(settings.google_client_ids),
            'google_client_id': settings.google_client_ids[0] if settings.google_client_ids else None}


async def _throttle_password(db: AsyncSession, identifier: str):
    await _lock_identifier(db, identifier)
    now = datetime.now(UTC)
    digest = _hash_code(identifier)
    count = await db.scalar(select(func.count()).select_from(LoginAttempt).where(
        LoginAttempt.identifier_hash == digest,
        LoginAttempt.created_at > now - timedelta(minutes=15)))
    if (count or 0) >= 5:
        raise HTTPException(429, "Ko'p urinish. 15 daqiqadan so'ng qaytadan urinib ko'ring.", headers={'Retry-After': '900'})
    await db.execute(delete(LoginAttempt).where(LoginAttempt.created_at < now - timedelta(days=1)))
    db.add(LoginAttempt(identifier_hash=digest, created_at=now))
    await db.commit()


@router.post('/password/login', response_model=TokenPair)
async def password_login(payload: PasswordLogin, db: AsyncSession = Depends(get_db)):
    identifier = payload.identifier.strip().lower()
    await _throttle_password(db, identifier)
    user = await db.scalar(select(User).where(or_(User.phone == identifier, User.email == identifier)))
    valid = await check_password(user.password_hash if user and not user.is_deleted else None, payload.password)
    if not valid:
        raise HTTPException(401, "Telefon/email yoki parol noto'g'ri.")
    user.last_seen_at = datetime.now(UTC)
    pair = await _issue_tokens(db, user.id)
    await db.commit()
    return pair


@router.post('/password/set', response_model=TokenPair)
async def password_set(payload: PasswordSet, me: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    # A password can only be created after Google/SMS verified ownership.
    await _throttle_password(db, 'set:' + str(me.id))
    me = await db.scalar(select(User).where(User.id == me.id).with_for_update())
    if me.password_hash and not await check_password(me.password_hash, payload.current_password or ''):
        raise HTTPException(401, "Joriy parol noto'g'ri.")
    me.password_hash = await hash_password(payload.password)
    await db.execute(update(RefreshToken).where(RefreshToken.user_id == me.id).values(revoked_at=datetime.now(UTC)))
    pair = await _issue_tokens(db, me.id)
    await db.commit()
    return pair


@router.post('/password/reset', response_model=TokenPair)
async def password_reset(payload: PasswordReset, db: AsyncSession = Depends(get_db)):
    await verify_otp(OtpVerify(phone=payload.phone, code=payload.code), db)
    user = await db.scalar(select(User).where(User.phone == payload.phone).with_for_update())
    user.password_hash = await hash_password(payload.password)
    await db.execute(update(RefreshToken).where(RefreshToken.user_id == user.id).values(revoked_at=datetime.now(UTC)))
    pair = await _issue_tokens(db, user.id)
    await db.commit()
    return pair


@router.post('/google', response_model=TokenPair)
async def google_login(payload: GoogleLogin, db: AsyncSession = Depends(get_db)):
    identity = await google_identity(payload.id_token)
    subject = identity['sub']
    await _lock_identifier(db, 'google:' + subject)
    user = await db.scalar(select(User).where(User.google_sub == subject))
    is_new = user is None
    if user is None:
        email = identity['email'].strip().lower()
        await _lock_identifier(db, 'email:' + email)
        # Never silently attach a Google identity to an existing local account.
        existing = await db.scalar(select(User.id).where(User.email == email))
        if existing:
            raise HTTPException(409, 'Bu email boshqa hisobga biriktirilgan. Avval o‘sha hisobga kiring.')
        user = User(phone=None, email=email, google_sub=subject,
                    first_name=str(identity.get('given_name', ''))[:80],
                    last_name=str(identity.get('family_name', ''))[:80], trust_score=0)
        db.add(user)
        await db.flush()
        for step, hint, weight in STARTER_STEPS:
            db.add(VerificationStep(user_id=user.id, step=step, hint=hint, weight=weight, state='todo'))
    if user.is_deleted:
        raise HTTPException(401, "Hisob o'chirilgan.")
    user.last_seen_at = datetime.now(UTC)
    pair = await _issue_tokens(db, user.id)
    await db.commit()
    return TokenPair(access_token=pair.access_token, refresh_token=pair.refresh_token, is_new_user=is_new)
