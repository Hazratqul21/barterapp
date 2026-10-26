"""Admin panel: kategoriya rasmlarini almashtirish.

Yuklangan zahoti ilova va saytda yangi rasm chiqadi — reliz kerak emas.
«Standartga qaytarish» ilova o'zi bilan kelgan rasmni qaytaradi.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.concurrency import run_in_threadpool

from app.api.uploads import MAX_UPLOAD_BYTES
from app.core.categories import CATEGORY_NAMES
from app.core.security import current_moderator
from app.db.session import get_db
from app.models.user import User
from app.schemas.common import ApiModel
from app.services import category_images

router = APIRouter(prefix="/admin/categories", tags=["admin"])


class CategoryAdminOut(ApiModel):
    id: str
    name: dict[str, str]
    #: Yuklangan rasm; null — ilovadagi standart rasm ko'rinadi.
    image_url: str | None


async def _all(db: AsyncSession, request: Request) -> list[CategoryAdminOut]:
    urls = await category_images.image_urls(db, request)
    return [
        CategoryAdminOut(id=tag.value, name=names, image_url=urls.get(tag.value))
        for tag, names in CATEGORY_NAMES.items()
    ]


@router.get("", response_model=list[CategoryAdminOut])
async def list_categories(
    request: Request,
    _: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> list[CategoryAdminOut]:
    return await _all(db, request)


@router.post("/{tag}/image", response_model=list[CategoryAdminOut])
async def upload_image(
    tag: str,
    request: Request,
    file: UploadFile = File(...),
    _: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> list[CategoryAdminOut]:
    """Rasm markazdan kvadrat qilib kesiladi va 600×600 gacha kichraytiriladi."""
    category = category_images.parse_tag(tag)
    raw = await file.read(MAX_UPLOAD_BYTES + 1)
    if not raw:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Fayl bo‘sh.")
    if len(raw) > MAX_UPLOAD_BYTES:
        raise HTTPException(
            status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, "Rasm 12 MB dan oshmasin."
        )
    jpeg = await run_in_threadpool(category_images.square, raw)
    await category_images.replace(db, category, jpeg)
    return await _all(db, request)


@router.delete("/{tag}/image", response_model=list[CategoryAdminOut])
async def reset_image(
    tag: str,
    request: Request,
    _: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> list[CategoryAdminOut]:
    await category_images.reset(db, category_images.parse_tag(tag))
    return await _all(db, request)
