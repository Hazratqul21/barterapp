"""Credential verification; never accept an email supplied by the client as proof."""
import jwt
from argon2 import PasswordHasher
from argon2.exceptions import VerificationError, InvalidHashError
from fastapi import HTTPException
from starlette.concurrency import run_in_threadpool
from app.core.config import settings

hasher = PasswordHasher(time_cost=2, memory_cost=19456, parallelism=1)
_dummy_hash = hasher.hash('dummy-password-not-an-account')
# Manzil sozlamada: test o'z kalitini beradi; productionda boshqa manzil
# qo'yilsa server ishga tushmaydi (config.production_problems).
_keys = jwt.PyJWKClient(settings.google_jwks_url, cache_keys=True, lifespan=6 * 3600, timeout=10)

async def hash_password(password: str) -> str:
    return await run_in_threadpool(hasher.hash, password)

async def check_password(stored: str | None, password: str) -> bool:
    def verify():
        try:
            valid = hasher.verify(stored or _dummy_hash, password)
            return bool(stored) and valid
        except (VerificationError, InvalidHashError):
            return False
    return await run_in_threadpool(verify)

async def google_identity(token: str) -> dict:
    if not settings.google_client_ids:
        raise HTTPException(503, 'Google orqali kirish hali sozlanmagan.')
    def verify():
        key = _keys.get_signing_key_from_jwt(token).key
        claims = jwt.decode(token, key, algorithms=['RS256'],
            audience=list(settings.google_client_ids),
            issuer=['https://accounts.google.com', 'accounts.google.com'],
            options={'require': ['exp', 'iat', 'sub', 'aud', 'iss', 'email']})
        if claims.get('email_verified') is not True:
            raise ValueError('unverified email')
        if not isinstance(claims['sub'], str) or not claims['sub'] or len(claims['sub']) > 255:
            raise ValueError('invalid subject')
        if not isinstance(claims['email'], str) or len(claims['email']) > 320:
            raise ValueError('invalid email')
        return claims
    try:
        return await run_in_threadpool(verify)
    except jwt.PyJWKClientConnectionError as exc:
        raise HTTPException(503, 'Google bilan aloqa vaqtincha mavjud emas.') from exc
    except (jwt.PyJWTError, ValueError, TypeError, KeyError) as exc:
        raise HTTPException(401, 'Google tasdiqlashi yaroqsiz. Qaytadan kiring.') from exc
