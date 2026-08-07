from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "postgresql+asyncpg://barter:barter@localhost:5434/barter"

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

    cors_origins: tuple[str, ...] = (
        "http://localhost:3000",
        "http://localhost:5173",
        "http://localhost:8080",
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
