"""
F02 — what happens after "accept".

An accepted offer used to be a status and nothing else: the goods stayed on the
market, either side could mark the deal "completed" alone, and a dispute was a
dead end. These tables give the accept real consequences:

* `TradeAgreement` — the terms frozen at the moment of acceptance. A later
  counter, edit or price change cannot rewrite what both people agreed to.
* `Reservation` — every listing in the deal is held for it. One active
  reservation per listing, enforced by the database, so two deals can never
  both believe they own the same tractor.
* `TradeConfirmation` — each side says "done" separately; the deal completes
  only when both have.
* `Dispute` — pauses the deal and is settled by admin-configured rules or,
  above their limits, by an operator.
"""

from __future__ import annotations

import enum
import uuid
from datetime import datetime

from sqlalchemy import (
    BigInteger,
    Boolean,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, UUIDPrimaryKey


class TradeAgreement(Base, UUIDPrimaryKey):
    """The terms at acceptance, never edited. One per accepted offer."""

    __tablename__ = "trade_agreements"

    offer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("offers.id", ondelete="CASCADE"), nullable=False
    )
    #: {"wanted": {...}, "offered": [...], "cash_delta_minor": int,
    #:  "currency": str, "from_user_id": str, "to_user_id": str}
    terms: Mapped[dict] = mapped_column(JSONB, nullable=False)
    #: Worth of the whole deal (both sides' listings plus cash), in minor
    #: units — what the dispute rules compare against their limit.
    value_minor: Mapped[int] = mapped_column(BigInteger, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    __table_args__ = (UniqueConstraint("offer_id", name="uq_agreement_offer"),)


class Reservation(Base, UUIDPrimaryKey):
    """A listing held for one deal until it completes, expires or is undone."""

    __tablename__ = "reservations"

    listing_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("listings.id", ondelete="CASCADE"), nullable=False
    )
    offer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("offers.id", ondelete="CASCADE"), nullable=False
    )
    active: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="true")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    #: When the hold lapses if nobody confirms. Null while a dispute pauses it.
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    released_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    #: completed | expired | cancelled | resolved
    release_reason: Mapped[str | None] = mapped_column(String(20))

    __table_args__ = (
        # The guarantee itself: at most one active hold per listing. Two
        # accepts racing for the same listing cannot both insert.
        Index(
            "uq_reservation_active_listing",
            "listing_id",
            unique=True,
            postgresql_where=text("active"),
        ),
        Index("ix_reservations_offer", "offer_id"),
    )


class TradeConfirmation(Base):
    """One side's "handed over / received". Both are needed to complete."""

    __tablename__ = "trade_confirmations"

    offer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("offers.id", ondelete="CASCADE"),
        primary_key=True,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    confirmed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )


class DisputeReason(str, enum.Enum):
    no_show = "no_show"                  # the other side never came
    not_received = "not_received"        # I gave mine, got nothing back
    not_as_described = "not_as_described"
    other = "other"


class DisputeStatus(str, enum.Enum):
    escalated = "escalated"   # waiting for an operator
    resolved = "resolved"     # settled, by a rule or by an operator


class DisputeResolution(str, enum.Enum):
    cancel = "cancel"         # unwind: holds released, listings back on sale
    complete = "complete"     # the trade stands


class Dispute(Base, UUIDPrimaryKey):
    __tablename__ = "disputes"

    offer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("offers.id", ondelete="CASCADE"), nullable=False
    )
    opened_by: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    reason: Mapped[DisputeReason] = mapped_column(
        Enum(DisputeReason, name="dispute_reason"), nullable=False
    )
    note: Mapped[str | None] = mapped_column(Text)
    status: Mapped[DisputeStatus] = mapped_column(
        Enum(DisputeStatus, name="dispute_status"), nullable=False
    )
    resolution: Mapped[DisputeResolution | None] = mapped_column(
        Enum(DisputeResolution, name="dispute_resolution")
    )
    #: Null when a rule settled it; the operator otherwise.
    resolved_by: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL")
    )
    #: Which rule (or "operator") decided, and the rules version at the time —
    #: so a past decision can be explained after the rules change.
    decided_by_rule: Mapped[str | None] = mapped_column(String(60))
    rules_version: Mapped[int | None] = mapped_column(Integer)
    resolution_note: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    __table_args__ = (
        UniqueConstraint("offer_id", name="uq_dispute_offer"),
        Index("ix_disputes_status", "status", "created_at"),
    )
