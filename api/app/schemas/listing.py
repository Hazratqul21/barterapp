from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import Field

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
    photos: list[str] = Field(default_factory=list, max_length=10)
    value: Money
    cash_ok: bool = True
    latitude: float | None = None
    longitude: float | None = None
