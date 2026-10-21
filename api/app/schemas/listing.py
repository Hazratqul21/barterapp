from __future__ import annotations

import uuid
from datetime import datetime

from typing import ClassVar

from pydantic import Field, model_validator

from app.models.listing import ListingStatus, ListingTag
from app.schemas.common import ApiModel, MediaUrl, Money
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
    #: Where the goods are (the listing's own, not the owner's).
    region: str | None = None
    district: str | None = None
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


#: The order a missing language borrows from: the author's own words first.
LOCALES = ("uz", "ru", "en")


class TranslatedText(ApiModel):
    """
    A field in the supported languages. One is enough on write.

    Asking for all three made publishing a listing eighteen text boxes long, and
    people gave up at the second step: a farmer selling rice writes in the
    language they speak. A language left out is filled with the author's own
    text, the way every classifieds site shows a listing as it was written; all
    three rows still exist, so readers, search and edits work as before.
    """

    uz: str = ""
    ru: str = ""
    en: str = ""

    #: Length per language. Matches the column, so an overlong title is a 422
    #: with a reason, not a 500 from the database; the description's cap keeps
    #: one listing from making every search scan megabytes.
    _max: ClassVar[int] = 5000

    @model_validator(mode="after")
    def _fill_missing(self) -> TranslatedText:
        given = {code: getattr(self, code).strip() for code in LOCALES}
        source = next((text for text in given.values() if text), None)
        if source is None:
            raise ValueError("Matnni kamida bitta tilda yozing.")
        if any(len(text) > self._max for text in given.values()):
            raise ValueError(f"Matn {self._max} belgidan oshmasin.")
        for code, text in given.items():
            object.__setattr__(self, code, text or source)
        return self


class Text80(TranslatedText):
    _max: ClassVar[int] = 80


class Text120(TranslatedText):
    _max: ClassVar[int] = 120


class Text160(TranslatedText):
    _max: ClassVar[int] = 160


class Text200(TranslatedText):
    _max: ClassVar[int] = 200


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
    title: Text160
    description: TranslatedText
    image_alt: Text200
    category: Text80
    condition: Text80
    quantity: Text80
    wants_summary: Text160
    wants: list[Text120] = Field(default_factory=list, max_length=8)
    #: Structured counterpart to `wants`. Optional on the wire, but a listing
    #: published without one can never appear in anybody's matches — so the
    #: endpoint derives a default rather than leaving it empty.
    desires: list[DesireIn] = Field(default_factory=list, max_length=8)
    photos: list[MediaUrl] = Field(default_factory=list, max_length=10)
    value: Money
    cash_ok: bool = True
    latitude: float | None = None
    longitude: float | None = None
    #: Defaults to the owner's region. One of `/regions`.
    region: str | None = Field(default=None, max_length=120)
    district: str | None = Field(default=None, max_length=120)


class ListingUpdate(ApiModel):
    """
    An edit to a listing you own. Every field is optional: the screen sends what
    changed, and anything left out keeps the value it already had.

    The lists are the exception to "optional means untouched" in spirit but not
    in mechanics — sending `photos` replaces the whole set rather than appending
    to it, because that is what a photo editor with a remove button does. The
    same holds for `wants` and `desires`. Leaving them out changes nothing.

    Translated fields are replaced whole: a title sent in one language becomes
    that title in every language, so an edit never leaves an old wording
    behind in a locale the author did not touch.
    """

    tag: ListingTag | None = None
    title: Text160 | None = None
    description: TranslatedText | None = None
    image_alt: Text200 | None = None
    category: Text80 | None = None
    condition: Text80 | None = None
    quantity: Text80 | None = None
    wants_summary: Text160 | None = None
    wants: list[Text120] | None = Field(default=None, max_length=8)
    desires: list[DesireIn] | None = Field(default=None, max_length=8)
    region: str | None = Field(default=None, max_length=120)
    district: str | None = Field(default=None, max_length=120)
    photos: list[MediaUrl] | None = Field(default=None, max_length=10)
    value: Money | None = None
    cash_ok: bool | None = None
    latitude: float | None = None
    longitude: float | None = None
