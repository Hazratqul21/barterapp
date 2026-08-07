from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.db.session import get_db
from app.models.user import User

bearer = HTTPBearer(auto_error=False)


def _encode(subject: str, kind: str, lifetime: timedelta) -> str:
    now = datetime.now(UTC)
    return jwt.encode(
        {"sub": subject, "typ": kind, "iat": now, "exp": now + lifetime},
        settings.jwt_secret,
        algorithm=settings.jwt_algorithm,
    )


def create_access_token(user_id: uuid.UUID) -> str:
    return _encode(
        str(user_id), "access", timedelta(minutes=settings.access_token_minutes)
    )


def create_refresh_token(user_id: uuid.UUID) -> str:
    return _encode(
        str(user_id), "refresh", timedelta(days=settings.refresh_token_days)
    )


def decode_token(token: str, expected: str) -> uuid.UUID:
    try:
        payload = jwt.decode(
            token, settings.jwt_secret, algorithms=[settings.jwt_algorithm]
        )
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED, "Sessiya muddati tugagan. Qaytadan kiring."
        )
    except jwt.PyJWTError:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Token yaroqsiz.")

    if payload.get("typ") != expected:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Token turi mos emas.")
    return uuid.UUID(payload["sub"])


async def current_user(
    creds: HTTPAuthorizationCredentials | None = Depends(bearer),
    db: AsyncSession = Depends(get_db),
) -> User:
    if creds is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Kirish talab qilinadi.")

    user_id = decode_token(creds.credentials, "access")
    user = await db.scalar(select(User).where(User.id == user_id))
    if user is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Foydalanuvchi topilmadi.")
    return user


async def optional_user(
    creds: HTTPAuthorizationCredentials | None = Depends(bearer),
    db: AsyncSession = Depends(get_db),
) -> User | None:
    """The feed works signed out, but hides your own listings when signed in."""
    if creds is None:
        return None
    try:
        user_id = decode_token(creds.credentials, "access")
    except HTTPException:
        return None
    return await db.scalar(select(User).where(User.id == user_id))
