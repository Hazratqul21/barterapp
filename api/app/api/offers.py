from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.locale import resolve_locale
from app.core.security import current_user
from app.db.session import get_db
from app.models.listing import Listing, ListingStatus
from app.models.offer import Conversation, Message, Offer, OfferItem, OfferStatus
from app.models.social import NotifyKind, NotifyTargetType
from app.models.user import User
from app.schemas.trade import OfferAction, OfferCreate, OfferOut
from app.services import offers as service

router = APIRouter(prefix="/offers", tags=["offers"])

OFFER_TTL = timedelta(hours=48)


@router.get("", response_model=list[OfferOut])
async def list_offers(
    locale: str = Depends(resolve_locale),
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> list[OfferOut]:
    rows = (
        (
            await db.scalars(
                select(Offer)
                .options(selectinload(Offer.items))
                .where(
                    (Offer.from_user_id == me.id) | (Offer.to_user_id == me.id)
                )
                .order_by(Offer.created_at.desc())
            )
        )
        .unique()
        .all()
    )
    return [await service.present(db, offer, me.id, locale) for offer in rows]


@router.post("", response_model=OfferOut, status_code=status.HTTP_201_CREATED)
async def create_offer(
    payload: OfferCreate,
    locale: str = Depends(resolve_locale),
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> OfferOut:
    wanted = await db.get(Listing, payload.listing_id)
    if wanted is None or wanted.status != ListingStatus.active:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "E’lon topilmadi yoki yopilgan.")
    if wanted.owner_id == me.id:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST, "O‘z e’loningizga taklif yubora olmaysiz."
        )

    # You can only put up listings you actually own.
    offered = (
        await db.scalars(
            select(Listing).where(
                Listing.id.in_(payload.offered_listing_ids),
                Listing.owner_id == me.id,
            )
        )
    ).all()
    if len(offered) != len(set(payload.offered_listing_ids)):
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "Taklif qilingan e’lonlarning ba’zisi sizga tegishli emas.",
        )

    now = datetime.now(UTC)
    offer = Offer(
        listing_id=wanted.id,
        from_user_id=me.id,
        to_user_id=wanted.owner_id,
        status=OfferStatus.pending,
        cash_delta_minor=payload.cash_delta_minor,
        currency=payload.currency,
        expires_at=now + OFFER_TTL,
    )
    db.add(offer)
    await db.flush()
    service.link_items(db, offer, list(payload.offered_listing_ids))

    # An offer always opens the thread it will be negotiated in.
    thread = Conversation(
        offer_id=offer.id,
        user_a_id=me.id,
        user_b_id=wanted.owner_id,
        last_message_at=now if payload.message else None,
    )
    db.add(thread)
    await db.flush()

    if payload.message:
        db.add(
            Message(
                conversation_id=thread.id,
                sender_id=me.id,
                body=payload.message,
                created_at=now,
            )
        )

    await db.flush()
    out = await service.present(db, offer, me.id, locale)

    await service.notify(
        db,
        user_id=wanted.owner_id,
        kind=NotifyKind.offer,
        title=f"{me.full_name} taklif yubordi",
        body=service.deal_summary(out),
        target_type=NotifyTargetType.chat,
        target_id=thread.id,
        avatar_url=me.avatar_url,
    )

    await db.commit()
    return out


@router.get("/{offer_id}", response_model=OfferOut)
async def read_offer(
    offer_id: uuid.UUID,
    locale: str = Depends(resolve_locale),
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> OfferOut:
    offer = await service.load_offer(db, offer_id)
    if offer is None or me.id not in (offer.from_user_id, offer.to_user_id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Taklif topilmadi.")
    return await service.present(db, offer, me.id, locale)


@router.patch("/{offer_id}", response_model=OfferOut)
async def act_on_offer(
    offer_id: uuid.UUID,
    payload: OfferAction,
    locale: str = Depends(resolve_locale),
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> OfferOut:
    """
    Accept, decline, counter, complete or dispute. The legal transitions live in
    `services/offers.TRANSITIONS`, so no screen can push the deal into a state
    the rest of the product does not understand.
    """
    offer = await service.load_offer(db, offer_id)
    if offer is None or me.id not in (offer.from_user_id, offer.to_user_id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Taklif topilmadi.")

    try:
        new_status = service.check_transition(offer, payload.action, me.id)
    except service.OfferError as e:
        raise HTTPException(status.HTTP_409_CONFLICT, str(e))

    peer_id = offer.to_user_id if offer.from_user_id == me.id else offer.from_user_id

    if payload.action == "counter":
        service.apply_counter(offer, me.id, payload.cash_delta_minor)
    offer.status = new_status

    thread_id = await db.scalar(
        select(Conversation.id).where(Conversation.offer_id == offer.id)
    )
    now = datetime.now(UTC)

    if payload.message and thread_id:
        db.add(
            Message(
                conversation_id=thread_id,
                sender_id=me.id,
                body=payload.message,
                created_at=now,
            )
        )

    # A completed trade closes both listings — they are no longer on the table.
    if new_status == OfferStatus.completed:
        offered = (
            await db.scalars(
                select(OfferItem.listing_id).where(OfferItem.offer_id == offer.id)
            )
        ).all()
        ids = [offer.listing_id, *offered]
        for listing in (await db.scalars(select(Listing).where(Listing.id.in_(ids)))).all():
            listing.status = ListingStatus.completed

    await db.flush()
    out = await service.present(db, offer, me.id, locale)

    headline = {
        "accept": "Taklifingiz qabul qilindi",
        "decline": "Taklifingiz rad etildi",
        "counter": f"{me.full_name} qarshi taklif yubordi",
        "complete": "Savdo yakunlandi",
        "dispute": "Savdo bo‘yicha nizo ochildi",
    }[payload.action]

    await service.notify(
        db,
        user_id=peer_id,
        kind=NotifyKind.offer,
        title=headline,
        body=service.deal_summary(out),
        target_type=NotifyTargetType.chat,
        target_id=thread_id,
        avatar_url=me.avatar_url,
    )

    await db.commit()
    return out
