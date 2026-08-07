from __future__ import annotations

import enum
import uuid
from typing import TYPE_CHECKING

from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    Enum,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, Timestamps, UUIDPrimaryKey

if TYPE_CHECKING:
    from app.models.user import User


class ListingTag(str, enum.Enum):
    agri = "agri"
    livestock = "livestock"
    machinery = "machinery"
    transport = "transport"
    electronics = "electronics"
    construction = "construction"


class ListingStatus(str, enum.Enum):
    """Names follow the business spec so code and product talk about the same thing."""

    draft = "draft"
    active = "active"
    in_negotiation = "in_negotiation"
    completed = "completed"
    archived = "archived"


class Listing(Base, UUIDPrimaryKey, Timestamps):
    """
    One side of a trade. Everything about the owner lives on `users` — this table
    holds only `owner_id`, so a renamed trader can never leave a stale name on a
    feed card.
    """

    __tablename__ = "listings"

    owner_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    tag: Mapped[ListingTag] = mapped_column(
        Enum(ListingTag, name="listing_tag"), nullable=False
    )
    status: Mapped[ListingStatus] = mapped_column(
        Enum(ListingStatus, name="listing_status"),
        nullable=False,
        server_default="active",
    )

    # Money is an integer in minor units plus a currency, never a formatted
    # string: the prototype stored "$5,000" and could not sort or compare it.
    # UZS by default — this is an Uzbek marketplace and every price in the
    # business plan is quoted in so'm.
    value_minor: Mapped[int] = mapped_column(BigInteger, nullable=False)
    currency: Mapped[str] = mapped_column(String(3), nullable=False, server_default="UZS")

    cash_ok: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="true")
    is_premium: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default="false"
    )

    # Copied from the owner at publish time so a feed query can compute distance
    # without joining users, and so moving house does not rewrite old listings.
    latitude: Mapped[float | None] = mapped_column(Float)
    longitude: Mapped[float | None] = mapped_column(Float)

    owner: Mapped[User] = relationship(back_populates="listings")
    translations: Mapped[list[ListingTranslation]] = relationship(
        back_populates="listing", cascade="all, delete-orphan", lazy="selectin"
    )
    photos: Mapped[list[ListingPhoto]] = relationship(
        back_populates="listing",
        cascade="all, delete-orphan",
        lazy="selectin",
        order_by="ListingPhoto.position",
    )
    wants: Mapped[list[ListingWant]] = relationship(
        back_populates="listing",
        cascade="all, delete-orphan",
        lazy="selectin",
        order_by="ListingWant.position",
    )

    __table_args__ = (
        CheckConstraint("value_minor >= 0", name="value_non_negative"),
        Index("ix_listings_feed", "status", "tag", "created_at"),
    )


class ListingTranslation(Base):
    """
    Title, description and alt text in one language. The API refuses to publish a
    listing that is missing any supported locale, so a Russian reader never falls
    through to Uzbek without being told.
    """

    __tablename__ = "listing_translations"

    listing_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("listings.id", ondelete="CASCADE"),
        primary_key=True,
    )
    locale: Mapped[str] = mapped_column(String(2), primary_key=True)

    title: Mapped[str] = mapped_column(String(160), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    image_alt: Mapped[str] = mapped_column(String(200), nullable=False)
    category: Mapped[str] = mapped_column(String(80), nullable=False)
    condition: Mapped[str] = mapped_column(String(80), nullable=False)
    quantity: Mapped[str] = mapped_column(String(80), nullable=False)
    wants_summary: Mapped[str] = mapped_column(String(160), nullable=False)

    listing: Mapped[Listing] = relationship(back_populates="translations")

    __table_args__ = (
        CheckConstraint("locale IN ('uz', 'ru', 'en')", name="locale_supported"),
    )


class ListingPhoto(Base, UUIDPrimaryKey):
    __tablename__ = "listing_photos"

    listing_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("listings.id", ondelete="CASCADE"), nullable=False
    )
    url: Mapped[str] = mapped_column(Text, nullable=False)
    position: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")

    listing: Mapped[Listing] = relationship(back_populates="photos")

    __table_args__ = (
        UniqueConstraint("listing_id", "position", name="uq_listing_photo_position"),
    )


class ListingWant(Base, UUIDPrimaryKey):
    """One thing the owner would accept in return."""

    __tablename__ = "listing_wants"

    listing_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("listings.id", ondelete="CASCADE"), nullable=False
    )
    position: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")

    listing: Mapped[Listing] = relationship(back_populates="wants")
    translations: Mapped[list[ListingWantTranslation]] = relationship(
        back_populates="want", cascade="all, delete-orphan", lazy="selectin"
    )


class ListingWantTranslation(Base):
    __tablename__ = "listing_want_translations"

    want_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("listing_wants.id", ondelete="CASCADE"),
        primary_key=True,
    )
    locale: Mapped[str] = mapped_column(String(2), primary_key=True)
    label: Mapped[str] = mapped_column(String(120), nullable=False)

    want: Mapped[ListingWant] = relationship(back_populates="translations")

    __table_args__ = (
        CheckConstraint("locale IN ('uz', 'ru', 'en')", name="locale_supported"),
    )
