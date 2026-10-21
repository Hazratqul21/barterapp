"""Google ID token'ini tekshirish.

Ilova (yoki sayt) Google'dan ID token oladi va uni bizga yuboradi. Bu yerda
token haqiqatan Google imzolagani, aynan bizning ilovamiz uchun berilgani
(`aud`) va muddati o'tmagani tekshiriladi. Google'ga alohida so'rov
yuborilmaydi: ochiq kalitlar bir marta olinadi va keshda turadi.
"""

from __future__ import annotations

from dataclasses import dataclass
from functools import lru_cache

import jwt
from jwt import PyJWKClient
from starlette.concurrency import run_in_threadpool

from app.core.config import settings

_ISSUERS = ("accounts.google.com", "https://accounts.google.com")


class GoogleTokenError(Exception):
    pass


@dataclass(frozen=True)
class GoogleIdentity:
    sub: str
    email: str | None
    email_verified: bool
    given_name: str
    family_name: str
    picture: str | None


@lru_cache
def _jwks(url: str) -> PyJWKClient:
    # Kalitlar soatlab o'zgarmaydi; noma'lum `kid` kelsa, PyJWKClient o'zi
    # bir marta qayta oladi.
    return PyJWKClient(url, cache_keys=True, lifespan=6 * 3600, timeout=10)


def _verify_sync(token: str) -> dict:
    try:
        key = _jwks(settings.google_jwks_url).get_signing_key_from_jwt(token)
        return jwt.decode(
            token,
            key.key,
            algorithms=["RS256"],
            audience=list(settings.google_client_ids),
            issuer=_ISSUERS,
            options={"require": ["exp", "iat", "iss", "aud", "sub"]},
            leeway=60,
        )
    except jwt.PyJWKClientError as exc:
        raise GoogleTokenError(f"Google kalitlari olinmadi: {exc}") from exc
    except jwt.InvalidTokenError as exc:
        raise GoogleTokenError(str(exc)) from exc


async def verify_id_token(token: str) -> GoogleIdentity:
    # PyJWKClient sinxron (urllib) — event loop'ni to'sib qo'ymasin.
    claims = await run_in_threadpool(_verify_sync, token)
    email = claims.get("email")
    return GoogleIdentity(
        sub=str(claims["sub"]),
        email=email.strip().lower()[:254] if isinstance(email, str) else None,
        email_verified=claims.get("email_verified") in (True, "true"),
        given_name=str(claims.get("given_name") or "")[:80],
        family_name=str(claims.get("family_name") or "")[:80],
        picture=claims.get("picture") if isinstance(claims.get("picture"), str) else None,
    )
