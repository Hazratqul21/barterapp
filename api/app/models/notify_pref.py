from __future__ import annotations

import uuid

from sqlalchemy import Boolean, CheckConstraint, ForeignKey, Integer, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, Timestamps, UUIDPrimaryKey


class NotificationSetting(Base, UUIDPrimaryKey, Timestamps):
    """
    What this account agrees to be woken up for.

    Only the *push* is governed here. The notification row is written either
    way and the in-app list still shows it — turning off "matches" means "stop
    buzzing my phone about these", not "hide them from me". Conflating the two
    is how people end up missing an offer they never asked to hide.

    Absent row means everything on. Defaults live in `DEFAULTS` below rather
    than as rows created at signup, so a new notification kind added later is
    on for existing accounts without a backfill.
    """

    __tablename__ = "notification_settings"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )

    offers: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="true")
    matches: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default="true"
    )
    messages: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default="true"
    )
    system: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="true")

    #: Local hours (Asia/Tashkent) between which the phone stays quiet. Both
    #: null means never quiet. Stored as plain hours, not timestamps, because
    #: "don't wake me before 8" is a rule about the clock, not about a date.
    #:
    #: Start may be greater than end — 22 to 7 crosses midnight, which is the
    #: normal case and the one a naive `between` check gets wrong.
    quiet_from: Mapped[int | None] = mapped_column(Integer)
    quiet_to: Mapped[int | None] = mapped_column(Integer)

    __table_args__ = (
        UniqueConstraint("user_id", name="uq_notification_setting_user"),
        CheckConstraint(
            "quiet_from IS NULL OR (quiet_from BETWEEN 0 AND 23)",
            name="quiet_from_hour",
        ),
        CheckConstraint(
            "quiet_to IS NULL OR (quiet_to BETWEEN 0 AND 23)", name="quiet_to_hour"
        ),
        # Yarmi to'ldirilgan oraliq ma'nosiz: "22 dan" deb yozib, "nechagacha"
        # ni aytmaslik — sozlama emas, xato.
        CheckConstraint(
            "(quiet_from IS NULL) = (quiet_to IS NULL)", name="quiet_pair"
        ),
    )
