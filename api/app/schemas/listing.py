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
