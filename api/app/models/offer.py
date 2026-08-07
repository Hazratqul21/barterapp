from __future__ import annotations

import enum
import uuid
from datetime import datetime

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, Timestamps, UUIDPrimaryKey


class OfferStatus(str, enum.Enum):
    draft = "draft"
    pending = "pending"
    talking = "talking"
    accepted = "accepted"
    declined = "declined"
    expired = "expired"
    completed = "completed"
    disputed = "disputed"
    refunded = "refunded"


class Offer(Base, UUIDPrimaryKey, Timestamps):
    """
    The central object: chat, escrow, notifications and reviews all hang off an
    offer's status rather than tracking their own copy of "what is happening".
    """

    __tablename__ = "offers"

    # What the sender wants.
    listing_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("listings.id", ondelete="CASCADE"), nullable=False
    )
    from_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    to_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )

    status: Mapped[OfferStatus] = mapped_column(
        Enum(OfferStatus, name="offer_status"), nullable=False, server_default="pending"
    )
    # Positive: the sender tops up. Negative: the sender asks for money back.
    cash_delta_minor: Mapped[int] = mapped_column(
        BigInteger, nullable=False, server_default="0"
    )
    currency: Mapped[str] = mapped_column(String(3), nullable=False, server_default="UZS")
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    items: Mapped[list[OfferItem]] = relationship(
        back_populates="offer", cascade="all, delete-orphan", lazy="selectin"
    )

    __table_args__ = (
        CheckConstraint("from_user_id <> to_user_id", name="no_self_offer"),
        Index("ix_offers_inbox", "to_user_id", "status", "created_at"),
    )


class OfferItem(Base):
    """A listing the sender puts on their side of the trade."""

    __tablename__ = "offer_items"

    offer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("offers.id", ondelete="CASCADE"), primary_key=True
    )
    listing_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("listings.id", ondelete="CASCADE"),
        primary_key=True,
    )

    offer: Mapped[Offer] = relationship(back_populates="items")


class Conversation(Base, UUIDPrimaryKey, Timestamps):
    """
    One thread per offer. Participants are ordered so the pair is unique whichever
    way round it is created.
    """

    __tablename__ = "conversations"

    offer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("offers.id", ondelete="CASCADE"), nullable=False
    )
    user_a_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    user_b_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    last_message_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    messages: Mapped[list[Message]] = relationship(
        back_populates="conversation", cascade="all, delete-orphan"
    )

    __table_args__ = (
        UniqueConstraint("offer_id", name="uq_conversation_offer"),
        CheckConstraint("user_a_id <> user_b_id", name="distinct_participants"),
    )


class Message(Base, UUIDPrimaryKey):
    __tablename__ = "messages"

    conversation_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("conversations.id", ondelete="CASCADE"),
        nullable=False,
    )
    sender_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    body: Mapped[str] = mapped_column(Text, nullable=False)
    photo_url: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    conversation: Mapped[Conversation] = relationship(back_populates="messages")

    __table_args__ = (
        Index("ix_messages_thread", "conversation_id", "created_at"),
    )
