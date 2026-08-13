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


def _encode(
    subject: str, kind: str, lifetime: timedelta, jti: str | None = None
) -> str:
    now = datetime.now(UTC)
    claims: dict[str, object] = {
        "sub": subject,
        "typ": kind,
        "iat": now,
        "exp": now + lifetime,
    }
    if jti is not None:
        claims["jti"] = jti
    return jwt.encode(claims, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def create_access_token(user_id: uuid.UUID) -> str:
    return _encode(
        str(user_id), "access", timedelta(minutes=settings.access_token_minutes)
    )


def refresh_lifetime() -> timedelta:
    return timedelta(days=settings.refresh_token_days)


def create_refresh_token(user_id: uuid.UUID, jti: uuid.UUID) -> str:
    """The token carries the id of its own database row as `jti`."""
    return _encode(str(user_id), "refresh", refresh_lifetime(), jti=str(jti))


def create_socket_token(user_id: uuid.UUID) -> str:
    """A few-seconds ticket for the WebSocket handshake. The long-lived access
    token never travels in a query string; this throwaway does instead."""
    return _encode(
        str(user_id), "socket", timedelta(seconds=settings.socket_token_seconds)
    )


def decode_token(token: str, expected: str) -> uuid.UUID:
    return _decode(token, expected)["sub"]


def decode_refresh(token: str) -> tuple[uuid.UUID, uuid.UUID]:
    """The user id and the token's own row id (jti)."""
    payload = _decode(token, "refresh")
    jti = payload.get("jti")
    if jti is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Token yaroqsiz.")
    return payload["sub"], uuid.UUID(str(jti))


def _decode(token: str, expected: str) -> dict:
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
    payload["sub"] = uuid.UUID(payload["sub"])
    return payload


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
