from __future__ import annotations

import uuid

from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    Enum,
    ForeignKey,
    Index,
    Integer,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, UUIDPrimaryKey
from app.models.listing import Listing, ListingTag


class Desire(Base, UUIDPrimaryKey):
    """
    What a listing's owner will accept, in a form the matcher can actually
    compare — a category plus a value band, not a sentence.

    The human-readable wording still lives in `listing_wants` for display; this
    table is what the scoring algorithm reads. Keeping them apart means the
    label can be phrased freely in three languages without the matcher having to
    parse prose, which is what made the first version score on word overlap.
    """

    __tablename__ = "desires"

    listing_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("listings.id", ondelete="CASCADE"), nullable=False
    )

    #: Null means "anything" — the open offer the spec expects most people to use.
    category: Mapped[ListingTag | None] = mapped_column(
        Enum(ListingTag, name="listing_tag", create_type=False)
    )

    min_value_minor: Mapped[int | None] = mapped_column(BigInteger)
    max_value_minor: Mapped[int | None] = mapped_column(BigInteger)

    #: The owner is willing to top up in cash to close a value gap.
    will_add_cash: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default="false"
    )
    #: The owner expects the other side to top up.
    wants_cash: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default="false"
    )

    position: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")

    listing: Mapped[Listing] = relationship()

    __table_args__ = (
        CheckConstraint(
            "min_value_minor IS NULL OR max_value_minor IS NULL "
            "OR min_value_minor <= max_value_minor",
            name="value_band_ordered",
        ),
        Index("ix_desires_lookup", "category", "min_value_minor", "max_value_minor"),
    )

    #: How far past the stated band a cash top-up is assumed to stretch. Two
    #: sides of one trade rarely have equal worth, and the spec expects most
    #: deals to close with money making up the difference.
    CASH_STRETCH = 2.0

    def accepts_value(self, value_minor: int) -> bool:
        """
        Is a listing of this worth something the owner would take?

        The cash flags widen the band rather than sitting unused: someone who
        said "I will add cash" can reach for something dearer, and someone who
        wants cash back can accept something cheaper. Without this, the flagship
        case — 40 tons of rice plus money for a tractor — never matches, because
        the tractor is worth 2.4× the rice on its own.
        """
        low = self.min_value_minor
        high = self.max_value_minor

        if self.will_add_cash and high is not None:
            high = int(high * self.CASH_STRETCH)
        if self.wants_cash and low is not None:
            low = int(low / self.CASH_STRETCH)

        if low is not None and value_minor < low:
            return False
        if high is not None and value_minor > high:
            return False
        return True
