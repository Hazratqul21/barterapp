from __future__ import annotations

import uuid

from sqlalchemy import ForeignKey, Index, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, Timestamps, UUIDPrimaryKey


class Favorite(Base, UUIDPrimaryKey, Timestamps):
    """
    A listing somebody put aside to come back to.

    In a barter marketplace this is not a wishlist — it is a shortlist of
    things worth offering against, which the person builds over several
    sittings before they commit to a trade.
    """

    __tablename__ = "favorites"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    listing_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("listings.id", ondelete="CASCADE"),
        nullable=False,
    )

    __table_args__ = (
        UniqueConstraint("user_id", "listing_id", name="uq_favorite_pair"),
        # Ro'yxat so'rovi: shu odamning saqlaganlari, oxirgisi birinchi.
        Index("ix_favorites_user", "user_id", "created_at"),
        # Teskari yo'nalish: e'lon nechta odamda saqlangani.
        Index("ix_favorites_listing", "listing_id"),
    )
