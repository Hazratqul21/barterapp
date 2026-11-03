"""Admin panel: kategoriyalarni qo'shish, tahrirlash, yashirish va o'chirish.

O'zgarish darhol ilova va saytda ko'rinadi — reliz kerak emas.

- **Yashirish** (`is_active=false`): kategoriya ro'yxatdan chiqadi, unga yangi
  e'lon qo'yib bo'lmaydi; eski e'lonlar joyida qoladi va qaytarib ochish mumkin.
- **O'chirish**: faqat e'loni yo'q kategoriya. E'loni borini yashiring —
  aks holda odamlarning e'lonlari kategoriyasiz qolardi.
- **Rasm**: markazdan kvadrat qilib kesiladi; «standart» ilovadagi rasmni qaytaradi.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile, status
from pydantic import Field
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.concurrency import run_in_threadpool

from app.api.uploads import MAX_UPLOAD_BYTES
from app.core.security import current_moderator
from app.db.session import get_db
from app.models.category import Category
from app.models.listing import Listing
from app.models.user import User
from app.schemas.common import ApiModel
from app.services import categories, category_images

router = APIRouter(prefix="/admin/categories", tags=["admin"])


class CategoryName(ApiModel):
    uz: str = Field(min_length=1, max_length=60)
    ru: str | None = Field(default=None, max_length=60)
    en: str | None = Field(default=None, max_length=60)


class CategoryCreate(ApiModel):
    name: CategoryName


class CategoryUpdate(ApiModel):
    """Yuborilmagan maydon o'zgarmaydi."""

    name: CategoryName | None = None
    is_active: bool | None = None
    #: Ro'yxatdagi o'rni (0 — birinchi). Boshqalar surilib joy beradi.
    position: int | None = Field(default=None, ge=0)


class CategoryAdminOut(ApiModel):
    id: str
    name: dict[str, str]
    #: Yuklangan rasm; null — ilovadagi standart rasm ko'rinadi.
    image_url: str | None
    is_active: bool
    position: int
    #: Shu kategoriyadagi barcha e'lonlar (har qanday holatda).
    listing_count: int


def _clean_name(name: CategoryName) -> dict[str, str]:
    """Bo'sh tarjima saqlanmaydi: u o'rnida o'zbekchasi ko'rinadi."""
    return {
        code: value.strip()
        for code in categories.LOCALES
        if (value := getattr(name, code)) and value.strip()
    }


async def _all(db: AsyncSession, request: Request) -> list[CategoryAdminOut]:
    counts = dict(
        (await db.execute(select(Listing.tag, func.count()).group_by(Listing.tag))).all()
    )
    return [
        CategoryAdminOut(
            id=row.id,
            name=row.name,
            image_url=categories.image_url(request, row),
            is_active=row.is_active,
            position=row.position,
            listing_count=counts.get(row.id, 0),
        )
        for row in await categories.all_categories(db, include_hidden=True)
    ]


async def _move(db: AsyncSession, category: Category, position: int) -> None:
    """Tartibni 0, 1, 2 … qilib qayta yozadi, `category` ni `position` ga qo'yib."""
    rows = [
        row for row in await categories.all_categories(db, include_hidden=True)
        if row.id != category.id
    ]
    rows.insert(min(position, len(rows)), category)
    for index, row in enumerate(rows):
        row.position = index


@router.get("", response_model=list[CategoryAdminOut])
async def list_categories(
    request: Request,
    _: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> list[CategoryAdminOut]:
    """Yashirilganlari bilan birga, ilovadagi tartibda."""
    return await _all(db, request)


@router.post("", response_model=list[CategoryAdminOut], status_code=status.HTTP_201_CREATED)
async def create_category(
    payload: CategoryCreate,
    request: Request,
    _: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> list[CategoryAdminOut]:
    """Kod nomdan yasaladi («Kosmonavtika» → `kosmonavtika`) va ro'yxat oxiriga qo'shiladi."""
    name = _clean_name(payload.name)
    if "uz" not in name:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "O‘zbekcha nom majburiy.")
    db.add(
        Category(
            id=await categories.free_id(db, name["uz"]),
            name=name,
            position=await categories.next_position(db),
        )
    )
    await db.commit()
    return await _all(db, request)


@router.patch("/{category_id}", response_model=list[CategoryAdminOut])
async def update_category(
    category_id: str,
    payload: CategoryUpdate,
    request: Request,
    _: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> list[CategoryAdminOut]:
    category = await categories.get_or_404(db, category_id)
    if payload.name is not None:
        name = _clean_name(payload.name)
        if "uz" not in name:
            raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "O‘zbekcha nom majburiy.")
        category.name = name
    if payload.is_active is not None:
        category.is_active = payload.is_active
    if payload.position is not None:
        await _move(db, category, payload.position)
    await db.commit()
    return await _all(db, request)


@router.delete("/{category_id}", response_model=list[CategoryAdminOut])
async def delete_category(
    category_id: str,
    request: Request,
    _: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> list[CategoryAdminOut]:
    category = await categories.get_or_404(db, category_id)
    used = await db.scalar(select(func.count()).where(Listing.tag == category.id))
    if used:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            f"Bu kategoriyada {used} ta e’lon bor. O‘chirib bo‘lmaydi — yashiring.",
        )
    image = category.image
    # Istaklardagi havola o'zi bo'shaydi (ON DELETE SET NULL): «istalgan narsa».
    await db.delete(category)
    await db.commit()
    category_images.remove_file(image)
    return await _all(db, request)


@router.post("/{category_id}/image", response_model=list[CategoryAdminOut])
async def upload_image(
    category_id: str,
    request: Request,
    file: UploadFile = File(...),
    _: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> list[CategoryAdminOut]:
    """Rasm markazdan kvadrat qilib kesiladi va 600×600 gacha kichraytiriladi."""
    category = await categories.get_or_404(db, category_id)
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


@router.delete("/{category_id}/image", response_model=list[CategoryAdminOut])
async def reset_image(
    category_id: str,
    request: Request,
    _: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> list[CategoryAdminOut]:
    await category_images.reset(db, await categories.get_or_404(db, category_id))
    return await _all(db, request)
