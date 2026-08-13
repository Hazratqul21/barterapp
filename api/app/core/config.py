from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

#: Repository root — `api/`, two levels up from this file.
_API_ROOT = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "postgresql+asyncpg://barter:barter@localhost:5434/barter"

    #: Where uploaded listing photos land. A directory on the API host while the
    #: product is one box; swapping this for an S3 client is a change inside
    #: `api/uploads.py` alone.
    media_root: Path = _API_ROOT / "media"
    media_url_prefix: str = "/media"

    jwt_secret: str = "dev-only-change-me"
    jwt_algorithm: str = "HS256"
    access_token_minutes: int = 60 * 24
    refresh_token_days: int = 60

    # Every listing must carry all three; there is no silent fallback locale.
    supported_locales: tuple[str, ...] = ("uz", "ru", "en")
    default_locale: str = "uz"

    #: Everything is priced in so'm; `Money.minor` is tiyin (1/100 so'm).
    default_currency: str = "UZS"

    #: Free listings a new account gets before the plan starts charging.
    free_listing_quota: int = 2

    # In development the OTP is not sent anywhere — it is returned by the request
    # endpoint so the app can be driven end to end without an SMS provider.
    otp_debug: bool = True
    otp_ttl_seconds: int = 300

    # How many codes a single phone may request inside the window before the
    # endpoint starts refusing. Without this a caller can make the server send
    # (and pay for) unlimited SMS to any number, or grind through codes.
    otp_rate_max: int = 5
    otp_rate_window_seconds: int = 900

    cors_origins: tuple[str, ...] = (
        "http://localhost:3000",
        "http://localhost:5173",
        "http://localhost:8080",
    )


#: The value `jwt_secret` ships with. A server still running on it will accept
#: a token anyone can mint, which means anyone can be anyone.
DEV_JWT_SECRET = "dev-only-change-me"


class InsecureConfiguration(RuntimeError):
    """Raised at import time rather than letting the server take real traffic."""


def _guard(settings: Settings) -> None:
    """
    Refuse to start in a configuration that would hand out accounts.

    `OTP_DEBUG=false` is taken as the signal that this is a real deployment:
    development wants the code back in the response, production must not have
    it. Once that is off, the signing key has to be a real one.

    A check that only logs would be read once and then scroll away. This is the
    kind of mistake that is invisible until it is exploited, so it stops the
    process instead.
    """
    if settings.otp_debug:
        return

    if settings.jwt_secret == DEV_JWT_SECRET or len(settings.jwt_secret) < 32:
        raise InsecureConfiguration(
            "JWT_SECRET hali standart yoki juda qisqa. Ishlab chiqarishda bu "
            "har kimga istalgan hisobga kirish imkonini beradi.\n"
            "Yangi kalit: python -c \"import secrets; "
            'print(secrets.token_urlsafe(48))"'
        )


@lru_cache
def get_settings() -> Settings:
    settings = Settings()
    _guard(settings)
    return settings


settings = get_settings()
