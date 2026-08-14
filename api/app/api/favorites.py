from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.locale import resolve_locale
from app.core.security import current_user
from app.db.session import get_db
from app.models.favorite import Favorite
from app.models.listing import Listing, ListingStatus
from app.models.user import User
from app.schemas.common import Page
from app.schemas.listing import ListingCard
from app.models.event import EventKind
from app.services import events, moderation, stats
from app.services.matching import haversine_km
from app.services.presenter import listing_card, trader_brief

router = APIRouter(tags=["favorites"])


async def favorite_ids(
    db: AsyncSession, user_id: uuid.UUID | None, listing_ids: list[uuid.UUID]
) -> set[uuid.UUID]:
    """
    Which of these listings the viewer already saved.

    One query for the whole page. The alternative — a flag resolved per card —
    is a query per row, and the feed would pay it on every scroll.
    """
    if user_id is None or not listing_ids:
        return set()

    rows = await db.scalars(
        select(Favorite.listing_id).where(
            Favorite.user_id == user_id, Favorite.listing_id.in_(listing_ids)
        )
    )
    return set(rows.all())


@router.post("/listings/{listing_id}/favorite", status_code=status.HTTP_204_NO_CONTENT)
async def add_favorite(
    listing_id: uuid.UUID,
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    """
    Put a listing aside. Idempotent — a double tap is not an error.

    Archived and completed listings are refused: saving something that is no
    longer on the table only builds a list that disappoints later.
    """
    listing = await db.get(Listing, listing_id)
    if listing is None or listing.status in (
        ListingStatus.archived,
        ListingStatus.completed,
    ):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "E'lon topilmadi.")

    if await moderation.is_blocked(db, me.id, listing.owner_id):
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "Bu savdogar bilan aloqa cheklangan."
        )

    existing = await db.scalar(
        select(Favorite).where(
            Favorite.user_id == me.id, Favorite.listing_id == listing_id
        )
    )
    if existing is None:
        db.add(Favorite(user_id=me.id, listing_id=listing_id))
        await events.record(
            db,
            EventKind.favorite_add,
            user_id=me.id,
            target_type="listing",
            target_id=listing_id,
            payload={"tag": listing.tag.value, "value_minor": listing.value_minor},
        )
        await db.commit()


@router.delete(
    "/listings/{listing_id}/favorite", status_code=status.HTTP_204_NO_CONTENT
)
async def remove_favorite(
    listing_id: uuid.UUID,
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Idempotent, and deliberately silent about listings that no longer exist."""
    existing = await db.scalar(
        select(Favorite).where(
            Favorite.user_id == me.id, Favorite.listing_id == listing_id
        )
    )
    if existing is not None:
        await db.delete(existing)
        # Saqlanganini olib tashlash ham ma'lumot: qiziqish so'ngani yoki
        # taklif yuborilgani. Faqat qo'shishni yozadigan tizim odamning
        # fikri o'zgarganini hech qachon ko'rmaydi.
        await events.record(
            db,
            EventKind.favorite_remove,
            user_id=me.id,
            target_type="listing",
            target_id=listing_id,
        )
        await db.commit()


@router.get("/favorites", response_model=Page[ListingCard])
async def list_favorites(
    limit: int = Query(default=20, ge=1, le=50),
    locale: str = Depends(resolve_locale),
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> Page[ListingCard]:
    """
    Everything saved, newest first.

    Listings that left the market — archived, completed, or belonging to
    somebody since blocked — are filtered out rather than shown as dead cards.
    The rows stay: a completed trade can be disputed and reopened, and losing
    the shortlist over that would be worse than briefly hiding one entry.
    """
    hidden = await moderation.blocked_ids(db, me.id)

    query = (
        select(Listing)
        .join(Favorite, Favorite.listing_id == Listing.id)
        .options(selectinload(Listing.translations), selectinload(Listing.photos))
        .where(
            Favorite.user_id == me.id,
            Listing.status == ListingStatus.active,
        )
        .order_by(Favorite.created_at.desc(), Listing.id.desc())
        .limit(limit)
    )
    if hidden:
        query = query.where(Listing.owner_id.notin_(hidden))

    rows = list((await db.scalars(query)).unique().all())
    if not rows:
        return Page[ListingCard](items=[], next_cursor=None)

    owner_ids = list({row.owner_id for row in rows})
    users = (await db.scalars(select(User).where(User.id.in_(owner_ids)))).all()
    ratings = await stats.rating_and_reviews(db, owner_ids)
    deals = await stats.completed_deals(db, owner_ids)
    briefs = {
        user.id: trader_brief(
            user,
            rating=ratings.get(user.id, (None, 0))[0],
            deals=deals.get(user.id, 0),
        )
        for user in users
    }

    return Page[ListingCard](
        items=[
            listing_card(
                row,
                locale,
                briefs[row.owner_id],
                distance_km=haversine_km(
                    me.latitude, me.longitude, row.latitude, row.longitude
                ),
                # Ta'rifi bo'yicha — bu ro'yxatning o'zi saqlanganlar.
                is_favorite=True,
            )
            for row in rows
        ],
        next_cursor=None,
    )
