from __future__ import annotations

import enum
import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Integer,
    String,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, Timestamps, UUIDPrimaryKey


class NotifyKind(str, enum.Enum):
    offer = "offer"
    match = "match"
    message = "message"
    system = "system"


class NotifyTargetType(str, enum.Enum):
    chat = "chat"
    matches = "matches"
    verification = "verification"
    listing = "listing"


class Notification(Base, UUIDPrimaryKey):
    """
    Carries its own destination. The prototype guessed one from `kind`, which sent
    two unrelated offers into the same chat thread.
    """

    __tablename__ = "notifications"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    kind: Mapped[NotifyKind] = mapped_column(
        Enum(NotifyKind, name="notify_kind"), nullable=False
    )
    target_type: Mapped[NotifyTargetType] = mapped_column(
        Enum(NotifyTargetType, name="notify_target_type"), nullable=False
    )
    # Null only for targets that need no id, such as the matches tab.
    target_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True))

    title: Mapped[str] = mapped_column(String(200), nullable=False)
    body: Mapped[str] = mapped_column(String(400), nullable=False)
    avatar_url: Mapped[str | None] = mapped_column(String(500))

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    __table_args__ = (
        CheckConstraint(
            "(target_type = 'matches') OR (target_id IS NOT NULL)",
            name="target_id_required",
        ),
        Index("ix_notifications_feed", "user_id", "created_at"),
    )


class VerificationState(str, enum.Enum):
    todo = "todo"
    pending = "pending"
    done = "done"


class VerificationStep(Base, UUIDPrimaryKey, Timestamps):
    __tablename__ = "verification_steps"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    # phone | passport | business | bank | video
    step: Mapped[str] = mapped_column(String(40), nullable=False)
    state: Mapped[VerificationState] = mapped_column(
        Enum(VerificationState, name="verification_state"),
        nullable=False,
        server_default="todo",
    )
    hint: Mapped[str | None] = mapped_column(String(200))
    weight: Mapped[int] = mapped_column(Integer, nullable=False, server_default="20")

    __table_args__ = (
        UniqueConstraint("user_id", "step", name="uq_verification_step"),
    )


class PaymentMethod(Base, UUIDPrimaryKey, Timestamps):
    __tablename__ = "payment_methods"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    brand: Mapped[str] = mapped_column(String(40), nullable=False)
    label: Mapped[str] = mapped_column(String(120), nullable=False)
    # Only ever the last four digits; full card numbers never reach this service.
    last4: Mapped[str] = mapped_column(String(4), nullable=False)
    expires: Mapped[str] = mapped_column(String(5), nullable=False)
    is_primary: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default="false"
    )

    __table_args__ = (
        CheckConstraint("last4 ~ '^[0-9]{4}$'", name="last4_digits"),
    )


class Match(Base, UUIDPrimaryKey):
    """
    A computed two-way fit. Recomputed by a job, never edited: the owner shown on
    a match card is always the owner of `their_listing_id`.
    """

    __tablename__ = "matches"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    my_listing_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("listings.id", ondelete="CASCADE"), nullable=False
    )
    their_listing_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("listings.id", ondelete="CASCADE"), nullable=False
    )
    score: Mapped[int] = mapped_column(Integer, nullable=False)
    computed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    dismissed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    __table_args__ = (
        CheckConstraint("score BETWEEN 0 AND 100", name="score_range"),
        CheckConstraint(
            "my_listing_id <> their_listing_id", name="distinct_listings"
        ),
        UniqueConstraint(
            "user_id", "my_listing_id", "their_listing_id", name="uq_match_pair"
        ),
    )
