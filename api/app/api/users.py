from __future__ import annotations

import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.locale import resolve_locale
from app.core.regions import coordinates_for, region_names
from app.core.security import current_user
from app.db.session import get_db
from app.models.listing import Listing, ListingStatus
from app.models.review import Review
from app.models.user import User
from app.schemas.common import ApiModel
from app.schemas.listing import ListingCard
from app.schemas.user import Me, MeUpdate, TraderProfile
from app.services import stats
from app.services.presenter import listing_card, trader_brief

router = APIRouter(tags=["users"])


class ReviewOut(ApiModel):
    id: uuid.UUID
    rating: int
    body: str
    created_at: datetime
    author_id: uuid.UUID
    author_name: str
    author_avatar_url: str | None = None


async def _profile(db: AsyncSession, user: User) -> TraderProfile:
    ratings = await stats.rating_and_reviews(db, [user.id])
    deals = await stats.completed_deals(db, [user.id])
    rating, review_count = ratings.get(user.id, (None, 0))

    brief = trader_brief(user, rating=rating, deals=deals.get(user.id, 0))
    location = " · ".join(p for p in (user.region, user.district) if p) or None

    return TraderProfile(
        **brief.model_dump(),
        cover_url=user.cover_url,
        bio=user.bio,
        location=location,
        joined_at=user.created_at,
        completion_rate=await stats.completion_rate(db, user.id),
        responds_within_minutes=user.responds_within_minutes,
        review_count=review_count,
    )


@router.get("/me", response_model=Me)
async def read_me(
    me: User = Depends(current_user), db: AsyncSession = Depends(get_db)
) -> Me:
    profile = await _profile(db, me)
    deals = await stats.completed_deals(db, [me.id])
    return Me(
        **profile.model_dump(),
        phone=me.phone,
        first_name=me.first_name,
        last_name=me.last_name,
        region=me.region,
        district=me.district,
        address=me.address,
        locale=me.locale,
        trust_score=me.trust_score,
        active_listings=await stats.active_listings(db, me.id),
        completed_trades=deals.get(me.id, 0),
    )


@router.get("/regions", response_model=list[str], tags=["meta"])
async def list_regions() -> list[str]:
    """
    The regions an account can be placed in.

    Served rather than hardcoded in the client so that adding one — or fixing a
    spelling — does not need an app release on three platforms.
    """
    return region_names()


@router.patch("/me", response_model=Me)
async def update_me(
    payload: MeUpdate,
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> Me:
    fields = payload.model_dump(exclude_unset=True)
    for field, value in fields.items():
        setattr(me, field, value)

    # Picking a region also places the account on the map. Distance carries 30%
    # of every match score, and without this nothing outside the seed ever had
    # coordinates — so that 30% scored identically for everyone, which is the
    # same as not having it. An explicit latitude wins when one is sent.
    if "region" in fields and "latitude" not in fields:
        point = coordinates_for(me.region)
        if point is not None:
            me.latitude, me.longitude = point

    me.last_seen_at = datetime.now(UTC)
    await db.commit()
    await db.refresh(me)
    return await read_me(me=me, db=db)


@router.get("/me/listings", response_model=list[ListingCard])
async def my_listings(
    locale: str = Depends(resolve_locale),
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> list[ListingCard]:
    rows = (
        await db.scalars(
            select(Listing)
            .options(selectinload(Listing.translations), selectinload(Listing.photos))
            .where(Listing.owner_id == me.id)
            .order_by(Listing.created_at.desc())
        )
    ).unique().all()

    ratings = await stats.rating_and_reviews(db, [me.id])
    deals = await stats.completed_deals(db, [me.id])
    brief = trader_brief(
        me, rating=ratings.get(me.id, (None, 0))[0], deals=deals.get(me.id, 0)
    )
    return [listing_card(row, locale, brief) for row in rows]


@router.get("/users/{user_id}", response_model=TraderProfile)
async def read_trader(
    user_id: uuid.UUID, db: AsyncSession = Depends(get_db)
) -> TraderProfile:
    user = await db.get(User, user_id)
    if user is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Savdogar topilmadi.")
    return await _profile(db, user)


@router.get("/users/{user_id}/listings", response_model=list[ListingCard])
async def trader_listings(
    user_id: uuid.UUID,
    locale: str = Depends(resolve_locale),
    db: AsyncSession = Depends(get_db),
) -> list[ListingCard]:
    user = await db.get(User, user_id)
    if user is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Savdogar topilmadi.")

    rows = (
        await db.scalars(
            select(Listing)
            .options(selectinload(Listing.translations), selectinload(Listing.photos))
            .where(Listing.owner_id == user_id, Listing.status == ListingStatus.active)
            .order_by(Listing.created_at.desc())
        )
    ).unique().all()

    ratings = await stats.rating_and_reviews(db, [user_id])
    deals = await stats.completed_deals(db, [user_id])
    brief = trader_brief(
        user, rating=ratings.get(user_id, (None, 0))[0], deals=deals.get(user_id, 0)
    )
    return [listing_card(row, locale, brief) for row in rows]


@router.get("/users/{user_id}/reviews", response_model=list[ReviewOut])
async def trader_reviews(
    user_id: uuid.UUID, db: AsyncSession = Depends(get_db)
) -> list[ReviewOut]:
    """
    Only what other people wrote *about* this trader. The schema already makes a
    self-review unwritable; this filter makes sure a stranger's review never
    lands on the wrong page either.
    """
    rows = await db.execute(
        select(Review, User)
        .join(User, User.id == Review.author_id)
        .where(Review.about_id == user_id)
        .order_by(Review.created_at.desc())
    )
    return [
        ReviewOut(
            id=review.id,
            rating=review.rating,
            body=review.body,
            created_at=review.created_at,
            author_id=author.id,
            author_name=author.full_name,
            author_avatar_url=author.avatar_url,
        )
        for review, author in rows
    ]
