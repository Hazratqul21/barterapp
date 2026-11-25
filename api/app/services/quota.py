"""Bepul e'lonlar soni: oddiy kvota va birinchi foydalanuvchilar aksiyasi.

Ikkalasi ham admin panelda: kvota va aksiya hajmi reliz emas, biznes qarori.
Kvota hisob ochilganda beriladi; keyin sonni o'zgartirish eski hisoblarga
tegmaydi (aksiyani mavjudlarga tarqatish — alohida, ochiq amal).
"""

from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from datetime import UTC, datetime

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.services import settings_store

#: Ro'yxatdan o'tish va aksiya tarqatish bir vaqtda sanamasin.
_LOCK = 0x4D4142_01


@dataclass(frozen=True)
class Quota:
    #: Har yangi hisobga beriladigan bepul e'lonlar.
    free_listings: int = 2
    #: Birinchi nechta hisob aksiyaga kiradi; 0 — aksiya yo'q.
    promo_users: int = 0
    #: Ularga beriladigan bepul e'lonlar.
    promo_listings: int = 0

    @property
    def promo_on(self) -> bool:
        return self.promo_users > 0 and self.promo_listings > 0


async def read(db: AsyncSession) -> Quota:
    raw = await settings_store.get(db, settings_store.LISTING_QUOTA)
    if not raw:
        return Quota()
    try:
        return Quota(**json.loads(raw))
    except (ValueError, TypeError):
        # Buzuq yozuv ro'yxatdan o'tishni to'xtatmasin.
        return Quota()


async def write(db: AsyncSession, quota: Quota) -> None:
    await settings_store.put(db, settings_store.LISTING_QUOTA, json.dumps(asdict(quota)))


async def promo_used(db: AsyncSession) -> int:
    """O'chirilgan hisob ham sanaladi: joy qayta bo'shamasin."""
    return (
        await db.scalar(
            select(func.count()).select_from(User).where(User.promo_granted_at.is_not(None))
        )
        or 0
    )


async def _lock(db: AsyncSession) -> None:
    await db.execute(select(func.pg_advisory_xact_lock(_LOCK)))


async def grant_on_signup(db: AsyncSession, user: User) -> None:
    quota = await read(db)
    user.free_listings_left = quota.free_listings
    if not quota.promo_on:
        return
    await _lock(db)
    if await promo_used(db) < quota.promo_users:
        user.free_listings_left = max(quota.free_listings, quota.promo_listings)
        user.promo_granted_at = datetime.now(UTC)


async def grant_to_existing(db: AsyncSession) -> int:
    """Aksiyani oldin kirganlarga, kirgan tartibida tarqatadi. Takrori zararsiz."""
    quota = await read(db)
    if not quota.promo_on:
        return 0
    await _lock(db)
    room = quota.promo_users - await promo_used(db)
    if room <= 0:
        return 0
    users = (
        await db.scalars(
            select(User)
            .where(
                User.promo_granted_at.is_(None),
                User.deleted_at.is_(None),
                User.is_moderator.is_(False),
            )
            .order_by(User.created_at, User.id)
            .limit(room)
            .with_for_update()
            # Kredit shu paytda sarflanayotgan bo'lishi mumkin: eski nusxa emas,
            # qulflangan qatordagi son ustiga yoziladi.
            .execution_options(populate_existing=True)
        )
    ).all()
    now = datetime.now(UTC)
    for user in users:
        # Sotib olingan paket kamaymaydi: faqat ko'tariladi.
        user.free_listings_left = max(user.free_listings_left, quota.promo_listings)
        user.promo_granted_at = now
    return len(users)
