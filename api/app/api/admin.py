from __future__ import annotations

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.locale import resolve_locale
from app.core.security import current_moderator
from app.db.session import get_db
from app.models.listing import Listing, ListingStatus, ListingTranslation
from app.models.moderation import (
    Report,
    ReportReason,
    ReportStatus,
    ReportTargetType,
)
from app.models.user import User
from app.schemas.common import ApiModel
from app.services.matching import rebuild_matches

router = APIRouter(prefix="/admin", tags=["admin"])


class ReportRow(ApiModel):
    id: uuid.UUID
    target_type: ReportTargetType
    target_id: uuid.UUID
    reason: ReportReason
    note: str | None
    review_status: ReportStatus
    created_at: datetime

    reporter_id: uuid.UUID
    reporter_name: str

    #: Nima haqidaligi — e'lon sarlavhasi yoki savdogar ismi. Moderator
    #: navbatni qo'shimcha so'rovlarsiz o'qiy olishi uchun shu yerda keladi.
    target_label: str | None = None
    #: Shu obyekt haqida jami nechta shikoyat bor. Bitta shikoyat — nizo,
    #: o'nta — naqsh; navbatni saralashda eng muhim raqam shu.
    report_count: int = 1


class ReportAction(ApiModel):
    review_status: ReportStatus
    #: Moderatorning izohi shikoyatchining izohining ustiga yozilmaydi —
    #: alohida maydon, chunki ikkalasi ham keyin kerak bo'ladi.
    resolution: str | None = Field(default=None, max_length=1000)


def _who(user: User) -> str:
    """
    A name a moderator can act on.

    A freshly signed-up account has no name yet, and an empty string in the
    queue identifies nobody. The phone number is what the moderator would look
    for anyway, so it stands in rather than a blank.
    """
    return user.full_name.strip() or user.phone


async def _labels(
    db: AsyncSession, reports: list[Report], locale: str
) -> dict[uuid.UUID, str]:
    """Bir so'rovda butun sahifaning nomlari, har qator uchun bittadan emas."""
    listing_ids = [
        r.target_id for r in reports if r.target_type is ReportTargetType.listing
    ]
    user_ids = [r.target_id for r in reports if r.target_type is ReportTargetType.user]

    labels: dict[uuid.UUID, str] = {}

    if listing_ids:
        rows = await db.execute(
            select(ListingTranslation.listing_id, ListingTranslation.title).where(
                ListingTranslation.listing_id.in_(listing_ids),
                ListingTranslation.locale == locale,
            )
        )
        labels.update({lid: title for lid, title in rows})

    if user_ids:
        rows = await db.scalars(select(User).where(User.id.in_(user_ids)))
        labels.update({u.id: _who(u) for u in rows})

    return labels


@router.get("/reports", response_model=list[ReportRow])
async def list_reports(
    review_status: ReportStatus | None = ReportStatus.open,
    target_type: ReportTargetType | None = None,
    limit: int = Query(default=50, ge=1, le=200),
    locale: str = Depends(resolve_locale),
    me: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> list[ReportRow]:
    """
    The moderation queue, oldest first.

    Oldest first rather than newest: a complaint that has been sitting for
    three days is the one costing the product a user. A newest-first queue
    quietly buries exactly those.

    Defaults to `open`. Pass `review_status=` empty to see everything.
    """
    query = select(Report).order_by(Report.created_at).limit(limit)
    if review_status is not None:
        query = query.where(Report.review_status == review_status)
    if target_type is not None:
        query = query.where(Report.target_type == target_type)

    reports = list((await db.scalars(query)).all())
    if not reports:
        return []

    labels = await _labels(db, reports, locale)

    reporters = {
        u.id: u
        for u in await db.scalars(
            select(User).where(User.id.in_({r.reporter_id for r in reports}))
        )
    }

    # Bir obyekt haqida jami nechta shikoyat borligi — holatidan qat'i nazar.
    counts: dict[tuple[ReportTargetType, uuid.UUID], int] = {}
    rows = await db.execute(
        select(Report.target_type, Report.target_id).where(
            Report.target_id.in_({r.target_id for r in reports})
        )
    )
    for t_type, t_id in rows:
        counts[(t_type, t_id)] = counts.get((t_type, t_id), 0) + 1

    return [
        ReportRow(
            id=r.id,
            target_type=r.target_type,
            target_id=r.target_id,
            reason=r.reason,
            note=r.note,
            review_status=r.review_status,
            created_at=r.created_at,
            reporter_id=r.reporter_id,
            reporter_name=(
                _who(reporters[r.reporter_id])
                if r.reporter_id in reporters
                else "—"
            ),
            target_label=labels.get(r.target_id),
            report_count=counts.get((r.target_type, r.target_id), 1),
        )
        for r in reports
    ]


@router.patch("/reports/{report_id}", response_model=ReportRow)
async def act_on_report(
    report_id: uuid.UUID,
    payload: ReportAction,
    locale: str = Depends(resolve_locale),
    me: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> ReportRow:
    """Mark a complaint reviewed, actioned or dismissed."""
    report = await db.get(Report, report_id)
    if report is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Shikoyat topilmadi.")

    report.review_status = payload.review_status
    if payload.resolution is not None:
        # Shikoyatchining izohi saqlanib qoladi — moderatorning qarori uning
        # ustiga yozilsa, keyin nima uchun shunday qilingani noma'lum qolardi.
        report.note = (
            f"{report.note}\n\n— moderator: {payload.resolution}"
            if report.note
            else f"— moderator: {payload.resolution}"
        )

    await db.commit()
    await db.refresh(report)

    rows = await list_reports(
        review_status=None, target_type=None, limit=200, locale=locale, me=me, db=db
    )
    for row in rows:
        if row.id == report.id:
            return row

    raise HTTPException(status.HTTP_404_NOT_FOUND, "Shikoyat topilmadi.")


@router.post(
    "/listings/{listing_id}/archive", status_code=status.HTTP_204_NO_CONTENT
)
async def force_archive(
    listing_id: uuid.UUID,
    me: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> None:
    """
    Take a listing down.

    Without this, "actioned" would be a status with nothing behind it — the
    moderator could read the complaint and mark it handled, and the listing
    would stay on the feed. Unlike the owner's own delete, this ignores live
    offers: a scam listing with an offer against it is more urgent to remove,
    not less.
    """
    listing = await db.get(Listing, listing_id)
    if listing is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "E'lon topilmadi.")

    if listing.status is not ListingStatus.archived:
        listing.status = ListingStatus.archived
        await db.commit()
        await rebuild_matches(db, listing.owner_id, force=True)
