from __future__ import annotations

import base64
import enum
import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.locale import resolve_locale
from app.core.security import current_user, optional_user
from app.db.session import get_db
from app.models.desire import Desire
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
from app.models.offer import Offer, OfferItem, OfferStatus
from app.schemas.listing import (
    DesireIn,
    ListingCard,
    ListingCreate,
    ListingDetail,
    ListingUpdate,
)
from app.services import moderation
from app.services import stats
from app.services.matching import haversine_km, rebuild_matches
from app.services.presenter import listing_card, listing_detail, trader_brief

router = APIRouter(prefix="/listings", tags=["listings"])

PAGE_SIZE = 20


class FeedSort(str, enum.Enum):
    """
    How the feed is ordered. The cursor carries whichever key is sorted on, so
    changing the order does not break paging.
    """

    new = "new"
    cheap = "cheap"
    expensive = "expensive"


def _encode_cursor(key: str, listing_id: uuid.UUID) -> str:
    raw = f"{key}|{listing_id}"
    return base64.urlsafe_b64encode(raw.encode()).decode()


def _decode_cursor(cursor: str) -> tuple[str, uuid.UUID]:
    try:
        raw = base64.urlsafe_b64decode(cursor.encode()).decode()
        key, listing_id = raw.rsplit("|", 1)
        return key, uuid.UUID(listing_id)
    except Exception:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Kursor yaroqsiz.")


def _sort_key(sort: FeedSort, listing: Listing) -> str:
    if sort is FeedSort.new:
        return listing.created_at.isoformat()
    return str(listing.value_minor)


def _paginate(query, sort: FeedSort, cursor: str | None):
    """
    Apply the ordering, and the seek condition when a page was already served.

    Every order is a pair — the sorted column then `id` — because `created_at`
    and `value_minor` both repeat. Without the tie-breaker two listings sharing
    a value can swap places between requests, which shows one of them twice and
    hides the other entirely.
    """
    if sort is FeedSort.new:
        column, descending = Listing.created_at, True
    elif sort is FeedSort.expensive:
        column, descending = Listing.value_minor, True
    else:
        column, descending = Listing.value_minor, False

    if cursor:
        key, last_id = _decode_cursor(cursor)
        try:
            edge = (
                datetime.fromisoformat(key) if sort is FeedSort.new else int(key)
            )
        except ValueError:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Kursor yaroqsiz.")

        if descending:
            query = query.where(
                or_(column < edge, (column == edge) & (Listing.id < last_id))
            )
        else:
            query = query.where(
                or_(column > edge, (column == edge) & (Listing.id > last_id))
            )

    if descending:
        return query.order_by(column.desc(), Listing.id.desc())
    return query.order_by(column.asc(), Listing.id.asc())


#: How far either side of its own worth a listing will look when the owner did
#: not say. Half to double covers the ordinary swap; `will_add_cash` stretches
#: the top of that band again inside `Desire.accepts_value`.
DEFAULT_BAND_LOW = 0.5
DEFAULT_BAND_HIGH = 2.0


def _desires_for(payload: ListingCreate) -> list[DesireIn]:
    """
    The structured wishes to store for this listing.

    A listing with no desire row is invisible to the matcher — `wanted()` is a
    gate, and an owner who asked for nothing matches nothing. That is the right
    rule for someone who genuinely wants one specific thing, and the wrong
    outcome for someone who just filled in the form and expects offers. So when
    the client sends none, one open desire is derived from what the listing is
    worth: any category, within reach of its own value.
    """
    if payload.desires:
        return payload.desires

    worth = payload.value.minor
    return [
        DesireIn(
            category=None,
            min_value_minor=int(worth * DEFAULT_BAND_LOW),
            max_value_minor=int(worth * DEFAULT_BAND_HIGH),
            will_add_cash=payload.cash_ok,
            wants_cash=False,
        )
    ]


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
    min_value: int | None = Query(default=None, ge=0),
    max_value: int | None = Query(default=None, ge=0),
    region: str | None = Query(default=None, max_length=80),
    cash_ok: bool | None = None,
    sort: FeedSort = FeedSort.new,
    cursor: str | None = None,
    limit: int = Query(default=PAGE_SIZE, ge=1, le=50),
    locale: str = Depends(resolve_locale),
    viewer: User | None = Depends(optional_user),
    db: AsyncSession = Depends(get_db),
) -> Page[ListingCard]:
    """
    The discovery feed. Your own listings are excluded — they live on your
    profile, and seeing them here was one of the prototype's identity bugs.

    `min_value`/`max_value` are in minor units, the same as `value.minor`
    everywhere else, so a client never has to know a currency's exponent.
    """
    if min_value is not None and max_value is not None and min_value > max_value:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "Eng kichik narx eng kattasidan katta bo'lishi mumkin emas.",
        )

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

        # Both directions: the person you blocked leaves your feed, and so do
        # you leave theirs. A one-way hide would let the blocked side keep
        # watching everything you post, which is what the button is for.
        hidden = await moderation.blocked_ids(db, viewer.id)
        if hidden:
            query = query.where(Listing.owner_id.notin_(hidden))

    if tag is not None:
        query = query.where(Listing.tag == tag)

    if min_value is not None:
        query = query.where(Listing.value_minor >= min_value)
    if max_value is not None:
        query = query.where(Listing.value_minor <= max_value)
    if cash_ok is not None:
        query = query.where(Listing.cash_ok == cash_ok)

    if region:
        # Listings carry coordinates but not a region name, so the filter runs
        # through the owner. A subquery rather than a join: joining users would
        # multiply nothing here, but it would also let a later `.distinct()`
        # requirement creep in, and this reads as what it is — "owned by
        # somebody in this region".
        query = query.where(
            Listing.owner_id.in_(select(User.id).where(User.region == region))
        )

    if q:
        # Searched across every language, not just the one being read. Each
        # listing is stored in all three, so scoping to the current locale meant
        # a Russian reader typing an Uzbek word — which is how half the country
        # writes a product name — got an empty feed while the listing sat right
        # there. Matching by subquery keeps one row per listing; a join would
        # return the same listing up to three times.
        #
        # `%` and `_` are wildcards to LIKE, so a search for "50%" or "_" was
        # read as a pattern and matched everything. Escaped here, with the
        # escape character declared on each clause.
        safe = q.strip().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
        needle = f"%{safe}%"
        query = query.where(
            Listing.id.in_(
                select(ListingTranslation.listing_id).where(
                    or_(
                        ListingTranslation.title.ilike(needle, escape="\\"),
                        ListingTranslation.description.ilike(needle, escape="\\"),
                        ListingTranslation.wants_summary.ilike(needle, escape="\\"),
                        ListingTranslation.category.ilike(needle, escape="\\"),
                    )
                )
            )
        )

    query = _paginate(query, sort, cursor).limit(limit + 1)

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
        _encode_cursor(_sort_key(sort, rows[-1]), rows[-1].id)
        if has_more and rows
        else None
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

    for position, desire in enumerate(_desires_for(payload)):
        db.add(
            Desire(
                listing_id=listing.id,
                category=desire.category,
                min_value_minor=desire.min_value_minor,
                max_value_minor=desire.max_value_minor,
                will_add_cash=desire.will_add_cash,
                wants_cash=desire.wants_cash,
                position=position,
            )
        )

    if me.user_type != UserType.business:
        me.free_listings_left -= 1
    me.last_seen_at = datetime.now(UTC)
    await db.commit()

    # Match straight away rather than on the next stale read. Someone who has
    # just published their first listing opens the matches tab expecting the
    # product's one promise to have happened; a five-minute cache window there
    # reads as an empty app, not as a cache.
    await rebuild_matches(db, me.id, force=True)

    return await get_listing(listing.id, locale=locale, viewer=me, db=db)


#: An offer that is still live. A listing tangled in one of these cannot be
#: edited out from under the person negotiating for it.
_LIVE_OFFERS = (OfferStatus.pending, OfferStatus.talking, OfferStatus.accepted)


async def _owned_listing(
    listing_id: uuid.UUID, me: User, db: AsyncSession
) -> Listing:
    """The listing, if it is yours and still exists.

    Answers 404 rather than 403 for somebody else's listing: whether a given id
    belongs to another user is not a fact this endpoint owes a stranger.
    """
    listing = await db.get(Listing, listing_id)
    if listing is None or listing.owner_id != me.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "E’lon topilmadi.")
    return listing


async def _live_offer_count(listing_id: uuid.UUID, db: AsyncSession) -> int:
    """How many open offers touch this listing, as the thing wanted or offered."""
    via_item = select(OfferItem.offer_id).where(OfferItem.listing_id == listing_id)
    rows = await db.scalars(
        select(Offer.id).where(
            Offer.status.in_(_LIVE_OFFERS),
            or_(Offer.listing_id == listing_id, Offer.id.in_(via_item)),
        )
    )
    return len(rows.all())


@router.patch("/{listing_id}", response_model=ListingDetail)
async def update_listing(
    listing_id: uuid.UUID,
    payload: ListingUpdate,
    locale: str = Depends(resolve_locale),
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> ListingDetail:
    """
    Change a listing you own.

    Until this existed a listing was write-once: a typo in the price, a photo
    taken in the dark, a tractor that is no longer 2019 — none of it could be
    corrected, and the only way out was to publish a second listing and leave
    the wrong one in the feed forever.

    Two things are refused rather than silently allowed. A listing already sold
    or archived is history and stays as it was, and a listing inside a live
    negotiation cannot be rewritten while the other side is looking at it —
    changing the price under an open offer is the marketplace equivalent of
    moving the goalposts mid-deal.
    """
    listing = await _owned_listing(listing_id, me, db)

    if listing.status in (ListingStatus.completed, ListingStatus.archived):
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "Yakunlangan yoki arxivlangan e’lonni tahrirlab bo‘lmaydi.",
        )
    if await _live_offer_count(listing.id, db):
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "Bu e’lon ochiq taklifda turibdi. Avval taklifni yakunlang yoki rad eting.",
        )

    if payload.tag is not None:
        listing.tag = payload.tag
    if payload.value is not None:
        listing.value_minor = payload.value.minor
        listing.currency = payload.value.currency
    if payload.cash_ok is not None:
        listing.cash_ok = payload.cash_ok
    if payload.latitude is not None:
        listing.latitude = payload.latitude
    if payload.longitude is not None:
        listing.longitude = payload.longitude

    # Translated fields are patched per language in place, so an edit that only
    # touches the title leaves the description rows untouched.
    translated = {
        "title": payload.title,
        "description": payload.description,
        "image_alt": payload.image_alt,
        "category": payload.category,
        "condition": payload.condition,
        "quantity": payload.quantity,
        "wants_summary": payload.wants_summary,
    }
    if any(v is not None for v in translated.values()):
        rows = (
            await db.scalars(
                select(ListingTranslation).where(
                    ListingTranslation.listing_id == listing.id
                )
            )
        ).all()
        for row in rows:
            for field, value in translated.items():
                if value is not None:
                    setattr(row, field, getattr(value, row.locale))

    if payload.photos is not None:
        for row in (
            await db.scalars(
                select(ListingPhoto).where(ListingPhoto.listing_id == listing.id)
            )
        ).all():
            await db.delete(row)
        await db.flush()
        for position, url in enumerate(payload.photos):
            db.add(ListingPhoto(listing_id=listing.id, url=url, position=position))

    if payload.wants is not None:
        for row in (
            await db.scalars(
                select(ListingWant).where(ListingWant.listing_id == listing.id)
            )
        ).all():
            await db.delete(row)
        await db.flush()
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

    if payload.desires is not None:
        for row in (
            await db.scalars(select(Desire).where(Desire.listing_id == listing.id))
        ).all():
            await db.delete(row)
        await db.flush()
        for position, desire in enumerate(payload.desires):
            db.add(
                Desire(
                    listing_id=listing.id,
                    category=desire.category,
                    min_value_minor=desire.min_value_minor,
                    max_value_minor=desire.max_value_minor,
                    will_add_cash=desire.will_add_cash,
                    wants_cash=desire.wants_cash,
                    position=position,
                )
            )

    await db.commit()

    # What this listing is willing to take may have changed, so the matches it
    # belongs to are recomputed rather than left pointing at the old wants.
    await rebuild_matches(db, me.id, force=True)

    return await get_listing(listing.id, locale=locale, viewer=me, db=db)


@router.delete("/{listing_id}", status_code=status.HTTP_204_NO_CONTENT)
async def archive_listing(
    listing_id: uuid.UUID,
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    """
    Take a listing off the marketplace.

    Archived, not deleted. Offers, conversations and reviews all point at this
    row, and a completed trade has to stay readable by both sides months later —
    a hard delete would either cascade that history away or leave the tables
    referring to something that is gone. Archiving takes the listing out of the
    feed, out of search and out of matching, which is what "delete" means to
    the person pressing it.

    A listing inside a live offer is refused for the same reason an edit is: the
    other side is mid-negotiation over it.
    """
    listing = await _owned_listing(listing_id, me, db)

    if listing.status == ListingStatus.archived:
        return
    if listing.status == ListingStatus.completed:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "Yakunlangan savdo tarixi — uni o‘chirib bo‘lmaydi.",
        )
    if await _live_offer_count(listing.id, db):
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "Bu e’lon ochiq taklifda turibdi. Avval taklifni yakunlang yoki rad eting.",
        )

    listing.status = ListingStatus.archived

    # The matches this listing appeared in are stale the moment it leaves the
    # feed, so they are rebuilt rather than left advertising something that can
    # no longer be traded for.
    await db.commit()
    await rebuild_matches(db, me.id, force=True)
