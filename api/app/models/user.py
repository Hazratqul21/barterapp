from __future__ import annotations

import uuid
from datetime import datetime
from typing import TYPE_CHECKING

import enum

from sqlalchemy import Boolean, CheckConstraint, DateTime, Enum, Float, Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, Timestamps, UUIDPrimaryKey

if TYPE_CHECKING:
    from app.models.listing import Listing


class UserType(str, enum.Enum):
    """
    A shop swapping dead stock and a person swapping a laptop behave nothing
    alike. B2B accounts get a company name from their tax id, a business badge,
    and the B2B filter in search.
    """

    individual = "individual"
    business = "business"


class User(Base, UUIDPrimaryKey, Timestamps):
    """
    The one place a person is described. Nothing else in the schema copies a
    name, photo, rating or trade count — they join to this row instead, which is
    what kept the prototype's feed, inbox and profile pages disagreeing.
    """

    __tablename__ = "users"

    phone: Mapped[str] = mapped_column(String(20), unique=True, nullable=False)
    first_name: Mapped[str] = mapped_column(String(80), nullable=False)
    last_name: Mapped[str] = mapped_column(String(80), nullable=False)
    user_type: Mapped[UserType] = mapped_column(
        Enum(UserType, name="user_type"), nullable=False, server_default="individual"
    )
    #: Company name for a business account; shown next to the person's own name.
    handle: Mapped[str | None] = mapped_column(String(120))
    #: STIR / INN. Required for business accounts, unique when present.
    tax_id: Mapped[str | None] = mapped_column(String(20), unique=True)
    avatar_url: Mapped[str | None] = mapped_column(Text)
    cover_url: Mapped[str | None] = mapped_column(Text)
    bio: Mapped[str | None] = mapped_column(Text)

    region: Mapped[str | None] = mapped_column(String(120))
    district: Mapped[str | None] = mapped_column(String(120))
    address: Mapped[str | None] = mapped_column(Text)

    locale: Mapped[str] = mapped_column(String(2), nullable=False, server_default="uz")

    # Denormalised only because it is expensive to recompute per request; a nightly
    # job rebuilds it from verification_steps. Never edited by hand.
    trust_score: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")
    is_verified: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default="false"
    )

    # Where this trader is. Distance is 30% of a match score, so a missing
    # location quietly costs a user their best matches.
    latitude: Mapped[float | None] = mapped_column(Float)
    longitude: Mapped[float | None] = mapped_column(Float)

    #: Rolling average reply time, shown as "usually replies in N minutes".
    responds_within_minutes: Mapped[int | None] = mapped_column(Integer)

    #: Free listings still available this month. The plan gives everyone a small
    #: quota, then charges per listing or by subscription.
    free_listings_left: Mapped[int] = mapped_column(
        Integer, nullable=False, server_default="2"
    )
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    listings: Mapped[list[Listing]] = relationship(
        back_populates="owner", cascade="all, delete-orphan"
    )

    __table_args__ = (
        CheckConstraint(
            "trust_score BETWEEN 0 AND 100", name="trust_score_range"
        ),
        CheckConstraint("locale IN ('uz', 'ru', 'en')", name="locale_supported"),
        CheckConstraint(
            "user_type <> 'business' OR tax_id IS NOT NULL",
            name="business_needs_tax_id",
        ),
    )

    @property
    def full_name(self) -> str:
        return f"{self.first_name} {self.last_name}".strip()


class OtpChallenge(Base, UUIDPrimaryKey):
    """
    A short-lived login code. Rows are consumed on verify and swept by age, so a
    code can never be replayed.
    """

    __tablename__ = "otp_challenges"

    phone: Mapped[str] = mapped_column(String(20), nullable=False, index=True)
    # The HMAC of the code, never the code itself: a database dump, a log line
    # or a stray backup then leaks nothing usable, since the hash cannot be
    # turned back into the six digits without the server secret.
    code_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    consumed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    attempts: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    user_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True))
