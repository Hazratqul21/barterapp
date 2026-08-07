from __future__ import annotations

import uuid

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.listing import Listing, ListingStatus
from app.models.offer import Offer, OfferStatus
from app.models.review import Review


async def rating_and_reviews(
    db: AsyncSession, user_ids: list[uuid.UUID]
) -> dict[uuid.UUID, tuple[float | None, int]]:
    """
    Ratings are computed, never stored on the user row. The prototype hardcoded
    "4.8" in three places and they disagreed with the review list underneath.
    """
    if not user_ids:
        return {}

    rows = await db.execute(
        select(
            Review.about_id,
            func.round(func.avg(Review.rating), 1),
            func.count(Review.id),
        )
        .where(Review.about_id.in_(user_ids))
        .group_by(Review.about_id)
    )
    return {row[0]: (float(row[1]) if row[1] is not None else None, row[2]) for row in rows}


async def completed_deals(
    db: AsyncSession, user_ids: list[uuid.UUID]
) -> dict[uuid.UUID, int]:
    """A trade counts for both sides once it reaches `completed`."""
    if not user_ids:
        return {}

    counts: dict[uuid.UUID, int] = {uid: 0 for uid in user_ids}
    for column in (Offer.from_user_id, Offer.to_user_id):
        rows = await db.execute(
            select(column, func.count(Offer.id))
            .where(column.in_(user_ids), Offer.status == OfferStatus.completed)
            .group_by(column)
        )
        for user_id, total in rows:
            counts[user_id] = counts.get(user_id, 0) + total
    return counts


async def completion_rate(db: AsyncSession, user_id: uuid.UUID) -> int | None:
    """Share of accepted deals that actually reached hand-over."""
    accepted = await db.scalar(
        select(func.count(Offer.id)).where(
            (Offer.from_user_id == user_id) | (Offer.to_user_id == user_id),
            Offer.status.in_(
                [
                    OfferStatus.accepted,
                    OfferStatus.completed,
                    OfferStatus.disputed,
                    OfferStatus.refunded,
                ]
            ),
        )
    )
    if not accepted:
        return None

    done = await db.scalar(
        select(func.count(Offer.id)).where(
            (Offer.from_user_id == user_id) | (Offer.to_user_id == user_id),
            Offer.status == OfferStatus.completed,
        )
    )
    return round((done or 0) * 100 / accepted)


async def active_listings(db: AsyncSession, user_id: uuid.UUID) -> int:
    return (
        await db.scalar(
            select(func.count(Listing.id)).where(
                Listing.owner_id == user_id, Listing.status == ListingStatus.active
            )
        )
        or 0
    )
