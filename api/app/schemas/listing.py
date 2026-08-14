from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import Field, model_validator

from app.models.listing import ListingStatus, ListingTag
from app.schemas.common import ApiModel, Money
from app.schemas.user import TraderBrief


class ListingCard(ApiModel):
    """What the feed needs — nothing more, so the list endpoint stays cheap."""

    id: uuid.UUID
    tag: ListingTag
    title: str
    image_url: str | None = None
    image_alt: str
    wants_summary: str
    value: Money
    distance_km: float | None = None
    cash_ok: bool
    is_premium: bool
    posted_at: datetime
    owner: TraderBrief
    #: Kirgan foydalanuvchi buni saqlaganmi. Mehmon uchun doim False.
    #: Lentaning o'zida keladi, aks holda mijoz har karta uchun alohida
    #: so'rov yuborishga yoki yurakni noto'g'ri holatda chizishga majbur.
    is_favorite: bool = False


class ListingDetail(ListingCard):
    status: ListingStatus
    description: str
    category: str
    condition: str
    quantity: str
    gallery: list[str] = Field(default_factory=list)
    wants: list[str] = Field(default_factory=list)


class TranslatedText(ApiModel):
    """
    A field in every supported language. Required on write: the server rejects a
    listing that is missing one, rather than quietly serving Uzbek to a Russian
    reader.
    """

    uz: str = Field(min_length=1)
    ru: str = Field(min_length=1)
    en: str = Field(min_length=1)


class DesireIn(ApiModel):
    """
    What the owner will accept, in the shape the matcher reads.

    `listing_wants` holds the same wish as a sentence for a person to read;
    this holds it as a category and a value band for the algorithm. Both are
    written from the same form — the wording is free, the bounds are not, and
    trying to recover bounds from prose is what made the first matcher score on
    word overlap.
    """

    #: Null means "any offer" — the open desire the spec expects most people to
    #: pick, and which the matcher still admits, just scored lower.
    category: ListingTag | None = None
    min_value_minor: int | None = Field(default=None, ge=0)
    max_value_minor: int | None = Field(default=None, ge=0)
    #: The owner will top up in cash to reach something dearer.
    will_add_cash: bool = False
    #: The owner expects cash back and will take something cheaper.
    wants_cash: bool = False

    @model_validator(mode="after")
    def _band_ordered(self) -> DesireIn:
        low, high = self.min_value_minor, self.max_value_minor
        if low is not None and high is not None and low > high:
            raise ValueError("Eng kam qiymat eng ko‘p qiymatdan katta bo‘lishi mumkin emas.")
        return self


class ListingCreate(ApiModel):
    tag: ListingTag
    title: TranslatedText
    description: TranslatedText
    image_alt: TranslatedText
    category: TranslatedText
    condition: TranslatedText
    quantity: TranslatedText
    wants_summary: TranslatedText
    wants: list[TranslatedText] = Field(default_factory=list, max_length=8)
    #: Structured counterpart to `wants`. Optional on the wire, but a listing
    #: published without one can never appear in anybody's matches — so the
    #: endpoint derives a default rather than leaving it empty.
    desires: list[DesireIn] = Field(default_factory=list, max_length=8)
    photos: list[str] = Field(default_factory=list, max_length=10)
    value: Money
    cash_ok: bool = True
    latitude: float | None = None
    longitude: float | None = None


class ListingUpdate(ApiModel):
    """
    An edit to a listing you own. Every field is optional: the screen sends what
    changed, and anything left out keeps the value it already had.

    The lists are the exception to "optional means untouched" in spirit but not
    in mechanics — sending `photos` replaces the whole set rather than appending
    to it, because that is what a photo editor with a remove button does. The
    same holds for `wants` and `desires`. Leaving them out changes nothing.

    Translated fields stay all-or-nothing per field: a title arrives in three
    languages or not at all, so an edit can never leave the feed half-translated
    the way a per-locale patch would.
    """

    tag: ListingTag | None = None
    title: TranslatedText | None = None
    description: TranslatedText | None = None
    image_alt: TranslatedText | None = None
    category: TranslatedText | None = None
    condition: TranslatedText | None = None
    quantity: TranslatedText | None = None
    wants_summary: TranslatedText | None = None
    wants: list[TranslatedText] | None = Field(default=None, max_length=8)
    desires: list[DesireIn] | None = Field(default=None, max_length=8)
    photos: list[str] | None = Field(default=None, max_length=10)
    value: Money | None = None
    cash_ok: bool | None = None
    latitude: float | None = None
    longitude: float | None = None
