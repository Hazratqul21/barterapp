from functools import lru_cache
from pathlib import Path
from typing import Literal
from urllib.parse import urlsplit

from pydantic_settings import BaseSettings, SettingsConfigDict

GOOGLE_JWKS_URL = "https://www.googleapis.com/oauth2/v3/certs"

#: Repository root — `api/`, two levels up from this file.
_API_ROOT = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    #: development | test | production. Only `production` switches on the
    #: strict start-up checks in `_guard_production`. A typo ("prod") is an
    #: error rather than a silent fall back to development rules.
    app_env: Literal["development", "test", "production"] = "development"

    database_url: str = "postgresql+asyncpg://barter:barter@localhost:5434/barter"

    #: Where uploaded listing photos land. A directory on the API host while the
    #: product is one box; swapping this for an S3 client is a change inside
    #: `api/uploads.py` alone.
    media_root: Path = _API_ROOT / "media"
    media_url_prefix: str = "/media"

    jwt_secret: str = "dev-only-change-me"
    jwt_algorithm: str = "HS256"
    # Short, because a leaked access token cannot be revoked — it is only ever
    # as dangerous as the time left on it. The refresh token (which can be
    # revoked) carries the long-lived session.
    access_token_minutes: int = 60
    refresh_token_days: int = 60
    # A single-use hop for opening the WebSocket. Browsers can't set headers on a
    # WS handshake, so the token lives in the query string — where proxies and
    # server logs can capture it. Making that token a throwaway with a few
    # seconds of life means a captured one is worthless before it can be replayed.
    socket_token_seconds: int = 30

    # Every listing must carry all three; there is no silent fallback locale.
    supported_locales: tuple[str, ...] = ("uz", "ru", "en")
    default_locale: str = "uz"

    #: Everything is priced in so'm; `Money.minor` is tiyin (1/100 so'm).
    default_currency: str = "UZS"

    #: Free listings a new account gets before the plan starts charging.
    free_listing_quota: int = 2

    # In development set OTP_DEBUG=true in your .env so the OTP code comes back
    # in the response. The default is OFF so a forgotten .env in production
    # cannot leak verification codes.
    otp_debug: bool = False
    otp_ttl_seconds: int = 300

    # How many codes a single phone may request inside the window before the
    # endpoint starts refusing. Without this a caller can make the server send
    # (and pay for) unlimited SMS to any number, or grind through codes.
    otp_rate_max: int = 5
    otp_rate_window_seconds: int = 900

    # SMS — Eskiz (notify.eskiz.uz). Bo'sh bo'lsa quruq rejim: SMS ketmaydi,
    # matn logga yoziladi. Kalitlar faqat .env dan keladi va hech qayerda
    # chop etilmaydi.
    eskiz_email: str = ""
    eskiz_password: str = ""
    #: Tasdiqlangan alfanumerik jo'natuvchi. "4546" — Eskizning sinov nomi;
    #: haqiqiy nom shartnoma imzolangach beriladi.
    eskiz_sender: str = "4546"
    #: Eskiz har bir matnni oldindan tasdiqlaydi va tasdiqlanmagani jimgina
    #: yetkazilmaydi. Shu sababli matn shakli sozlamada — tasdiq boshqa so'z
    #: bilan kelsa, kod emas, .env o'zgaradi.
    eskiz_otp_template: str = "MAB: tasdiqlash kodi {code}. Hech kimga aytmang."
    #: SMS yuborilmasa ro'yxatdan o'tish to'xtatilsinmi. Ishlab chiqarishda
    #: albatta ha: aks holda odam kod kutadi, kod kelmaydi va sabab
    #: hech qayerda ko'rinmaydi.
    sms_required: bool = False
    #: Vaqtinchalik: Eskiz shartnomasi kelguncha productionni SMS'siz ishga
    #: tushirish. Kodlar foydalanuvchiga bormaydi — faqat server logida
    #: (journalctl -u mab-api) ko'rinadi, ya'ni faqat jamoa kira oladi.
    #: Eskiz ulangach albatta o'chiring.
    sms_optional: bool = False

    # Payme (Merchant API). Bo'sh bo'lsa to'lov o'chiq: buyurtma yaratib
    # bo'lmaydi va Payme endpoint'i har so'rovni avtorizatsiya xatosi bilan
    # qaytaradi. Kalit faqat .env dan keladi va hech qayerda chop etilmaydi.
    #: Kassa ID'si (Payme biznes kabinetidagi "ID kassy").
    payme_merchant_id: str = ""
    #: Kassa kaliti. Sinovda — test kaliti, jangovar rejimda — asosiy kalit.
    payme_key: str = ""
    #: https://test.paycom.uz — sinov (sandbox), https://checkout.paycom.uz — jangovar.
    payme_checkout_url: str = "https://test.paycom.uz"
    #: To'lovdan keyin foydalanuvchi qaytadigan sahifa; `{order_id}` buyurtma
    #: raqami bilan almashtiriladi.
    payme_return_url: str = "https://mab.uz/payments/return?order={order_id}"

    # Google orqali kirish. Bo'sh bo'lsa o'chiq: /auth/google 404 qaytaradi.
    #: Google Cloud'dagi OAuth "Web application" client ID (ilova ham shuni
    #: `serverClientId` sifatida ishlatadi, shuning uchun token aud'i shu).
    #: Bir nechta bo'lishi mumkin: ["...web...", "...ios..."]. Bular maxfiy emas.
    google_client_ids: tuple[str, ...] = ()
    #: Google kalitlari. Faqat testda o'zgartiriladi.
    google_jwks_url: str = GOOGLE_JWKS_URL

    #: Ommaviy sayt. Huquqiy hujjatlar shu domenda ochiladi
    #: (https://mab.uz/privacy — nginx ularni API'dan oladi).
    public_web_url: str = "https://mab.uz"

    #: F01: also check the reverse direction (do they want what I have?) and
    #: rank two-way fits first. Off restores the one-way matcher.
    matching_mutual: bool = True

    cors_origins: tuple[str, ...] = (
        "http://localhost:3000",
        "http://localhost:5173",
        "http://localhost:8080",
    )

    @property
    def is_production(self) -> bool:
        return self.app_env == "production"

    @property
    def google_enabled(self) -> bool:
        return bool(self.google_client_ids)

    @property
    def payme_enabled(self) -> bool:
        return bool(self.payme_merchant_id and self.payme_key)

    @property
    def cors_origin_regex(self) -> str | None:
        """Loopback on any port for development; nothing extra in production."""
        return None if self.is_production else LOOPBACK_ORIGIN_REGEX


#: Flutter web picks a fresh port on every run, and reaches the host as both
#: localhost and 127.0.0.1. Never sent in production: a browser page on the
#: user's own machine must not be able to call the real API with credentials.
LOOPBACK_ORIGIN_REGEX = r"http://(localhost|127\.0\.0\.1)(:\d+)?"
_LOOPBACK_HOSTS = {"localhost", "127.0.0.1", "0.0.0.0", "::1", "[::1]"}


#: The value `jwt_secret` ships with. A server still running on it will accept
#: a token anyone can mint, which means anyone can be anyone.
DEV_JWT_SECRET = "dev-only-change-me"


class InsecureConfiguration(RuntimeError):
    """Raised at import time rather than letting the server take real traffic."""


def _guard(settings: Settings) -> None:
    """
    Refuse to start in a configuration that would hand out accounts.

    The JWT secret check is unconditional: even in debug mode, a leaked
    dev secret lets anyone forge tokens. The OTP_DEBUG flag only controls
    whether codes appear in responses — it must not disable the key check.
    """
    if settings.jwt_secret == DEV_JWT_SECRET or len(settings.jwt_secret) < 32:
        if not settings.otp_debug:
            raise InsecureConfiguration(
                "JWT_SECRET hali standart yoki juda qisqa. Ishlab chiqarishda bu "
                "har kimga istalgan hisobga kirish imkonini beradi.\n"
                "Yangi kalit: python -c \"import secrets; "
                'print(secrets.token_urlsafe(48))"'
            )
        import warnings
        warnings.warn(
            "JWT_SECRET hali standart. OTP_DEBUG=true bo'lgani uchun server "
            "ishlaydi, lekin bu kalit bilan ishlab chiqarishga chiqmang.",
            stacklevel=2,
        )


def production_problems(settings: Settings) -> list[str]:
    """
    Everything that makes this configuration unfit for real users.

    Collected rather than raised one by one, so a deploy fails once with the
    full list instead of once per mistake.
    """
    problems: list[str] = []
    if settings.otp_debug:
        problems.append(
            "OTP_DEBUG=true: tasdiqlash kodi HTTP javobida qaytadi — istalgan "
            "odam istalgan hisobga kiradi. OTP_DEBUG=false qiling."
        )
    if settings.jwt_secret == DEV_JWT_SECRET or len(settings.jwt_secret) < 32:
        problems.append(
            "JWT_SECRET standart yoki 32 belgidan qisqa. Yangi kalit: "
            "python -c \"import secrets; print(secrets.token_urlsafe(48))\""
        )
    if settings.sms_optional:
        pass  # get_settings() ogohlantiradi; qolgan tekshiruvlar o'z joyida.
    elif not (settings.eskiz_email and settings.eskiz_password):
        problems.append(
            "SMS sozlanmagan: ESKIZ_EMAIL va ESKIZ_PASSWORD bo'sh — kodlar "
            "foydalanuvchiga yetib bormaydi. Vaqtincha SMS'siz ishga "
            "tushirish uchun: SMS_OPTIONAL=true."
        )
    if not settings.sms_required and not settings.sms_optional:
        problems.append(
            "SMS_REQUIRED=false: SMS ketmasa ham ro'yxatdan o'tish jimgina "
            "davom etadi. SMS_REQUIRED=true qiling."
        )
    if bool(settings.payme_merchant_id) != bool(settings.payme_key):
        problems.append(
            "Payme yarim sozlangan: PAYME_MERCHANT_ID va PAYME_KEY ikkalasi "
            "ham to'ldirilishi (yoki ikkalasi ham bo'sh qolishi) kerak."
        )
    if settings.google_jwks_url != GOOGLE_JWKS_URL:
        problems.append(
            "GOOGLE_JWKS_URL o'zgartirilgan: Google tokenini boshqa kalit bilan "
            "tekshirish istalgan odamga istalgan hisob bilan kirish imkonini "
            "beradi. Bu qatorni .env dan olib tashlang."
        )
    if not settings.cors_origins:
        problems.append("CORS_ORIGINS bo'sh: veb-ilova domeni ko'rsatilmagan.")
    for origin in settings.cors_origins:
        if "*" in origin:
            problems.append(
                f"CORS_ORIGINS da wildcard ({origin}): cookie/token bilan "
                "birga ishlatish xavfli. Aniq domen yozing."
            )
            continue
        parts = urlsplit(origin)
        if parts.scheme != "https":
            problems.append(f"CORS_ORIGINS faqat https bo'lishi kerak: {origin}")
        if (parts.hostname or "") in _LOOPBACK_HOSTS:
            problems.append(f"CORS_ORIGINS da lokal manzil: {origin}")
    return problems


def _guard_production(settings: Settings) -> None:
    problems = production_problems(settings)
    if problems:
        raise InsecureConfiguration(
            "APP_ENV=production, lekin sozlamalar xavfsiz emas:\n"
            + "\n".join(f"  - {p}" for p in problems)
        )


@lru_cache
def get_settings() -> Settings:
    settings = Settings()
    if settings.is_production:
        _guard_production(settings)
        if settings.sms_optional:
            import warnings
            warnings.warn(
                "SMS_OPTIONAL=true: SMS yuborilmaydi, tasdiqlash kodlari faqat "
                "server logida. Eskiz ulangach o'chiring.",
                stacklevel=2,
            )
    else:
        _guard(settings)
    return settings


settings = get_settings()
