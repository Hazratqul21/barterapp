from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.ratelimit import reports as report_limit, source
from app.core.security import current_user
from app.db.session import get_db
from app.models.listing import Listing
from app.models.moderation import (
    Block,
    Report,
    ReportReason,
    ReportTargetType,
)
from app.models.user import User
from app.schemas.common import ApiModel
from app.schemas.user import TraderBrief
from app.services import stats
from app.services.presenter import trader_brief

router = APIRouter(tags=["moderation"])


class ReportIn(ApiModel):
    target_type: ReportTargetType
    target_id: uuid.UUID
    reason: ReportReason
    note: str | None = Field(default=None, max_length=1000)


class ReportOut(ApiModel):
    id: uuid.UUID
    target_type: ReportTargetType
    target_id: uuid.UUID
    reason: ReportReason


@router.post("/blocks/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def block_user(
    user_id: uuid.UUID,
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    """
    Stop dealing with someone. Their listings leave your feed, neither of you
    can send the other an offer, and the chat closes from both sides.

    Idempotent: pressing it twice is what people do when nothing visibly
    happens, and that should not be an error.
    """
    if user_id == me.id:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST, "O'zingizni bloklay olmaysiz."
        )

    target = await db.get(User, user_id)
    if target is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Foydalanuvchi topilmadi.")

    existing = await db.scalar(
        select(Block).where(Block.blocker_id == me.id, Block.blocked_id == user_id)
    )
    if existing is None:
        db.add(Block(blocker_id=me.id, blocked_id=user_id))
        await db.commit()


@router.delete("/blocks/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def unblock_user(
    user_id: uuid.UUID,
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    """
    Lift your own block. Someone else's block on you stays — otherwise this
    endpoint would be a way to undo a decision that was never yours.
    """
    existing = await db.scalar(
        select(Block).where(Block.blocker_id == me.id, Block.blocked_id == user_id)
    )
    if existing is not None:
        await db.delete(existing)
        await db.commit()


@router.get("/blocks", response_model=list[TraderBrief])
async def list_blocks(
    me: User = Depends(current_user), db: AsyncSession = Depends(get_db)
) -> list[TraderBrief]:
    """Only the blocks this account set, because only those can be lifted here."""
    ids = list(
        (
            await db.scalars(select(Block.blocked_id).where(Block.blocker_id == me.id))
        ).all()
    )
    if not ids:
        return []

    users = (await db.scalars(select(User).where(User.id.in_(ids)))).all()
    ratings = await stats.rating_and_reviews(db, ids)
    deals = await stats.completed_deals(db, ids)
    return [
        trader_brief(
            user,
            rating=ratings.get(user.id, (None, 0))[0],
            deals=deals.get(user.id, 0),
        )
        for user in users
    ]


@router.post("/reports", response_model=ReportOut, status_code=status.HTTP_201_CREATED)
async def file_report(
    payload: ReportIn,
    request: Request,
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> ReportOut:
    """
    Hand a complaint to a moderator.

    The target is checked to exist so the queue cannot be filled with reports
    about nothing, and reporting yourself is refused — it is always either a
    mistake or an attempt to test the endpoint.
    """
    report_limit.check(source(request, me))

    if payload.target_type is ReportTargetType.user:
        if payload.target_id == me.id:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST, "O'zingiz haqingizda shikoyat yozib bo'lmaydi."
            )
        exists = await db.get(User, payload.target_id)
    else:
        exists = await db.get(Listing, payload.target_id)

    if exists is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Shikoyat obyekti topilmadi.")

    already = await db.scalar(
        select(Report).where(
            Report.reporter_id == me.id,
            Report.target_type == payload.target_type,
            Report.target_id == payload.target_id,
        )
    )
    if already is not None:
        # Not an error: the complaint is already on file and saying so twice
        # helps nobody. The first one is returned unchanged.
        return ReportOut(
            id=already.id,
            target_type=already.target_type,
            target_id=already.target_id,
            reason=already.reason,
        )

    report = Report(
        reporter_id=me.id,
        target_type=payload.target_type,
        target_id=payload.target_id,
        reason=payload.reason,
        note=payload.note,
    )
    db.add(report)
    await db.commit()
    await db.refresh(report)

    return ReportOut(
        id=report.id,
        target_type=report.target_type,
        target_id=report.target_id,
        reason=report.reason,
    )
