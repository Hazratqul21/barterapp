"""Shaxsni tasdiqlash navbati (moderator)."""

from __future__ import annotations

import logging
import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from pydantic import Field, field_validator
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import current_moderator
from app.db.session import get_db
from app.models.social import (
    NotifyKind,
    NotifyTargetType,
    VerificationDocument,
    VerificationState,
    VerificationStep,
)
from app.models.user import User, UserType
from app.schemas.common import ApiModel
from app.services import verification
from app.services.offers import notify

router = APIRouter(prefix="/admin/verifications", tags=["admin"])

log = logging.getLogger("barter.admin")


class VerificationRow(ApiModel):
    id: uuid.UUID
    step: str
    submitted_at: datetime | None
    user_id: uuid.UUID
    first_name: str
    last_name: str
    phone: str | None
    email: str | None
    user_type: UserType
    company: str | None
    tax_id: str | None
    trust_score: int
    documents: list[str]
    #: Selfi pasportdan oldin tasdiqlanmaydi — panel tugmani shunga qarab yopadi.
    passport_done: bool
    is_me: bool


class RejectIn(ApiModel):
    reason: str = Field(min_length=3, max_length=300)

    @field_validator("reason")
    @classmethod
    def _trim(cls, value: str) -> str:
        value = value.strip()
        if len(value) < 3:
            raise ValueError("Sababni yozing.")
        return value


_LABELS = {
    "passport": "Pasport yoki ID karta",
    "video": "Selfi",
    "business": "Korxona hujjatlari",
}


async def _pending(
    db: AsyncSession, step_id: uuid.UUID, me: User
) -> tuple[VerificationStep, User]:
    row = await db.scalar(
        select(VerificationStep).where(VerificationStep.id == step_id).with_for_update()
    )
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Ariza topilmadi.")
    if row.state != VerificationState.pending:
        raise HTTPException(status.HTTP_409_CONFLICT, "Bu ariza ko‘rib chiqib bo‘lingan.")
    if row.user_id == me.id:
        raise HTTPException(
            status.HTTP_409_CONFLICT, "O‘z arizangizni o‘zingiz ko‘rib chiqa olmaysiz."
        )
    # Ball ikki moderatorning parallel qarorida yo'qolmasin.
    user = await db.scalar(select(User).where(User.id == row.user_id).with_for_update())
    return row, user


@router.get("", response_model=list[VerificationRow])
async def list_pending(
    limit: int = Query(default=50, ge=1, le=200),
    me: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> list[VerificationRow]:
    """Eskisidan boshlab: eng uzoq kutgan odam birinchi."""
    rows = (
        await db.execute(
            select(VerificationStep, User)
            .join(User, User.id == VerificationStep.user_id)
            .where(
                VerificationStep.state == VerificationState.pending,
                User.deleted_at.is_(None),
            )
            .order_by(VerificationStep.submitted_at.asc().nulls_first(), VerificationStep.id)
            .limit(limit)
        )
    ).all()
    ids = {u.id for _, u in rows}
    documents: dict[tuple[uuid.UUID, str], list[str]] = {}
    passports: set[uuid.UUID] = set()
    if ids:
        for user_id, step, kind in await db.execute(
            select(
                VerificationDocument.user_id,
                VerificationDocument.step,
                VerificationDocument.kind,
            ).where(VerificationDocument.user_id.in_(ids))
        ):
            documents.setdefault((user_id, step), []).append(kind)
        passports = set(
            (
                await db.scalars(
                    select(VerificationStep.user_id).where(
                        VerificationStep.user_id.in_(ids),
                        VerificationStep.step == "passport",
                        VerificationStep.state == VerificationState.done,
                    )
                )
            ).all()
        )
    return [
        VerificationRow(
            id=s.id,
            step=s.step,
            submitted_at=s.submitted_at,
            user_id=u.id,
            first_name=u.first_name,
            last_name=u.last_name,
            phone=u.phone,
            email=u.email,
            user_type=u.user_type,
            company=u.handle,
            tax_id=u.tax_id,
            trust_score=u.trust_score,
            documents=sorted(documents.get((u.id, s.step), [])),
            passport_done=u.id in passports,
            is_me=u.id == me.id,
        )
        for s, u in rows
    ]


@router.get("/{step_id}/documents/{kind}")
async def read_document(
    step_id: uuid.UUID,
    kind: str,
    me: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> Response:
    row = await db.get(VerificationStep, step_id)
    document = None
    if row is not None and row.state == VerificationState.pending:
        document = await db.scalar(
            select(VerificationDocument).where(
                VerificationDocument.user_id == row.user_id,
                VerificationDocument.step == row.step,
                VerificationDocument.kind == kind,
            )
        )
    if document is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Hujjat topilmadi.")
    data = verification.unseal(document)
    if data is None:
        raise HTTPException(
            status.HTTP_410_GONE, "Hujjat ochilmadi. Foydalanuvchidan qayta so‘rang."
        )
    # Kim kimning hujjatini ochgani iz qoldiradi.
    log.info("Hujjat ko'rildi: moderator=%s ariza=%s tur=%s", me.id, step_id, kind)
    return Response(
        data, media_type="image/jpeg", headers={"Cache-Control": "no-store, private"}
    )


@router.post("/{step_id}/approve", status_code=status.HTTP_204_NO_CONTENT)
async def approve(
    step_id: uuid.UUID,
    me: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> None:
    row, user = await _pending(db, step_id, me)
    if row.step == "video":
        passport = await db.scalar(
            select(VerificationStep.state).where(
                VerificationStep.user_id == user.id, VerificationStep.step == "passport"
            )
        )
        if passport != VerificationState.done:
            raise HTTPException(
                status.HTTP_409_CONFLICT, "Avval pasportni tasdiqlang, keyin selfini."
            )
    row.state = VerificationState.done
    await _close(db, row, user, me, "Tasdiqlandi: " + _LABELS.get(row.step, row.step),
                 "Hujjatlaringiz ko‘rib chiqildi va tasdiqlandi.")


@router.post("/{step_id}/reject", status_code=status.HTTP_204_NO_CONTENT)
async def reject(
    step_id: uuid.UUID,
    payload: RejectIn,
    me: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> None:
    row, user = await _pending(db, step_id, me)
    row.state = VerificationState.todo
    row.reject_reason = payload.reason
    await _close(db, row, user, me, "Tasdiqlanmadi: " + _LABELS.get(row.step, row.step),
                 payload.reason)


async def _close(
    db: AsyncSession, row: VerificationStep, user: User, me: User, title: str, body: str
) -> None:
    row.reviewed_at = datetime.now(UTC)
    row.reviewed_by = me.id
    await verification.drop_documents(db, user.id, row.step)
    await verification.recompute(db, user)
    await notify(
        db,
        user_id=user.id,
        kind=NotifyKind.system,
        title=title,
        body=body,
        target_type=NotifyTargetType.verification,
        target_id=row.id,
    )
    await db.commit()
    log.info("Ariza yopildi: moderator=%s ariza=%s holat=%s", me.id, row.id, row.state.value)
