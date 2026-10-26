"""Kategoriya rasmlari: admin yuklagani `media/categories/` da, nomi sozlamada.

Rasm yo'q bo'lsa ilova o'zi bilan kelgan rasmni ko'rsatadi, shuning uchun bu
yerda «standart rasm» tushunchasi yo'q — faqat almashtirilgani bor.
"""

from __future__ import annotations

import io
import secrets

from fastapi import HTTPException, Request, status
from PIL import Image
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.uploads import _process
from app.core.categories import IMAGE_SETTING_PREFIX, image_setting
from app.core.config import settings
from app.models.listing import ListingTag
from app.models.setting import AppSetting
from app.services import settings_store

FOLDER = "categories"

#: Plitka telefonda ~90 pt, 3x ekranda 270 px; 600 px veb va planshet uchun ham yetadi.
EDGE = 600


def public_url(request: Request, name: str) -> str:
    return f"{settings.api_base(request)}{settings.media_url_prefix}/{name}"


async def image_names(db: AsyncSession) -> dict[str, str]:
    """tag → `categories/<fayl>` (faqat almashtirilganlari)."""
    rows = (
        await db.execute(
            select(AppSetting.key, AppSetting.value).where(
                AppSetting.key.startswith(IMAGE_SETTING_PREFIX)
            )
        )
    ).all()
    return {key.removeprefix(IMAGE_SETTING_PREFIX): value for key, value in rows}


async def image_urls(db: AsyncSession, request: Request) -> dict[str, str]:
    return {tag: public_url(request, name) for tag, name in (await image_names(db)).items()}


def square(raw: bytes) -> bytes:
    """Tekshiruv va tozalash `uploads._process` da (format, piksel chegarasi,
    EXIF olib tashlash); keyin markazdan kvadrat qilib kesiladi."""
    processed, _, _ = _process(raw)
    image = Image.open(io.BytesIO(processed))
    side = min(image.size)
    left = (image.width - side) // 2
    top = (image.height - side) // 2
    image = image.crop((left, top, left + side, top + side))
    if side > EDGE:
        image = image.resize((EDGE, EDGE), Image.LANCZOS)
    buffer = io.BytesIO()
    image.save(buffer, format="JPEG", quality=86, optimize=True)
    return buffer.getvalue()


def _remove(name: str | None) -> None:
    if not name or not name.startswith(FOLDER + "/"):
        return
    path = settings.media_root / name
    if path.is_file():
        path.unlink()


async def replace(db: AsyncSession, tag: ListingTag, jpeg: bytes) -> str:
    folder = settings.media_root / FOLDER
    folder.mkdir(parents=True, exist_ok=True)
    # Tasodifiy qo'shimcha: yangi rasm qurilmalardagi eski nusxa keshidan qochadi.
    name = f"{FOLDER}/{tag.value}-{secrets.token_hex(4)}.jpg"
    (settings.media_root / name).write_bytes(jpeg)
    old = await settings_store.get(db, image_setting(tag))
    await settings_store.put(db, image_setting(tag), name)
    await db.commit()
    _remove(old)
    return name


async def reset(db: AsyncSession, tag: ListingTag) -> None:
    old = await settings_store.get(db, image_setting(tag))
    await settings_store.drop(db, image_setting(tag))
    await db.commit()
    _remove(old)


def parse_tag(value: str) -> ListingTag:
    try:
        return ListingTag(value)
    except ValueError:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Bunday kategoriya yo'q.")
