from __future__ import annotations

import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.locale import resolve_locale
from app.core.security import current_user
from app.db.session import get_db
from app.models.listing import Listing
from app.models.offer import Offer, OfferStatus
from app.models.social import (
    Match,
    Notification,
    PaymentMethod,
    VerificationState,
    VerificationStep,
)
from app.models.user import User
from app.schemas.common import Money
from app.schemas.trade import (
    MarkRead,
    MatchOut,
    NotificationOut,
    PaymentMethodOut,
    SettlementOut,
    VerificationOut,
    VerificationStepOut,
)
from app.services import stats
from app.services.matching import explain, haversine_km, rebuild_matches
from app.services.presenter import listing_card, trader_brief

router = APIRouter(tags=["account"])


# ---------------------------------------------------------------- notifications


@router.get("/notifications", response_model=list[NotificationOut])
async def list_notifications(
    me: User = Depends(current_user), db: AsyncSession = Depends(get_db)
) -> list[NotificationOut]:
    rows = (
        await db.scalars(
            select(Notification)
            .where(Notification.user_id == me.id)
            .order_by(Notification.created_at.desc())
            .limit(60)
        )
    ).all()
    return [
        NotificationOut(
            id=n.id,
            kind=n.kind,
            title=n.title,
            body=n.body,
            avatar_url=n.avatar_url,
            created_at=n.created_at,
            is_unread=n.read_at is None,
            target_type=n.target_type,
            target_id=n.target_id,
        )
        for n in rows
    ]


@router.post("/notifications/read", status_code=status.HTTP_204_NO_CONTENT)
async def mark_read(
    payload: MarkRead,
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    """An empty `ids` list means every unread notification."""
    query = update(Notification).where(
        Notification.user_id == me.id, Notification.read_at.is_(None)
    )
    if payload.ids:
        query = query.where(Notification.id.in_(payload.ids))
    await db.execute(query.values(read_at=datetime.now(UTC)))
    await db.commit()


# ---------------------------------------------------------------------- matches


@router.get("/matches", response_model=list[MatchOut])
async def list_matches(
    locale: str = Depends(resolve_locale),
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> list[MatchOut]:
    await rebuild_matches(db, me.id)

    rows = (
        await db.scalars(
            select(Match)
            .where(Match.user_id == me.id, Match.dismissed_at.is_(None))
            .order_by(Match.score.desc())
            .limit(20)
        )
    ).all()
    if not rows:
        return []

    listing_ids = {r.my_listing_id for r in rows} | {r.their_listing_id for r in rows}
    listings = {
        listing.id: listing
        for listing in (
            await db.scalars(
                select(Listing)
                .options(
                    selectinload(Listing.translations), selectinload(Listing.photos)
                )
                .where(Listing.id.in_(listing_ids))
            )
        )
        .unique()
        .all()
    }

    owner_ids = list({listing.owner_id for listing in listings.values()})
    users = {
        u.id: u
        for u in (await db.scalars(select(User).where(User.id.in_(owner_ids)))).all()
    }
    ratings = await stats.rating_and_reviews(db, owner_ids)
    deals = await stats.completed_deals(db, owner_ids)

    def brief(user_id: uuid.UUID):
        return trader_brief(
            users[user_id],
            rating=ratings.get(user_id, (None, 0))[0],
            deals=deals.get(user_id, 0),
        )

    out: list[MatchOut] = []
    for row in rows:
        mine = listings.get(row.my_listing_id)
        theirs = listings.get(row.their_listing_id)
        if mine is None or theirs is None:
            continue
        owner = brief(theirs.owner_id)
        out.append(
            MatchOut(
                id=row.id,
                score=row.score,
                reason=explain(row.score, None),
                mine=listing_card(mine, locale, brief(mine.owner_id)),
                theirs=listing_card(theirs, locale, owner),
                owner=owner,
            )
        )
    return out


@router.post("/matches/{match_id}/dismiss", status_code=status.HTTP_204_NO_CONTENT)
async def dismiss_match(
    match_id: uuid.UUID,
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    match = await db.get(Match, match_id)
    if match is None or match.user_id != me.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Moslik topilmadi.")
    match.dismissed_at = datetime.now(UTC)
    await db.commit()


# ----------------------------------------------------------------- verification


@router.get("/me/verification", response_model=VerificationOut)
async def read_verification(
    me: User = Depends(current_user), db: AsyncSession = Depends(get_db)
) -> VerificationOut:
    steps = (
        await db.scalars(
            select(VerificationStep)
            .where(VerificationStep.user_id == me.id)
            .order_by(VerificationStep.weight.desc())
        )
    ).all()
    return VerificationOut(
        trust_score=me.trust_score,
        steps=[
            VerificationStepOut(
                step=s.step, state=s.state, hint=s.hint, weight=s.weight
            )
            for s in steps
        ],
    )


@router.post("/me/verification/{step}", response_model=VerificationOut)
async def submit_step(
    step: str,
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> VerificationOut:
    """
    Submitting a step puts it in review. The trust score is then recomputed from
    the steps themselves, so the number on the profile always adds up.
    """
    row = await db.scalar(
        select(VerificationStep).where(
            VerificationStep.user_id == me.id, VerificationStep.step == step
        )
    )
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Bunday bosqich yo‘q.")
    if row.state == VerificationState.done:
        raise HTTPException(
            status.HTTP_409_CONFLICT, "Bu bosqich allaqachon tasdiqlangan."
        )

    row.state = VerificationState.pending
    await db.flush()

    steps = (
        await db.scalars(
            select(VerificationStep).where(VerificationStep.user_id == me.id)
        )
    ).all()
    me.trust_score = sum(s.weight for s in steps if s.state == VerificationState.done)
    me.is_verified = me.trust_score >= 60
    await db.commit()

    return await read_verification(me=me, db=db)


# --------------------------------------------------------------------- payments


@router.get("/me/payment-methods", response_model=list[PaymentMethodOut])
async def list_cards(
    me: User = Depends(current_user), db: AsyncSession = Depends(get_db)
) -> list[PaymentMethodOut]:
    rows = (
        await db.scalars(
            select(PaymentMethod)
            .where(PaymentMethod.user_id == me.id)
            .order_by(PaymentMethod.is_primary.desc(), PaymentMethod.created_at)
        )
    ).all()
    return [PaymentMethodOut.model_validate(r) for r in rows]


@router.post("/me/payment-methods/{card_id}/primary", response_model=list[PaymentMethodOut])
async def make_primary(
    card_id: uuid.UUID,
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> list[PaymentMethodOut]:
    card = await db.get(PaymentMethod, card_id)
    if card is None or card.user_id != me.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Karta topilmadi.")

    await db.execute(
        update(PaymentMethod)
        .where(PaymentMethod.user_id == me.id)
        .values(is_primary=False)
    )
    card.is_primary = True
    await db.commit()
    return await list_cards(me=me, db=db)


@router.delete("/me/payment-methods/{card_id}", response_model=list[PaymentMethodOut])
async def remove_card(
    card_id: uuid.UUID,
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> list[PaymentMethodOut]:
    card = await db.get(PaymentMethod, card_id)
    if card is None or card.user_id != me.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Karta topilmadi.")

    was_primary = card.is_primary
    await db.delete(card)
    await db.flush()

    if was_primary:
        # Never leave the account without a primary card while one remains.
        replacement = await db.scalar(
            select(PaymentMethod)
            .where(PaymentMethod.user_id == me.id)
            .order_by(PaymentMethod.created_at)
            .limit(1)
        )
        if replacement is not None:
            replacement.is_primary = True

    await db.commit()
    return await list_cards(me=me, db=db)


@router.get("/me/settlements", response_model=list[SettlementOut])
async def list_settlements(
    me: User = Depends(current_user), db: AsyncSession = Depends(get_db)
) -> list[SettlementOut]:
    """
    Cash that actually moved: only completed deals that carried a top-up. The
    sign follows which side the user was on, so it is never ambiguous.
    """
    rows = (
        (
            await db.scalars(
                select(Offer)
                .where(
                    (Offer.from_user_id == me.id) | (Offer.to_user_id == me.id),
                    Offer.status == OfferStatus.completed,
                    Offer.cash_delta_minor != 0,
                )
                .order_by(Offer.updated_at.desc())
            )
        )
        .unique()
        .all()
    )
    if not rows:
        return []

    peer_ids = list(
        {r.to_user_id if r.from_user_id == me.id else r.from_user_id for r in rows}
    )
    peers = {
        u.id: u
        for u in (await db.scalars(select(User).where(User.id.in_(peer_ids)))).all()
    }

    out: list[SettlementOut] = []
    for offer in rows:
        outgoing = offer.from_user_id == me.id
        peer_id = offer.to_user_id if outgoing else offer.from_user_id
        out.append(
            SettlementOut(
                offer_id=offer.id,
                amount=Money(
                    minor=abs(offer.cash_delta_minor), currency=offer.currency
                ),
                counterparty_name=peers[peer_id].full_name,
                settled_at=offer.updated_at,
                outgoing=outgoing,
            )
        )
    return out
