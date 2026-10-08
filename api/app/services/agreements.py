"""
F02 — the life of an accepted deal: hold, confirm, dispute, expire.

Every function here runs inside the caller's transaction and never commits;
`api/offers.py` and `api/admin.py` own the commit. That keeps "reserve all
listings or none" a single database transaction.
"""

from __future__ import annotations

import json
import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta

from sqlalchemy import or_, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.agreement import (
    Dispute,
    DisputeReason,
    DisputeResolution,
    DisputeStatus,
    Reservation,
    TradeAgreement,
    TradeConfirmation,
)
from app.models.listing import Listing, ListingStatus
from app.models.offer import Offer, OfferItem, OfferStatus
from app.models.setting import AppSetting

RULES_KEY = "dispute_rules"

#: What a fresh install starts with. Conservative on purpose: only "the other
#: side never came" is settled automatically, and only for small deals. Every
#: other reason, and anything over the limit, goes to a person.
DEFAULT_RULES: dict = {
    "version": 1,
    #: How long accepted goods stay held without both confirmations.
    "reservation_hours": 72,
    #: Deals worth more than this (minor units, so'm × 100) always go to an
    #: operator. 5,000,000 so'm.
    "auto_max_value_minor": 500_000_000,
    #: Reasons a rule may settle by unwinding the deal, when the other side
    #: has not already confirmed.
    "auto_cancel_reasons": ["no_show"],
}


class AgreementError(Exception):
    """A refused step, phrased for the person who tried it."""


# ── rules ────────────────────────────────────────────────────────────────────


async def load_rules(db: AsyncSession) -> dict:
    row = await db.get(AppSetting, RULES_KEY)
    if row is None:
        return dict(DEFAULT_RULES)
    try:
        stored = json.loads(row.value)
    except ValueError:
        return dict(DEFAULT_RULES)
    return {**DEFAULT_RULES, **stored}


def validate_rules(new: dict) -> dict:
    """The editable part of the rules, checked; raises AgreementError."""
    hours = new.get("reservation_hours")
    limit = new.get("auto_max_value_minor")
    reasons = new.get("auto_cancel_reasons")
    if not isinstance(hours, int) or not 1 <= hours <= 24 * 30:
        raise AgreementError("reservation_hours 1 dan 720 gacha bo‘lishi kerak.")
    if not isinstance(limit, int) or limit < 0:
        raise AgreementError("auto_max_value_minor manfiy bo‘lmasin.")
    known = {r.value for r in DisputeReason}
    if not isinstance(reasons, list) or not set(reasons) <= known:
        raise AgreementError(f"auto_cancel_reasons faqat: {sorted(known)}.")
    return {
        "reservation_hours": hours,
        "auto_max_value_minor": limit,
        "auto_cancel_reasons": sorted(set(reasons)),
    }


async def save_rules(db: AsyncSession, new: dict) -> dict:
    """Store new rules with the next version number."""
    clean = validate_rules(new)
    current = await load_rules(db)
    stored = {**clean, "version": int(current.get("version", 1)) + 1}
    row = await db.get(AppSetting, RULES_KEY)
    if row is None:
        db.add(AppSetting(key=RULES_KEY, value=json.dumps(stored)))
    else:
        row.value = json.dumps(stored)
    return stored


# ── helpers ──────────────────────────────────────────────────────────────────


async def deal_listing_ids(db: AsyncSession, offer: Offer) -> list[uuid.UUID]:
    offered = (
        await db.scalars(select(OfferItem.listing_id).where(OfferItem.offer_id == offer.id))
    ).all()
    return [offer.listing_id, *offered]


async def active_reservations(db: AsyncSession, offer_id: uuid.UUID) -> list[Reservation]:
    return list(
        (
            await db.scalars(
                select(Reservation).where(
                    Reservation.offer_id == offer_id, Reservation.active.is_(True)
                )
            )
        ).all()
    )


async def _release(
    db: AsyncSession, offer: Offer, reason: str, *, relist: bool, now: datetime
) -> None:
    """End the holds; put the goods back on sale unless the trade happened."""
    holds = await active_reservations(db, offer.id)
    ids = [h.listing_id for h in holds]
    for h in holds:
        h.active = False
        h.released_at = now
        h.release_reason = reason
    if relist and ids:
        await db.execute(
            update(Listing)
            .where(Listing.id.in_(ids), Listing.status == ListingStatus.in_negotiation)
            .values(status=ListingStatus.active)
        )


# ── accept: freeze terms, hold everything ────────────────────────────────────


async def reserve(db: AsyncSession, offer: Offer, *, now: datetime) -> TradeAgreement:
    """
    Hold every listing in the deal for this offer — all of them or none.

    Listings are locked in id order, so two accepts touching the same pair of
    listings cannot deadlock; the partial unique index on active reservations
    is the backstop if anything slips past.
    """
    ids = await deal_listing_ids(db, offer)
    listings = (
        await db.scalars(
            select(Listing).where(Listing.id.in_(ids)).order_by(Listing.id).with_for_update()
        )
    ).all()
    if len(listings) != len(set(ids)):
        raise AgreementError("Savdodagi e’lonlardan biri endi mavjud emas.")
    if any(l.status != ListingStatus.active for l in listings):
        raise AgreementError(
            "Savdodagi e’lonlardan biri allaqachon band yoki sotilgan."
        )
    taken = await db.scalar(
        select(Reservation.id).where(
            Reservation.listing_id.in_(ids), Reservation.active.is_(True)
        )
    )
    if taken is not None:
        raise AgreementError("Savdodagi e’lonlardan biri boshqa kelishuvda band.")

    rules = await load_rules(db)
    until = now + timedelta(hours=int(rules["reservation_hours"]))
    for listing in listings:
        listing.status = ListingStatus.in_negotiation
        db.add(
            Reservation(
                listing_id=listing.id, offer_id=offer.id, expires_at=until, created_at=now
            )
        )

    by_id = {l.id: l for l in listings}
    wanted = by_id[offer.listing_id]
    offered = [by_id[i] for i in ids[1:]]
    terms = {
        "wanted": {"id": str(wanted.id), "value_minor": wanted.value_minor},
        "offered": [{"id": str(l.id), "value_minor": l.value_minor} for l in offered],
        "cash_delta_minor": offer.cash_delta_minor,
        "currency": offer.currency,
        "from_user_id": str(offer.from_user_id),
        "to_user_id": str(offer.to_user_id),
    }
    value = max(
        wanted.value_minor, sum(l.value_minor for l in offered)
    ) + abs(offer.cash_delta_minor)
    agreement = TradeAgreement(offer_id=offer.id, terms=terms, value_minor=value)
    db.add(agreement)
    try:
        await db.flush()
    except IntegrityError:
        raise AgreementError("Savdodagi e’lonlardan biri boshqa kelishuvda band.")
    return agreement


# ── confirm / complete ───────────────────────────────────────────────────────


async def confirmed_by(db: AsyncSession, offer_id: uuid.UUID) -> set[uuid.UUID]:
    return set(
        (
            await db.scalars(
                select(TradeConfirmation.user_id).where(TradeConfirmation.offer_id == offer_id)
            )
        ).all()
    )


async def confirm(
    db: AsyncSession, offer: Offer, user_id: uuid.UUID, *, now: datetime
) -> bool:
    """Record one side's "done". True when both sides now have."""
    done = await confirmed_by(db, offer.id)
    if user_id not in done:
        db.add(TradeConfirmation(offer_id=offer.id, user_id=user_id, confirmed_at=now))
        done.add(user_id)
    return {offer.from_user_id, offer.to_user_id} <= done


async def complete(db: AsyncSession, offer: Offer, *, now: datetime) -> None:
    """The trade happened: goods off the market, rival offers expired."""
    ids = await deal_listing_ids(db, offer)
    await _release(db, offer, "completed", relist=False, now=now)
    await db.execute(
        update(Listing).where(Listing.id.in_(ids)).values(status=ListingStatus.completed)
    )
    open_ = (OfferStatus.pending, OfferStatus.talking, OfferStatus.accepted)
    via_item = select(OfferItem.offer_id).where(OfferItem.listing_id.in_(ids))
    await db.execute(
        update(Offer)
        .where(
            Offer.id != offer.id,
            Offer.status.in_(open_),
            or_(Offer.listing_id.in_(ids), Offer.id.in_(via_item)),
        )
        .values(status=OfferStatus.expired)
    )
    offer.status = OfferStatus.completed


async def cancel(db: AsyncSession, offer: Offer, reason: str, *, now: datetime) -> None:
    """Unwind: holds released, listings back on sale, the deal is undone."""
    await _release(db, offer, reason, relist=True, now=now)
    offer.status = OfferStatus.refunded


# ── disputes ─────────────────────────────────────────────────────────────────


@dataclass
class DisputeOutcome:
    dispute: Dispute
    auto: bool


async def open_dispute(
    db: AsyncSession,
    offer: Offer,
    opener_id: uuid.UUID,
    reason: DisputeReason,
    note: str | None,
    *,
    now: datetime,
) -> DisputeOutcome:
    """
    Pause the deal and apply the rules.

    A rule may settle it only when the deal is under the admin's value limit,
    the reason is one the admin listed, and the other side has not already
    confirmed — a confirmation from them contradicts "they never came", and
    that contradiction is exactly what a person should look at.
    """
    rules = await load_rules(db)
    agreement = await db.scalar(
        select(TradeAgreement).where(TradeAgreement.offer_id == offer.id)
    )
    value = agreement.value_minor if agreement else 0
    other = offer.to_user_id if opener_id == offer.from_user_id else offer.from_user_id

    # Pause the clock: a disputed deal must not lapse while it is looked at.
    for hold in await active_reservations(db, offer.id):
        hold.expires_at = None

    dispute = Dispute(
        offer_id=offer.id,
        opened_by=opener_id,
        reason=reason,
        note=note,
        status=DisputeStatus.escalated,
        rules_version=int(rules.get("version", 1)),
        created_at=now,
    )
    db.add(dispute)
    offer.status = OfferStatus.disputed

    if value > int(rules["auto_max_value_minor"]):
        dispute.decided_by_rule = "over_limit"
    elif reason.value not in rules["auto_cancel_reasons"]:
        dispute.decided_by_rule = "reason_needs_operator"
    elif other in await confirmed_by(db, offer.id):
        dispute.decided_by_rule = "contradicted_by_confirmation"
    else:
        await resolve(
            db, dispute, offer, DisputeResolution.cancel,
            by=None, rule=f"auto_cancel:{reason.value}", note=None, now=now,
        )
        return DisputeOutcome(dispute, auto=True)
    await db.flush()
    return DisputeOutcome(dispute, auto=False)


async def resolve(
    db: AsyncSession,
    dispute: Dispute,
    offer: Offer,
    resolution: DisputeResolution,
    *,
    by: uuid.UUID | None,
    rule: str | None,
    note: str | None,
    now: datetime,
) -> None:
    if dispute.status == DisputeStatus.resolved:
        raise AgreementError("Bu nizo allaqachon hal qilingan.")
    if resolution == DisputeResolution.cancel:
        await cancel(db, offer, "resolved", now=now)
    else:
        await complete(db, offer, now=now)
    dispute.status = DisputeStatus.resolved
    dispute.resolution = resolution
    dispute.resolved_by = by
    dispute.decided_by_rule = rule if by is None else "operator"
    dispute.resolution_note = note
    dispute.resolved_at = now


# ── expiry ───────────────────────────────────────────────────────────────────


async def expire_stale(db: AsyncSession, *, now: datetime) -> int:
    """
    Undo accepted deals whose hold ran out without both confirmations.

    Cheap enough to run on every offers request (one indexed query when there
    is nothing to do), and safe to call from a cron worker later.
    """
    offer_ids = (
        await db.scalars(
            select(Reservation.offer_id)
            .where(
                Reservation.active.is_(True),
                Reservation.expires_at.is_not(None),
                Reservation.expires_at < now,
            )
            .distinct()
        )
    ).all()
    count = 0
    for offer_id in offer_ids:
        offer = await db.scalar(
            select(Offer).where(Offer.id == offer_id).with_for_update(skip_locked=True)
        )
        if offer is None or offer.status != OfferStatus.accepted:
            continue
        await _release(db, offer, "expired", relist=True, now=now)
        offer.status = OfferStatus.expired
        count += 1
    return count
