from __future__ import annotations

import enum
import json
import logging
import uuid
from datetime import UTC, datetime

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import Field, field_validator
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.locale import resolve_locale
from app.core.security import current_moderator
from app.db.session import get_db
from app.models.device import Device
from app.models.listing import Listing, ListingStatus, ListingTranslation
from app.models.moderation import (
    Report,
    ReportReason,
    ReportStatus,
    ReportTargetType,
)
from app.models.social import Notification, NotifyKind, NotifyTargetType
from app.models.user import User
from app.schemas.common import ApiModel
from app.services import analytics, settings_store
from app.services.fcm import FcmError, FcmTransport, ServiceAccount
from app.services.matching import rebuild_matches

router = APIRouter(prefix="/admin", tags=["admin"])

log = logging.getLogger("barter.admin")


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


# ─────────────────────────────────────────────────────────────────────────────
# Tahlil
# ─────────────────────────────────────────────────────────────────────────────


@router.get("/analytics/funnel")
async def analytics_funnel(
    days: int = Query(default=30, ge=1, le=365),
    me: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Ko'rsatildi → ochildi → saqlandi → taklif → savdo."""
    return await analytics.funnel(db, days=days)


@router.get("/analytics/empty-searches")
async def analytics_empty_searches(
    days: int = Query(default=30, ge=1, le=365),
    limit: int = Query(default=50, ge=1, le=200),
    me: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    """Odamlar izlab topa olmagan narsalar — bozordagi bo'shliq."""
    return await analytics.empty_searches(db, days=days, limit=limit)


@router.get("/analytics/cold-listings")
async def analytics_cold_listings(
    days: int = Query(default=30, ge=1, le=365),
    min_impressions: int = Query(default=20, ge=1),
    limit: int = Query(default=50, ge=1, le=200),
    me: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    """Ko'p ko'rsatilgan, lekin ochilmagan e'lonlar."""
    return await analytics.cold_listings(
        db, days=days, min_impressions=min_impressions, limit=limit
    )


@router.get("/analytics/match-quality")
async def analytics_match_quality(
    days: int = Query(default=30, ge=1, le=365),
    me: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Matching algoritmi haqiqatan ishlayaptimi."""
    return await analytics.match_quality(db, days=days)


@router.get("/analytics/search-gaps")
async def analytics_search_gaps(
    days: int = Query(default=30, ge=1, le=365),
    me: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    """Qaysi turkumda qidiruv eng ko'p quruq qaytadi."""
    return await analytics.search_gaps(db, days=days)


# ─────────────────────────────────────────────────────────────────────────────
# Push yuborish
# ─────────────────────────────────────────────────────────────────────────────


class Segment(str, enum.Enum):
    """Kimga yuboriladi."""

    everyone = "everyone"
    #: E'loni bor savdogarlar — faol tomon.
    with_listings = "with_listings"
    #: E'loni yo'q hisoblar. Ularni qaytarish uchun.
    without_listings = "without_listings"
    #: Bitta viloyat. Mavsumiy yoki mahalliy xabar uchun.
    region = "region"


class PushIn(ApiModel):
    title: dict[str, str]
    body: dict[str, str]
    segment: Segment = Segment.everyone
    #: `segment=region` uchun viloyat nomi.
    region: str | None = None

    target_type: NotifyTargetType = NotifyTargetType.matches
    target_id: uuid.UUID | None = None

    #: Haqiqatan yubormasdan, nechta odamga tegishini ko'rsatadi.
    dry_run: bool = False

    @field_validator("title", "body")
    @classmethod
    def _three(cls, value: dict[str, str]) -> dict[str, str]:
        missing = [c for c in ("uz", "ru", "en") if not value.get(c, "").strip()]
        if missing:
            raise ValueError(
                f"Uch tilda ham matn kerak. Yetishmayapti: {', '.join(missing)}"
            )
        return value


class PushOut(ApiModel):
    recipients: int
    queued: int
    dry_run: bool


@router.post("/push", response_model=PushOut)
async def send_push(
    payload: PushIn,
    me: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> PushOut:
    """
    Tanlangan guruhga bildirishnoma yuborish.

    To'g'ridan-to'g'ri push emas — **bildirishnoma qatori** yoziladi va u
    mavjud navbatga (`app.push_send`) tushadi. Shu sababli u boshqa
    hamma narsa bilan bir xil qoidalarga bo'ysunadi: foydalanuvchining
    sozlamalari hurmat qilinadi, sokin soatlarda kutadi, qurilmasi
    yo'qlar o'tkazib yuboriladi. Alohida yo'l qurilsa, bularning
    hammasini ikkinchi marta yozish kerak bo'lardi — va ikkinchisi
    birinchisidan farq qila boshlardi.

    Matn **har bir odamning o'z tilida** yoziladi: `users.locale` ga
    qarab tanlanadi. Bitta tilda yuborish uchdan ikki foydalanuvchiga
    tushunarsiz xabar berardi.

    `dry_run` — nechta odamga tegishini yozmasdan ko'rsatadi. Ommaviy
    yuborishdan oldin buni bosish odat bo'lsin: "hammaga" degan tugma
    qaytarib bo'lmaydigan tugma.
    """
    query = select(User).where(User.deleted_at.is_(None))

    if payload.segment is Segment.region:
        if not payload.region:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST, "Viloyat ko'rsatilmagan."
            )
        query = query.where(User.region == payload.region)

    elif payload.segment in (Segment.with_listings, Segment.without_listings):
        owners = select(Listing.owner_id).where(
            Listing.status == ListingStatus.active
        )
        query = (
            query.where(User.id.in_(owners))
            if payload.segment is Segment.with_listings
            else query.where(User.id.notin_(owners))
        )

    people = (await db.scalars(query)).all()

    if payload.dry_run:
        return PushOut(recipients=len(people), queued=0, dry_run=True)

    now = datetime.now(UTC)
    for person in people:
        locale = person.locale if person.locale in ("uz", "ru", "en") else "uz"
        db.add(
            Notification(
                user_id=person.id,
                kind=NotifyKind.system,
                target_type=payload.target_type,
                target_id=payload.target_id,
                title=payload.title[locale][:200],
                body=payload.body[locale][:400],
                created_at=now,
            )
        )

    await db.commit()
    return PushOut(recipients=len(people), queued=len(people), dry_run=False)


@router.get("/push/status")
async def push_status(
    me: User = Depends(current_moderator), db: AsyncSession = Depends(get_db)
) -> dict:
    """
    Push haqiqatan ucha oladimi.

    Panelda ko'rsatiladi, chunki "yubordim, lekin hech kim olmadi" degan
    holatning eng ko'p sababi shu: transport ulanmagan yoki hech kimda
    qurilma ro'yxatdan o'tmagan. Buni oldindan ko'rsatish yuborgandan
    keyin izlashdan arzon.
    """
    devices = await db.scalar(select(func.count()).select_from(Device))
    pending = await db.scalar(
        select(func.count())
        .select_from(Notification)
        .where(Notification.pushed_at.is_(None))
    )
    by_platform = await db.execute(
        select(Device.platform, func.count()).group_by(Device.platform)
    )

    return {
        # Transport hali ulanmagan: FCM/APNs uchun Firebase kaliti kerak.
        # Shu paytgacha xabar navbatga tushadi va logga yoziladi.
        "transport": "log",
        "transport_ready": False,
        "devices": devices or 0,
        "by_platform": {p.value: n for p, n in by_platform},
        "queued": pending or 0,
    }


# ─────────────────────────────────────────────────────────────────────────────
# Firebase sozlamasi
# ─────────────────────────────────────────────────────────────────────────────


class FirebaseClientIn(ApiModel):
    """
    Mijoz tomoni uchun parametrlar — Firebase konsolidagi «Web app» yoki
    platforma sozlamalaridan.

    Bular maxfiy emas: ular baribir ilova ichida bo'ladi va Google
    hujjatlari ham ularni ochiq deb ataydi. Maxfiy bo'lgani — service
    account kaliti, u alohida va o'qib bo'lmaydi.
    """

    api_key: str = Field(min_length=10)
    app_id: str = Field(min_length=5)
    messaging_sender_id: str = Field(min_length=3)
    project_id: str = Field(min_length=3)
    #: iOS uchun. Android'da kerak emas.
    ios_bundle_id: str | None = None


class FirebaseStatus(ApiModel):
    #: Server xabar yubora oladimi.
    server_ready: bool
    #: Kalitning izi — qaysi kalit turganini ajratish uchun. Kalitning
    #: o'zi hech qachon qaytarilmaydi.
    server_key_fingerprint: str | None = None
    server_project_id: str | None = None

    #: Ilova xabar qabul qila oladimi.
    client_ready: bool
    client: FirebaseClientIn | None = None


@router.get("/firebase", response_model=FirebaseStatus)
async def firebase_status(
    me: User = Depends(current_moderator), db: AsyncSession = Depends(get_db)
) -> FirebaseStatus:
    """
    Nima sozlangan.

    Service account kaliti **qaytarilmaydi** — faqat izi. Panelga kirish
    huquqi bo'lgan hisob yoki o'g'irlangan sessiya kalitni ko'chirib olib
    keta olmasin: uni almashtirish uchun yozish yetarli.
    """
    raw = await settings_store.get(db, settings_store.FCM_SERVICE_ACCOUNT)
    project_id = None
    if raw:
        try:
            project_id = ServiceAccount.parse(raw).project_id
        except FcmError:
            project_id = None

    client_raw = await settings_store.get(db, settings_store.FIREBASE_CLIENT)
    client = FirebaseClientIn(**json.loads(client_raw)) if client_raw else None

    return FirebaseStatus(
        server_ready=bool(raw) and project_id is not None,
        server_key_fingerprint=settings_store.fingerprint(raw) if raw else None,
        server_project_id=project_id,
        client_ready=client is not None,
        client=client,
    )


class ServiceAccountIn(ApiModel):
    #: Firebase konsolidan yuklab olingan JSON faylning butun mazmuni.
    service_account: str


@router.put("/firebase/server", response_model=FirebaseStatus)
async def set_service_account(
    payload: ServiceAccountIn,
    me: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> FirebaseStatus:
    """
    Server kalitini qo'yish.

    Fayl saqlashdan **oldin** tekshiriladi: noto'g'ri fayl qo'yilishi eng
    ehtimolli xato, va uni yuborishga urinilganda emas, aynan shu yerda
    aytish kerak. Aks holda kalit qo'yilgandek ko'rinadi va nima uchun
    hech kim xabar olmayotgani bir hafta izlanadi.
    """
    try:
        account = ServiceAccount.parse(payload.service_account)
    except FcmError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc)) from exc

    await settings_store.put(
        db, settings_store.FCM_SERVICE_ACCOUNT, payload.service_account
    )
    await db.commit()
    log.info("FCM kaliti almashtirildi (loyiha: %s)", account.project_id)
    return await firebase_status(me=me, db=db)


@router.put("/firebase/client", response_model=FirebaseStatus)
async def set_client_config(
    payload: FirebaseClientIn,
    me: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> FirebaseStatus:
    """Ilova ishga tushganda oladigan parametrlar."""
    await settings_store.put(
        db, settings_store.FIREBASE_CLIENT, json.dumps(payload.model_dump())
    )
    await db.commit()
    return await firebase_status(me=me, db=db)


@router.delete("/firebase/server", response_model=FirebaseStatus)
async def clear_service_account(
    me: User = Depends(current_moderator), db: AsyncSession = Depends(get_db)
) -> FirebaseStatus:
    """Kalitni olib tashlash — push quruq rejimga qaytadi."""
    await settings_store.drop(db, settings_store.FCM_SERVICE_ACCOUNT)
    await db.commit()
    return await firebase_status(me=me, db=db)


@router.post("/firebase/test")
async def firebase_test(
    me: User = Depends(current_moderator), db: AsyncSession = Depends(get_db)
) -> dict:
    """
    Kalit haqiqatan ishlaydimi — Google'dan token so'rab ko'radi.

    Xabar yubormaydi: tokenni ololsa, kalit to'g'ri va ruxsatlar joyida.
    Bu tekshiruvni panelda bosish mumkin, ya'ni "kalit ishlayaptimi"
    degan savolga birinchi haqiqiy push kutmasdan javob bor.
    """
    raw = await settings_store.get(db, settings_store.FCM_SERVICE_ACCOUNT)
    if not raw:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Kalit qo'yilmagan.")

    try:
        account = ServiceAccount.parse(raw)
        transport = FcmTransport(account)
        async with httpx.AsyncClient(timeout=20.0) as client:
            await transport._access_token(client)
    except FcmError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc)) from exc
    except Exception as exc:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST, f"Google bilan aloqa bo'lmadi: {exc}"
        ) from exc

    return {"ok": True, "project_id": account.project_id}
