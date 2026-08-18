from __future__ import annotations

import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import Field, field_validator, model_validator
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.locale import resolve_locale
from app.core.security import current_moderator
from app.db.session import get_db
from app.models.feed_block import BlockAction, BlockKind, FeedBlock, FeedBlockText
from app.models.listing import Listing, ListingStatus
from app.models.user import User
from app.schemas.common import ApiModel
from app.schemas.listing import ListingCard
from app.services import stats
from app.services.presenter import listing_card, trader_brief

router = APIRouter(tags=["feed"])

LOCALES = ("uz", "ru", "en")


# ─────────────────────────────────────────────────────────────────────────────
# Shakllar
# ─────────────────────────────────────────────────────────────────────────────


class BlockOut(ApiModel):
    """Mijoz ko'radigan shakl — bitta tilda, tayyor holda."""

    id: uuid.UUID
    kind: BlockKind
    slot: str
    position: int

    title: str
    subtitle: str | None = None
    cta: str | None = None

    image_url: str | None = None
    background: str | None = None

    action: BlockAction
    action_value: str | None = None

    #: `promo_listings` uchun to'ldirilgan kartalar. Mijoz alohida so'rov
    #: yubormasin — bo'lakning butun mazmuni bitta javobda keladi.
    listings: list[ListingCard] = Field(default_factory=list)


class Tri(ApiModel):
    uz: str
    ru: str
    en: str


class TriOptional(ApiModel):
    uz: str | None = None
    ru: str | None = None
    en: str | None = None


class BlockIn(ApiModel):
    kind: BlockKind
    slot: str = Field(min_length=1, max_length=40)
    position: int = 0
    is_active: bool = True

    starts_at: datetime | None = None
    ends_at: datetime | None = None

    title: Tri
    subtitle: TriOptional | None = None
    cta: TriOptional | None = None

    image_url: str | None = None
    background: str | None = Field(default=None, max_length=9)

    action: BlockAction = BlockAction.none
    action_value: str | None = None

    listing_ids: list[uuid.UUID] = Field(default_factory=list)

    @model_validator(mode="after")
    def _window(self) -> "BlockIn":
        """
        Oyna to'g'ri tartibda bo'lsin.

        Bazada ham cheklov bor, lekin u ishga tushganda javob 500 bo'ladi —
        ya'ni admin "serverda xatolik" ko'radi va nimani noto'g'ri
        yozganini bilmaydi. Bu yerda tekshirilsa, 422 va o'qiladigan
        sabab qaytadi.
        """
        if (
            self.starts_at is not None
            and self.ends_at is not None
            and self.ends_at <= self.starts_at
        ):
            raise ValueError(
                "Tugash vaqti boshlanish vaqtidan keyin bo'lishi kerak."
            )
        return self

    @field_validator("background")
    @classmethod
    def _hex(cls, value: str | None) -> str | None:
        if value is None:
            return None
        if not value.startswith("#") or len(value) not in (7, 9):
            raise ValueError("Rang #RRGGBB yoki #AARRGGBB shaklida bo'lsin.")
        return value


class BlockAdminOut(BlockIn):
    """Admin ko'radigan shakl — barcha tillar bilan, tahrirlash uchun."""

    id: uuid.UUID
    created_at: datetime


# ─────────────────────────────────────────────────────────────────────────────
# Yordamchilar
# ─────────────────────────────────────────────────────────────────────────────


def _ids(block: FeedBlock) -> list[uuid.UUID]:
    if not block.listing_ids:
        return []
    out = []
    for raw in block.listing_ids.split(","):
        raw = raw.strip()
        if raw:
            try:
                out.append(uuid.UUID(raw))
            except ValueError:
                # Buzuq id butun bo'lakni yiqitmasin — u shunchaki
                # tushib qoladi va qolgani ko'rinadi.
                continue
    return out


def _text(block: FeedBlock, locale: str) -> FeedBlockText | None:
    by_locale = {t.locale: t for t in block.translations}
    return by_locale.get(locale) or by_locale.get("uz")


async def _cards(
    db: AsyncSession, ids: list[uuid.UUID], locale: str
) -> list[ListingCard]:
    """Tanlangan e'lonlarni **admin bergan tartibda** qaytaradi."""
    if not ids:
        return []

    rows = (
        await db.scalars(
            select(Listing)
            .options(selectinload(Listing.translations), selectinload(Listing.photos))
            .where(Listing.id.in_(ids), Listing.status == ListingStatus.active)
        )
    ).unique().all()

    found = {row.id: row for row in rows}
    if not found:
        return []

    owner_ids = list({row.owner_id for row in found.values()})
    users = (await db.scalars(select(User).where(User.id.in_(owner_ids)))).all()
    ratings = await stats.rating_and_reviews(db, owner_ids)
    deals = await stats.completed_deals(db, owner_ids)
    briefs = {
        u.id: trader_brief(
            u, rating=ratings.get(u.id, (None, 0))[0], deals=deals.get(u.id, 0)
        )
        for u in users
    }

    # SQL `IN` tartibni saqlamaydi; tahririyat tartibi esa aynan muhim,
    # shuning uchun qayta tiziladi.
    return [
        listing_card(found[i], locale, briefs[found[i].owner_id])
        for i in ids
        if i in found and found[i].owner_id in briefs
    ]


# ─────────────────────────────────────────────────────────────────────────────
# Ommaviy
# ─────────────────────────────────────────────────────────────────────────────


@router.get("/feed-blocks", response_model=list[BlockOut])
async def public_blocks(
    slot: str | None = Query(default=None, max_length=40),
    locale: str = Depends(resolve_locale),
    db: AsyncSession = Depends(get_db),
) -> list[BlockOut]:
    """
    Lentaning boshqariladigan bo'laklari.

    Kirish talab qilinmaydi — banner mehmonga ham ko'rinadi.

    Faqat **hozir ko'rinishi kerak** bo'lganlari qaytadi: o'chirilgani,
    hali boshlanmagani va muddati o'tgani filtrlanadi. Bu filtr serverda,
    chunki mijozdagi soat xato bo'lishi mumkin va bayram banneri bir kun
    erta chiqib ketishi mumkin emas.
    """
    now = datetime.now(UTC)

    query = (
        select(FeedBlock)
        .where(
            FeedBlock.is_active.is_(True),
            or_(FeedBlock.starts_at.is_(None), FeedBlock.starts_at <= now),
            or_(FeedBlock.ends_at.is_(None), FeedBlock.ends_at > now),
        )
        .order_by(FeedBlock.slot, FeedBlock.position, FeedBlock.created_at)
    )
    if slot:
        query = query.where(FeedBlock.slot == slot)

    blocks = (await db.scalars(query)).unique().all()

    out: list[BlockOut] = []
    for block in blocks:
        text = _text(block, locale)
        if text is None:
            # Matnsiz bo'lak ko'rsatilmaydi — bo'sh banner xatodek ko'rinadi.
            continue

        out.append(
            BlockOut(
                id=block.id,
                kind=block.kind,
                slot=block.slot,
                position=block.position,
                title=text.title,
                subtitle=text.subtitle,
                cta=text.cta,
                image_url=block.image_url,
                background=block.background,
                action=block.action,
                action_value=block.action_value,
                listings=await _cards(db, _ids(block), locale)
                if block.kind is BlockKind.promo_listings
                else [],
            )
        )

    # Ichi bo'sh qolgan tanlov ko'rsatilmaydi: e'lonlar arxivlangan bo'lsa
    # sarlavha yolg'iz qolib, buzuq ekran bo'lib ko'rinardi.
    return [b for b in out if b.kind is not BlockKind.promo_listings or b.listings]


# ─────────────────────────────────────────────────────────────────────────────
# Admin
# ─────────────────────────────────────────────────────────────────────────────


def _admin_shape(block: FeedBlock) -> BlockAdminOut:
    by_locale = {t.locale: t for t in block.translations}
    return BlockAdminOut(
        id=block.id,
        created_at=block.created_at,
        kind=block.kind,
        slot=block.slot,
        position=block.position,
        is_active=block.is_active,
        starts_at=block.starts_at,
        ends_at=block.ends_at,
        title=Tri(
            uz=by_locale["uz"].title if "uz" in by_locale else "",
            ru=by_locale["ru"].title if "ru" in by_locale else "",
            en=by_locale["en"].title if "en" in by_locale else "",
        ),
        subtitle=TriOptional(
            uz=by_locale.get("uz").subtitle if "uz" in by_locale else None,
            ru=by_locale.get("ru").subtitle if "ru" in by_locale else None,
            en=by_locale.get("en").subtitle if "en" in by_locale else None,
        ),
        cta=TriOptional(
            uz=by_locale.get("uz").cta if "uz" in by_locale else None,
            ru=by_locale.get("ru").cta if "ru" in by_locale else None,
            en=by_locale.get("en").cta if "en" in by_locale else None,
        ),
        image_url=block.image_url,
        background=block.background,
        action=block.action,
        action_value=block.action_value,
        listing_ids=_ids(block),
    )


def _apply(block: FeedBlock, payload: BlockIn) -> None:
    block.kind = payload.kind
    block.slot = payload.slot
    block.position = payload.position
    block.is_active = payload.is_active
    block.starts_at = payload.starts_at
    block.ends_at = payload.ends_at
    block.image_url = payload.image_url
    block.background = payload.background
    block.action = payload.action
    block.action_value = payload.action_value
    block.listing_ids = ",".join(str(i) for i in payload.listing_ids) or None

    block.translations.clear()
    for code in LOCALES:
        block.translations.append(
            FeedBlockText(
                locale=code,
                title=getattr(payload.title, code),
                subtitle=getattr(payload.subtitle, code) if payload.subtitle else None,
                cta=getattr(payload.cta, code) if payload.cta else None,
            )
        )


@router.get("/admin/feed-blocks", response_model=list[BlockAdminOut])
async def admin_list(
    me: User = Depends(current_moderator), db: AsyncSession = Depends(get_db)
) -> list[BlockAdminOut]:
    """Hammasi — o'chirilgani va muddati o'tgani ham."""
    blocks = (
        await db.scalars(
            select(FeedBlock).order_by(FeedBlock.slot, FeedBlock.position)
        )
    ).unique().all()
    return [_admin_shape(b) for b in blocks]


@router.post(
    "/admin/feed-blocks", response_model=BlockAdminOut, status_code=status.HTTP_201_CREATED
)
async def admin_create(
    payload: BlockIn,
    me: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> BlockAdminOut:
    block = FeedBlock()
    _apply(block, payload)
    db.add(block)
    await db.commit()
    await db.refresh(block)
    return _admin_shape(block)


@router.patch("/admin/feed-blocks/{block_id}", response_model=BlockAdminOut)
async def admin_update(
    block_id: uuid.UUID,
    payload: BlockIn,
    me: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> BlockAdminOut:
    block = await db.get(FeedBlock, block_id)
    if block is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Bo'lak topilmadi.")

    _apply(block, payload)
    await db.commit()
    await db.refresh(block)
    return _admin_shape(block)


@router.delete(
    "/admin/feed-blocks/{block_id}", status_code=status.HTTP_204_NO_CONTENT
)
async def admin_delete(
    block_id: uuid.UUID,
    me: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> None:
    block = await db.get(FeedBlock, block_id)
    if block is not None:
        await db.delete(block)
        await db.commit()
