from __future__ import annotations

import base64
import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.locale import resolve_locale
from app.core.security import current_user, optional_user
from app.db.session import get_db
from app.models.listing import (
    Listing,
    ListingPhoto,
    ListingStatus,
    ListingTag,
    ListingTranslation,
    ListingWant,
    ListingWantTranslation,
)
from app.models.user import User, UserType
from app.schemas.common import Page
from app.schemas.listing import ListingCard, ListingCreate, ListingDetail
from app.services import stats
from app.services.matching import haversine_km
from app.services.presenter import listing_card, listing_detail, trader_brief

router = APIRouter(prefix="/listings", tags=["listings"])

PAGE_SIZE = 20


def _encode_cursor(created_at: datetime, listing_id: uuid.UUID) -> str:
    raw = f"{created_at.isoformat()}|{listing_id}"
    return base64.urlsafe_b64encode(raw.encode()).decode()


def _decode_cursor(cursor: str) -> tuple[datetime, uuid.UUID]:
    try:
        raw = base64.urlsafe_b64decode(cursor.encode()).decode()
        stamp, listing_id = raw.split("|")
        return datetime.fromisoformat(stamp), uuid.UUID(listing_id)
    except Exception:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Kursor yaroqsiz.")


async def _owners_for(
    db: AsyncSession, listings: list[Listing]
) -> dict[uuid.UUID, object]:
    """One round trip for every owner on the page, instead of one per card."""
    owner_ids = list({listing.owner_id for listing in listings})
    if not owner_ids:
        return {}

    users = (await db.scalars(select(User).where(User.id.in_(owner_ids)))).all()
    ratings = await stats.rating_and_reviews(db, owner_ids)
    deals = await stats.completed_deals(db, owner_ids)

    return {
        user.id: trader_brief(
            user,
            rating=ratings.get(user.id, (None, 0))[0],
            deals=deals.get(user.id, 0),
        )
        for user in users
    }


@router.get("", response_model=Page[ListingCard])
async def list_listings(
    tag: ListingTag | None = None,
    q: str | None = Query(default=None, max_length=120),
    cursor: str | None = None,
    limit: int = Query(default=PAGE_SIZE, ge=1, le=50),
    locale: str = Depends(resolve_locale),
    viewer: User | None = Depends(optional_user),
    db: AsyncSession = Depends(get_db),
) -> Page[ListingCard]:
    """
    The discovery feed. Your own listings are excluded — they live on your
    profile, and seeing them here was one of the prototype's identity bugs.
    """
    query = (
        select(Listing)
        .options(
            selectinload(Listing.translations),
            selectinload(Listing.photos),
        )
        .where(Listing.status == ListingStatus.active)
    )

    if viewer is not None:
        query = query.where(Listing.owner_id != viewer.id)
    if tag is not None:
        query = query.where(Listing.tag == tag)

    if q:
        needle = f"%{q.lower()}%"
        query = query.join(ListingTranslation).where(
            ListingTranslation.locale == locale,
            or_(
                ListingTranslation.title.ilike(needle),
                ListingTranslation.description.ilike(needle),
                ListingTranslation.wants_summary.ilike(needle),
                ListingTranslation.category.ilike(needle),
            ),
        )

    if cursor:
        created_at, last_id = _decode_cursor(cursor)
        query = query.where(
            or_(
                Listing.created_at < created_at,
                (Listing.created_at == created_at) & (Listing.id < last_id),
            )
        )

    query = query.order_by(Listing.created_at.desc(), Listing.id.desc()).limit(limit + 1)

    rows = list((await db.scalars(query)).unique().all())
    has_more = len(rows) > limit
    rows = rows[:limit]

    owners = await _owners_for(db, rows)
    items = [
        listing_card(
            row,
            locale,
            owners[row.owner_id],
            distance_km=haversine_km(
                viewer.latitude if viewer else None,
                viewer.longitude if viewer else None,
                row.latitude,
                row.longitude,
            ),
        )
        for row in rows
    ]

    next_cursor = (
        _encode_cursor(rows[-1].created_at, rows[-1].id) if has_more and rows else None
    )
    return Page[ListingCard](items=items, next_cursor=next_cursor)


@router.get("/{listing_id}", response_model=ListingDetail)
async def get_listing(
    listing_id: uuid.UUID,
    locale: str = Depends(resolve_locale),
    viewer: User | None = Depends(optional_user),
    db: AsyncSession = Depends(get_db),
) -> ListingDetail:
    listing = await db.scalar(
        select(Listing)
        .options(
            selectinload(Listing.translations),
            selectinload(Listing.photos),
            selectinload(Listing.wants).selectinload(ListingWant.translations),
        )
        .where(Listing.id == listing_id)
    )
    if listing is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "E’lon topilmadi.")

    owner = await db.get(User, listing.owner_id)
    ratings = await stats.rating_and_reviews(db, [listing.owner_id])
    deals = await stats.completed_deals(db, [listing.owner_id])

    brief = trader_brief(
        owner,
        rating=ratings.get(listing.owner_id, (None, 0))[0],
        deals=deals.get(listing.owner_id, 0),
    )
    return listing_detail(
        listing,
        locale,
        brief,
        distance_km=haversine_km(
            viewer.latitude if viewer else None,
            viewer.longitude if viewer else None,
            listing.latitude,
            listing.longitude,
        ),
    )


@router.post("", response_model=ListingDetail, status_code=status.HTTP_201_CREATED)
async def create_listing(
    payload: ListingCreate,
    locale: str = Depends(resolve_locale),
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> ListingDetail:
    """
    Publishing requires all three languages. `TranslatedText` makes that a
    validation error rather than a half-translated listing in the feed.

    Free listings are metered: everyone gets a small monthly quota, after which
    the plan charges per listing or by subscription. Businesses are exempt while
    subscription billing is still to be built — better to let a paying segment
    work than to block it behind an unfinished payment flow.
    """
    if me.user_type != UserType.business and me.free_listings_left <= 0:
        raise HTTPException(
            status.HTTP_402_PAYMENT_REQUIRED,
            "Bepul e’lonlar tugadi. Davom etish uchun tarif tanlang.",
        )

    listing = Listing(
        owner_id=me.id,
        tag=payload.tag,
        status=ListingStatus.active,
        value_minor=payload.value.minor,
        currency=payload.value.currency,
        cash_ok=payload.cash_ok,
        latitude=payload.latitude if payload.latitude is not None else me.latitude,
        longitude=payload.longitude if payload.longitude is not None else me.longitude,
    )
    db.add(listing)
    await db.flush()

    for code in ("uz", "ru", "en"):
        db.add(
            ListingTranslation(
                listing_id=listing.id,
                locale=code,
                title=getattr(payload.title, code),
                description=getattr(payload.description, code),
                image_alt=getattr(payload.image_alt, code),
                category=getattr(payload.category, code),
                condition=getattr(payload.condition, code),
                quantity=getattr(payload.quantity, code),
                wants_summary=getattr(payload.wants_summary, code),
            )
        )

    for position, url in enumerate(payload.photos):
        db.add(ListingPhoto(listing_id=listing.id, url=url, position=position))

    for position, want in enumerate(payload.wants):
        row = ListingWant(listing_id=listing.id, position=position)
        db.add(row)
        await db.flush()
        for code in ("uz", "ru", "en"):
            db.add(
                ListingWantTranslation(
                    want_id=row.id, locale=code, label=getattr(want, code)
                )
            )

    if me.user_type != UserType.business:
        me.free_listings_left -= 1
    me.last_seen_at = datetime.now(UTC)
    await db.commit()

    return await get_listing(listing.id, locale=locale, viewer=me, db=db)
