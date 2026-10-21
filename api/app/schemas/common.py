from __future__ import annotations

from typing import Annotated, Generic, TypeVar
from urllib.parse import urlsplit

from pydantic import AfterValidator, BaseModel, ConfigDict, Field

T = TypeVar("T")


class ApiModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class Money(ApiModel):
    """
    Never a formatted string. The client formats with `intl` so "$5,000",
    "5 000 ₽" and "5 000 so'm" all come from one number.
    """

    minor: int = Field(description="Amount in the currency's smallest unit")
    currency: str = Field(min_length=3, max_length=3)


class Page(ApiModel, Generic[T]):
    items: list[T]
    next_cursor: str | None = Field(
        default=None, description="Pass back as ?cursor= to fetch the next page"
    )


def _own_media(url: str) -> str:
    """
    Faqat o'zimizga yuklangan surat (`/uploads` qaytargan havola).

    Ixtiyoriy havola qabul qilinsa, e'lon yoki xabar har ko'rgan odamning
    IP manzilini begona serverga yuboradigan "kuzatuv surati"ga aylanadi,
    `javascript:` kabi sxemalar esa keyinroq biror ekranda havola bo'lib
    qolishi mumkin.
    """
    from app.core.config import settings

    url = url.strip()
    if len(url) > 500:
        raise ValueError("Surat havolasi juda uzun.")
    parts = urlsplit(url)
    allowed = ("https",) if settings.is_production else ("https", "http")
    own_host = urlsplit(settings.public_api_url).netloc if settings.public_api_url else None
    if (
        parts.scheme not in allowed
        or not parts.netloc
        or (own_host and parts.netloc != own_host)
        or not parts.path.startswith(settings.media_url_prefix.rstrip("/") + "/")
        or ".." in parts.path
    ):
        raise ValueError("Suratni ilova orqali yuklang (/uploads).")
    return url


#: A photo the client uploaded through `/uploads` — nothing else.
MediaUrl = Annotated[str, AfterValidator(_own_media)]


def _https(url: str) -> str:
    url = url.strip()
    if len(url) > 500 or urlsplit(url).scheme != "https":
        raise ValueError("Havola https:// bilan boshlansin (500 belgigacha).")
    return url


#: An absolute https link set by a moderator (banner image and the like).
HttpsUrl = Annotated[str, AfterValidator(_https)]
