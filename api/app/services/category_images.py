"""Kategoriya rasmlari: admin yuklagani `media/categories/` da, yo'li `categories.image` da.

Rasm yo'q bo'lsa ilova o'zi bilan kelgan rasmni (yangi kategoriyada —
belgisini) ko'rsatadi, shuning uchun bu yerda «standart rasm» tushunchasi
yo'q — faqat yuklangani bor.
"""

from __future__ import annotations

import io
import secrets

from PIL import Image
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.uploads import _process
from app.core.config import settings
from app.models.category import Category

FOLDER = "categories"

#: Plitka telefonda ~90 pt, 3x ekranda 270 px; 600 px veb va planshet uchun ham yetadi.
EDGE = 600


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


def remove_file(name: str | None) -> None:
    if not name or not name.startswith(FOLDER + "/"):
        return
    path = settings.media_root / name
    if path.is_file():
        path.unlink()


async def replace(db: AsyncSession, category: Category, jpeg: bytes) -> str:
    folder = settings.media_root / FOLDER
    folder.mkdir(parents=True, exist_ok=True)
    # Tasodifiy qo'shimcha: yangi rasm qurilmalardagi eski nusxa keshidan qochadi.
    name = f"{FOLDER}/{category.id}-{secrets.token_hex(4)}.jpg"
    (settings.media_root / name).write_bytes(jpeg)
    old = category.image
    category.image = name
    await db.commit()
    remove_file(old)
    return name


async def reset(db: AsyncSession, category: Category) -> None:
    old = category.image
    category.image = None
    await db.commit()
    remove_file(old)
