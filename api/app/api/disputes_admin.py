"""
F02 — the operator's side of disputes, and the rules that settle the small ones.

Small disputes are settled by rules the product owner sets here (value limit,
which reasons may be unwound automatically, how long goods stay held). Anything
over the limit, any other reason, and any case where the two sides' records
contradict each other is escalated to an operator — a moderator account.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import current_moderator
from app.db.session import get_db
from app.models.agreement import (
    Dispute,
    DisputeReason,
    DisputeResolution,
    DisputeStatus,
    TradeAgreement,
)
from app.models.offer import Conversation, Offer
from app.models.social import NotifyKind, NotifyTargetType
from app.models.user import User
from app.schemas.common import ApiModel
from app.services import agreements
from app.services import offers as offer_service

router = APIRouter(prefix="/admin", tags=["admin"])


class DisputeRules(ApiModel):
    reservation_hours: int = Field(ge=1, le=720)
    auto_max_value_minor: int = Field(ge=0)
    auto_cancel_reasons: list[DisputeReason]


class DisputeRulesOut(DisputeRules):
    version: int


class DisputeRow(ApiModel):
    id: uuid.UUID
    offer_id: uuid.UUID
    reason: DisputeReason
    note: str | None
    status: DisputeStatus
    resolution: DisputeResolution | None
    decided_by_rule: str | None
    rules_version: int | None
    value_minor: int | None
    opened_by: uuid.UUID
    created_at: datetime
    resolved_at: datetime | None


class ResolveIn(ApiModel):
    resolution: DisputeResolution
    note: str = Field(min_length=3, max_length=1000)


@router.get("/dispute-rules", response_model=DisputeRulesOut)
async def get_rules(
    _: User = Depends(current_moderator), db: AsyncSession = Depends(get_db)
) -> DisputeRulesOut:
    return DisputeRulesOut(**await agreements.load_rules(db))


@router.put("/dispute-rules", response_model=DisputeRulesOut)
async def put_rules(
    payload: DisputeRules,
    _: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> DisputeRulesOut:
    """Change the rules. Each save bumps the version stored on new disputes."""
    try:
        saved = await agreements.save_rules(
            db,
            {
                "reservation_hours": payload.reservation_hours,
                "auto_max_value_minor": payload.auto_max_value_minor,
                "auto_cancel_reasons": [r.value for r in payload.auto_cancel_reasons],
            },
        )
    except agreements.AgreementError as e:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, str(e))
    await db.commit()
    return DisputeRulesOut(**saved)


@router.get("/disputes", response_model=list[DisputeRow])
async def list_disputes(
    status_: DisputeStatus | None = Query(default=DisputeStatus.escalated, alias="status"),
    limit: int = Query(default=50, ge=1, le=200),
    _: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> list[DisputeRow]:
    """The operator queue: escalated disputes, oldest first."""
    query = (
        select(Dispute, TradeAgreement.value_minor)
        .outerjoin(TradeAgreement, TradeAgreement.offer_id == Dispute.offer_id)
        .order_by(Dispute.created_at.asc())
        .limit(limit)
    )
    if status_ is not None:
        query = query.where(Dispute.status == status_)
    rows = (await db.execute(query)).all()
    return [
        DisputeRow(
            id=d.id,
            offer_id=d.offer_id,
            reason=d.reason,
            note=d.note,
            status=d.status,
            resolution=d.resolution,
            decided_by_rule=d.decided_by_rule,
            rules_version=d.rules_version,
            value_minor=value,
            opened_by=d.opened_by,
            created_at=d.created_at,
            resolved_at=d.resolved_at,
        )
        for d, value in rows
    ]


@router.post("/disputes/{dispute_id}/resolve", status_code=status.HTTP_204_NO_CONTENT)
async def resolve_dispute(
    dispute_id: uuid.UUID,
    payload: ResolveIn,
    me: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> None:
    """An operator's decision: unwind the deal or let it stand. Final."""
    dispute = await db.scalar(
        select(Dispute).where(Dispute.id == dispute_id).with_for_update()
    )
    if dispute is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Nizo topilmadi.")
    offer = await db.scalar(
        select(Offer).where(Offer.id == dispute.offer_id).with_for_update()
    )
    now = datetime.now(UTC)
    try:
        await agreements.resolve(
            db, dispute, offer, payload.resolution,
            by=me.id, rule=None, note=payload.note, now=now,
        )
    except agreements.AgreementError as e:
        raise HTTPException(status.HTTP_409_CONFLICT, str(e))

    thread_id = await db.scalar(
        select(Conversation.id).where(Conversation.offer_id == offer.id)
    )
    title = (
        "Nizo hal qilindi: savdo bekor, narsalar sotuvga qaytdi"
        if payload.resolution == DisputeResolution.cancel
        else "Nizo hal qilindi: savdo yakunlangan deb topildi"
    )
    for user_id in (offer.from_user_id, offer.to_user_id):
        await offer_service.notify(
            db,
            user_id=user_id,
            kind=NotifyKind.offer,
            title=title,
            body=payload.note,
            target_type=NotifyTargetType.chat,
            target_id=thread_id,
        )
    await db.commit()
