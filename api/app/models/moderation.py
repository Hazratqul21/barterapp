from __future__ import annotations

import enum
import uuid

from sqlalchemy import (
    CheckConstraint,
    Enum,
    ForeignKey,
    Index,
    String,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, Timestamps, UUIDPrimaryKey


class Block(Base, UUIDPrimaryKey, Timestamps):
    """
    One person refusing to deal with another.

    Deliberately one row per direction rather than a symmetric pair: only the
    person who pressed the button can lift it. The *effect* is symmetric — the
    feed, offers and chat all hide the pair from each other regardless of who
    blocked whom — because a one-way block leaves the blocked side able to keep
    opening the conversation, which is exactly what the button is for stopping.
    """

    __tablename__ = "blocks"

    blocker_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    blocked_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )

    __table_args__ = (
        UniqueConstraint("blocker_id", "blocked_id", name="uq_block_pair"),
        CheckConstraint("blocker_id <> blocked_id", name="no_self_block"),
        Index("ix_blocks_blocker", "blocker_id"),
        Index("ix_blocks_blocked", "blocked_id"),
    )


class ReportTargetType(str, enum.Enum):
    user = "user"
    listing = "listing"


class ReportReason(str, enum.Enum):
    spam = "spam"
    scam = "scam"
    offensive = "offensive"
    fake = "fake"
    illegal = "illegal"
    other = "other"


class ReportStatus(str, enum.Enum):
    open = "open"
    reviewed = "reviewed"
    actioned = "actioned"
    dismissed = "dismissed"


class Report(Base, UUIDPrimaryKey, Timestamps):
    """
    A complaint waiting for a human.

    No foreign key on `target_id`: it points at either a user or a listing
    depending on `target_type`. That also means a report survives the thing it
    is about being archived, which is the case a moderator most needs to read.
    """

    __tablename__ = "reports"

    reporter_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    target_type: Mapped[ReportTargetType] = mapped_column(
        Enum(ReportTargetType, name="report_target_type"), nullable=False
    )
    target_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)

    reason: Mapped[ReportReason] = mapped_column(
        Enum(ReportReason, name="report_reason"), nullable=False
    )
    note: Mapped[str | None] = mapped_column(String(1000))
    review_status: Mapped[ReportStatus] = mapped_column(
        Enum(ReportStatus, name="report_status"), nullable=False, server_default="open"
    )

    __table_args__ = (
        # One standing complaint per person per thing. Without this, tapping the
        # button twice — which is what people do when nothing visibly happens —
        # buries a moderator's queue under duplicates of the same grievance.
        UniqueConstraint(
            "reporter_id", "target_type", "target_id", name="uq_report_once"
        ),
        Index("ix_reports_queue", "review_status", "created_at"),
    )
