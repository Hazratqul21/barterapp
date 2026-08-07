from __future__ import annotations

import uuid
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.listing import Listing
from app.models.offer import Conversation, Offer, OfferItem, OfferStatus
from app.models.social import Notification, NotifyKind, NotifyTargetType
from app.models.user import User
from app.schemas.trade import OfferOut
from app.services import stats
from app.services.presenter import listing_card, trader_brief

# Which transitions are legal, and who is allowed to make them. Keeping this in
# one table is why a screen can never talk the backend into an impossible state.
TRANSITIONS: dict[str, tuple[set[OfferStatus], OfferStatus, str]] = {
    # action: (allowed from, resulting status, who — "recipient" | "either")
    "accept": ({OfferStatus.pending, OfferStatus.talking}, OfferStatus.accepted, "recipient"),
    "decline": ({OfferStatus.pending, OfferStatus.talking}, OfferStatus.declined, "recipient"),
    "counter": ({OfferStatus.pending, OfferStatus.talking}, OfferStatus.talking, "either"),
    "complete": ({OfferStatus.accepted}, OfferStatus.completed, "either"),
    "dispute": ({OfferStatus.accepted}, OfferStatus.disputed, "either"),
}


class OfferError(Exception):
    """A rejected transition, phrased for the person who tried it."""


async def load_offer(db: AsyncSession, offer_id: uuid.UUID) -> Offer | None:
    return await db.scalar(
        select(Offer).options(selectinload(Offer.items)).where(Offer.id == offer_id)
    )


def check_transition(offer: Offer, action: str, actor_id: uuid.UUID) -> OfferStatus:
    if action not in TRANSITIONS:
        raise OfferError("Bunday amal yo‘q.")

    allowed_from, result, who = TRANSITIONS[action]

    if offer.status not in allowed_from:
        raise OfferError(
            f"Bu savdo hozir “{offer.status.value}” holatida — bu amalni bajarib bo‘lmaydi."
        )
    if who == "recipient" and offer.to_user_id != actor_id:
        raise OfferError("Faqat taklif kelgan tomon bu amalni bajara oladi.")
    if actor_id not in (offer.from_user_id, offer.to_user_id):
        raise OfferError("Bu savdo sizga tegishli emas.")

    return result


def apply_counter(offer: Offer, actor_id: uuid.UUID, cash_delta_minor: int | None) -> None:
    """
    A counter flips the direction of the offer: whoever answered now becomes the
    sender, so the next accept belongs to the other side.
    """
    offer.from_user_id, offer.to_user_id = offer.to_user_id, offer.from_user_id
    if cash_delta_minor is not None:
        offer.cash_delta_minor = cash_delta_minor


async def notify(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    kind: NotifyKind,
    title: str,
    body: str,
    target_type: NotifyTargetType,
    target_id: uuid.UUID | None,
    avatar_url: str | None = None,
) -> None:
    db.add(
        Notification(
            user_id=user_id,
            kind=kind,
            title=title,
            body=body,
            target_type=target_type,
            target_id=target_id,
            avatar_url=avatar_url,
            created_at=datetime.now(UTC),
        )
    )


async def present(
    db: AsyncSession, offer: Offer, viewer_id: uuid.UUID, locale: str
) -> OfferOut:
    """Turn an offer into the shape both the inbox and the chat header render."""
    wanted = await db.scalar(
        select(Listing)
        .options(selectinload(Listing.translations), selectinload(Listing.photos))
        .where(Listing.id == offer.listing_id)
    )
    # Queried rather than read off `offer.items`: this runs for freshly flushed
    # offers too, where the relationship is not loaded yet.
    offered_ids = list(
        (
            await db.scalars(
                select(OfferItem.listing_id).where(OfferItem.offer_id == offer.id)
            )
        ).all()
    )
    offered_rows = (
        (
            await db.scalars(
                select(Listing)
                .options(
                    selectinload(Listing.translations), selectinload(Listing.photos)
                )
                .where(Listing.id.in_(offered_ids))
            )
        )
        .unique()
        .all()
        if offered_ids
        else []
    )

    peer_id = (
        offer.to_user_id if offer.from_user_id == viewer_id else offer.from_user_id
    )
    owner_ids = list({wanted.owner_id, peer_id, *[r.owner_id for r in offered_rows]})
    users = {
        u.id: u for u in (await db.scalars(select(User).where(User.id.in_(owner_ids)))).all()
    }
    ratings = await stats.rating_and_reviews(db, owner_ids)
    deals = await stats.completed_deals(db, owner_ids)

    def brief(user_id: uuid.UUID):
        return trader_brief(
            users[user_id],
            rating=ratings.get(user_id, (None, 0))[0],
            deals=deals.get(user_id, 0),
        )

    conversation_id = await db.scalar(
        select(Conversation.id).where(Conversation.offer_id == offer.id)
    )

    return OfferOut(
        id=offer.id,
        status=offer.status,
        cash_delta_minor=offer.cash_delta_minor,
        currency=offer.currency,
        created_at=offer.created_at,
        expires_at=offer.expires_at,
        is_mine=offer.from_user_id == viewer_id,
        counterparty=brief(peer_id),
        wanted=listing_card(wanted, locale, brief(wanted.owner_id)),
        offered=[listing_card(r, locale, brief(r.owner_id)) for r in offered_rows],
        conversation_id=conversation_id,
    )


def deal_summary(offer: OfferOut) -> str:
    """
    The one line that says what is on the table. Shown on inbox rows and pinned
    above the chat, so the thread stays anchored to the trade.
    """
    left = " + ".join(item.title for item in offer.offered) or "—"
    if offer.cash_delta_minor > 0:
        left = f"{left} + {offer.cash_delta_minor // 100} {offer.currency}"
    return f"{left} ↔ {offer.wanted.title}"


def link_items(db: AsyncSession, offer: Offer, listing_ids: list[uuid.UUID]) -> None:
    for listing_id in listing_ids:
        db.add(OfferItem(offer_id=offer.id, listing_id=listing_id))
