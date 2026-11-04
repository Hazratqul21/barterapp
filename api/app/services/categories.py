"""Kategoriyalar: `categories` jadvalidan o'qish va kiritilgan kodni tekshirish.

Ro'yxat koddan emas, bazadan keladi: admin panel yangisini qo'shadi,
nomini o'zgartiradi yoki yashiradi va bu darhol ilova hamda saytda ko'rinadi.

Kategoriya `id` si e'londagi `tag` va `/listings?tag=` filtri, shuning uchun
ilova uni hech narsaga tarjima qilmasdan qaytarib yuboradi.
"""

from __future__ import annotations

import re
import unicodedata

from fastapi import HTTPException, Request, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.category import Category

LOCALES = ("uz", "ru", "en")

# Kirillcha nom ham o'qiladigan kod bersin: «Космос» → kosmos.
_CYRILLIC = dict(zip(
    "абвгдеёжзийклмнопрстуфхцчшщъыьэюяўқғҳ",
    ["a", "b", "v", "g", "d", "e", "yo", "j", "z", "i", "y", "k", "l", "m", "n", "o",
     "p", "r", "s", "t", "u", "f", "x", "ts", "ch", "sh", "sh", "", "i", "", "e", "yu",
     "ya", "o", "q", "g", "h"],
))


async def all_categories(db: AsyncSession, *, include_hidden: bool = False) -> list[Category]:
    query = select(Category).order_by(Category.position, Category.created_at)
    if not include_hidden:
        query = query.where(Category.is_active.is_(True))
    return list((await db.scalars(query)).all())


def localized(category: Category, locale: str) -> str:
    """Tarjimasi yo'q til o'zbekchasini ko'rsatadi."""
    return category.name.get(locale) or category.name["uz"]


def image_url(request: Request, category: Category) -> str | None:
    if not category.image:
        return None
    return f"{settings.api_base(request)}{settings.media_url_prefix}/{category.image}"


async def get_or_404(db: AsyncSession, category_id: str) -> Category:
    category = await db.get(Category, category_id)
    if category is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Bunday kategoriya yo'q.")
    return category


async def require_active(
    db: AsyncSession, category_id: str | None, *, allow_hidden: bool = False
) -> None:
    """E'lon yoki istak faqat ko'rinib turgan kategoriyaga qo'yiladi.

    Yashirilgan kategoriya tanlovda yo'q; eski ilova uni yuborsa ham,
    yangi e'lon u yerga tushmasligi kerak.
    """
    if category_id is None:
        return
    category = await db.get(Category, category_id)
    if category is None or not (category.is_active or allow_hidden):
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY, "Bunday kategoriya yo'q yoki yashirilgan."
        )


def slugify(text: str) -> str:
    """Nomdan lotincha kod: «Qishloq xo‘jaligi» → qishloq-xojaligi."""
    text = "".join(_CYRILLIC.get(ch, ch) for ch in text.lower())
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", text).strip("-")[:32] or "kategoriya"


async def free_id(db: AsyncSession, name: str) -> str:
    """Band bo'lmagan kod: `kosmonavtika`, band bo'lsa `kosmonavtika-2` …"""
    base = slugify(name)
    candidate, n = base, 1
    while await db.get(Category, candidate) is not None:
        n += 1
        candidate = f"{base}-{n}"
    return candidate


async def next_position(db: AsyncSession) -> int:
    last = await db.scalar(select(func.max(Category.position)))
    return (last if last is not None else -1) + 1
