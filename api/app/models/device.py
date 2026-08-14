from __future__ import annotations

import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, Index, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, Timestamps, UUIDPrimaryKey


class DevicePlatform(str, enum.Enum):
    ios = "ios"
    android = "android"
    web = "web"


class Device(Base, UUIDPrimaryKey, Timestamps):
    """
    One installation that can receive a push.

    Keyed on the push token, not on the user: the same phone can be handed to
    somebody else, and when they sign in the token must move to the new account
    rather than keep delivering the first person's messages. Registering an
    already-known token therefore reassigns it.
    """

    __tablename__ = "devices"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    token: Mapped[str] = mapped_column(String(500), nullable=False)
    platform: Mapped[DevicePlatform] = mapped_column(
        Enum(DevicePlatform, name="device_platform"), nullable=False
    )
    locale: Mapped[str] = mapped_column(String(2), nullable=False, server_default="uz")

    #: Last time the app confirmed this installation still exists. A device that
    #: stops checking in is eventually dropped rather than pushed to forever.
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    __table_args__ = (
        UniqueConstraint("token", name="uq_device_token"),
        Index("ix_devices_user", "user_id"),
    )
