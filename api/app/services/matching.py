from __future__ import annotations

import math
import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.desire import Desire
from app.models.listing import Listing, ListingStatus
from app.models.social import Match
from app.models.user import User
from app.services import stats

STALE_AFTER = timedelta(minutes=5)

# The weights are a product decision, taken from the business spec. They live in
# one place so tuning the matcher is a one-line change with a visible diff.
W_VALUE = 40
W_LOCATION = 30
W_RATING = 20
W_CATEGORY = 10

# Beyond this, hauling the goods usually costs more than the trade is worth.
MAX_USEFUL_KM = 400.0


def haversine_km(
    lat1: float | None, lon1: float | None, lat2: float | None, lon2: float | None
) -> float | None:
    """Great-circle distance, or None when either side has no coordinates."""
    if None in (lat1, lon1, lat2, lon2):
        return None

    radius = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * radius * math.asin(math.sqrt(a))


def value_score(mine_minor: int, theirs_minor: int) -> float:
    """
    How close the two sides are in worth, 0–1.

    Nobody wants a 5,000,000 item matched against a 50,000 one, so this is the
    heaviest signal. A perfectly equal pair scores 1; a 10× gap scores 0.1.
    """
    if mine_minor <= 0 or theirs_minor <= 0:
        return 0.0
    return min(mine_minor, theirs_minor) / max(mine_minor, theirs_minor)


def location_score(distance_km: float | None) -> float:
    """
    Near is better, and unknown is treated as average rather than as a penalty —
    a trader who has not set their location should not be pushed to the bottom.
    """
    if distance_km is None:
        return 0.5
    if distance_km <= 25:
        return 1.0
    return max(0.0, 1.0 - (distance_km - 25) / MAX_USEFUL_KM)


def rating_score(rating: float | None, is_verified: bool) -> float:
    """A new trader with no reviews starts mid-scale, not at zero."""
    base = 0.5 if rating is None else min(1.0, rating / 5.0)
    return min(1.0, base + (0.1 if is_verified else 0.0))


def wanted(desires: list[Desire], theirs: Listing) -> Desire | None:
    """
    The desire their listing satisfies, or None if the owner never asked for
    anything like it.

    This is a **gate, not a score**. The spec weights category at 10%, which is
    right for ranking but not for admission: on its own it let a laptop match
    six tons of maize at 85%, because the values happened to be close and the
    sellers were nearby. A trade nobody asked for is not a weak match — it is
    not a match. So candidates must clear this first, and the weights then rank
    the ones that did.
    """
    best: Desire | None = None
    for desire in desires:
        if desire.category is not None and desire.category != theirs.tag:
            continue
        if not desire.accepts_value(theirs.value_minor):
            continue
        # A named category beats an open "any offer" desire.
        if best is None or (best.category is None and desire.category is not None):
            best = desire
    return best


def category_score(desire: Desire | None) -> float:
    """Full marks for a category the owner named, less for an open desire."""
    if desire is None:
        return 0.0
    return 1.0 if desire.category is not None else 0.6


def score_pair(
    mine: Listing,
    theirs: Listing,
    *,
    my_desires: list[Desire],
    distance_km: float | None,
    their_rating: float | None,
    their_verified: bool,
) -> int | None:
    """
    Match Score, 0–100, weighted as the business spec sets out:
    value 40, location 30, rating 20, category 10.

    Returns None when their listing is not something this owner asked for — see
    `wanted()` for why that is a gate rather than a low score.
    """
    match = wanted(my_desires, theirs)
    if match is None:
        return None

    total = (
        W_VALUE * value_score(mine.value_minor, theirs.value_minor)
        + W_LOCATION * location_score(distance_km)
        + W_RATING * rating_score(their_rating, their_verified)
        + W_CATEGORY * category_score(match)
    )
    return max(0, min(100, round(total)))


def explain(score: int, distance_km: float | None) -> str:
    """One sentence naming the strongest reason, so the card is not just a number."""
    if score >= 85:
        return "Ular aynan sizning toifangizni izlamoqda."
    if distance_km is not None and distance_km <= 25:
        return "Yaqin hududda — yetkazish arzon tushadi."
    if score >= 70:
        return "Qiymatlar yaqin — toza almashinuv chiqadi."
    return "Hududingizda mavsumiy talab yuqori."


async def rebuild_matches(
    db: AsyncSession, user_id: uuid.UUID, *, force: bool = False
) -> None:
    """
    Recompute this user's matches when the last pass is stale.

    The spec calls for a cron worker every 5 minutes; this runs the same
    computation on read so the feature works before that worker exists. Moving
    it to a background job later means calling this function from there instead
    — nothing else changes.

    `force` skips the staleness check. Publishing a listing uses it: the whole
    promise of the product is "we will find who wants this", and waiting out a
    cache window before the matches tab shows anything reads as a broken app to
    someone who just posted their first listing.
    """
    now = datetime.now(UTC)

    if not force:
        latest = await db.scalar(
            select(Match.computed_at)
            .where(Match.user_id == user_id)
            .order_by(Match.computed_at.desc())
            .limit(1)
        )
        if latest is not None and now - latest < STALE_AFTER:
            return

    mine = (
        (
            await db.scalars(
                select(Listing).where(
                    Listing.owner_id == user_id,
                    Listing.status == ListingStatus.active,
                )
            )
        )
        .unique()
        .all()
    )
    if not mine:
        return

    others = (
        (
            await db.scalars(
                select(Listing).where(
                    Listing.owner_id != user_id,
                    Listing.status == ListingStatus.active,
                )
            )
        )
        .unique()
        .all()
    )
    if not others:
        return

    # Structured desires, keyed by the listing they belong to.
    desires_by_listing: dict[uuid.UUID, list[Desire]] = {}
    for desire in (
        await db.scalars(
            select(Desire).where(Desire.listing_id.in_([m.id for m in mine]))
        )
    ).all():
        desires_by_listing.setdefault(desire.listing_id, []).append(desire)

    owner_ids = list({listing.owner_id for listing in others})
    owners = {
        u.id: u
        for u in (await db.scalars(select(User).where(User.id.in_(owner_ids)))).all()
    }
    ratings = await stats.rating_and_reviews(db, owner_ids)

    dismissed = {
        (row.my_listing_id, row.their_listing_id)
        for row in (
            await db.scalars(
                select(Match).where(
                    Match.user_id == user_id, Match.dismissed_at.is_not(None)
                )
            )
        ).all()
    }

    await db.execute(
        delete(Match).where(Match.user_id == user_id, Match.dismissed_at.is_(None))
    )

    scored: list[tuple[int, Listing, Listing]] = []
    for my_listing in mine:
        my_desires = desires_by_listing.get(my_listing.id, [])
        for their_listing in others:
            if (my_listing.id, their_listing.id) in dismissed:
                continue

            owner = owners.get(their_listing.owner_id)
            if owner is None:
                continue

            distance = haversine_km(
                my_listing.latitude,
                my_listing.longitude,
                their_listing.latitude,
                their_listing.longitude,
            )
            score = score_pair(
                my_listing,
                their_listing,
                my_desires=my_desires,
                distance_km=distance,
                their_rating=ratings.get(owner.id, (None, 0))[0],
                their_verified=owner.is_verified,
            )
            if score is not None and score >= 55:
                scored.append((score, my_listing, their_listing))

    scored.sort(key=lambda row: row[0], reverse=True)
    for score, my_listing, their_listing in scored[:20]:
        db.add(
            Match(
                user_id=user_id,
                my_listing_id=my_listing.id,
                their_listing_id=their_listing.id,
                score=score,
                computed_at=now,
            )
        )

    await db.commit()
