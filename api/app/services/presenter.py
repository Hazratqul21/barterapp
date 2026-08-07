from __future__ import annotations

from datetime import UTC, datetime, timedelta

from app.models.listing import Listing
from app.models.user import User
from app.schemas.common import Money
from app.schemas.listing import ListingCard, ListingDetail
from app.schemas.user import TraderBrief

ONLINE_WINDOW = timedelta(minutes=5)


def trader_brief(user: User, *, rating: float | None, deals: int) -> TraderBrief:
    """
    The single place a trader is turned into API output. Every endpoint goes
    through here, so a name or badge cannot be assembled two different ways.
    """
    online = (
        user.last_seen_at is not None
        and datetime.now(UTC) - user.last_seen_at < ONLINE_WINDOW
    )
    return TraderBrief(
        id=user.id,
        name=user.full_name,
        handle=user.handle,
        avatar_url=user.avatar_url,
        is_verified=user.is_verified,
        rating=rating,
        deals=deals,
        is_online=online,
        last_seen_at=user.last_seen_at,
    )


def _text(listing: Listing, locale: str):
    """
    Translations are guaranteed complete on write, so this always resolves. The
    fallback exists only for rows seeded before a locale was added.
    """
    by_locale = {t.locale: t for t in listing.translations}
    return by_locale.get(locale) or by_locale["uz"]


def listing_card(
    listing: Listing,
    locale: str,
    owner: TraderBrief,
    *,
    distance_km: float | None = None,
) -> ListingCard:
    text = _text(listing, locale)
    return ListingCard(
        id=listing.id,
        tag=listing.tag,
        title=text.title,
        image_url=listing.photos[0].url if listing.photos else None,
        image_alt=text.image_alt,
        wants_summary=text.wants_summary,
        value=Money(minor=listing.value_minor, currency=listing.currency),
        distance_km=distance_km,
        cash_ok=listing.cash_ok,
        is_premium=listing.is_premium,
        posted_at=listing.created_at,
        owner=owner,
    )


def listing_detail(
    listing: Listing,
    locale: str,
    owner: TraderBrief,
    *,
    distance_km: float | None = None,
) -> ListingDetail:
    text = _text(listing, locale)
    card = listing_card(listing, locale, owner, distance_km=distance_km)

    wants: list[str] = []
    for want in listing.wants:
        by_locale = {t.locale: t.label for t in want.translations}
        label = by_locale.get(locale) or by_locale.get("uz")
        if label:
            wants.append(label)

    return ListingDetail(
        **card.model_dump(),
        status=listing.status,
        description=text.description,
        category=text.category,
        condition=text.condition,
        quantity=text.quantity,
        gallery=[p.url for p in listing.photos],
        wants=wants,
    )
