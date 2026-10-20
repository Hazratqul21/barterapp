"""Admin panel: huquqiy hujjatlarni yozish, tahrirlash va PDF yuklash.

Matn Markdown'da, uch tilda. Saqlangan zahoti https://mab.uz/<slug> da
yangi matn chiqadi — reliz yoki deploy kerak emas.
"""

from __future__ import annotations

import secrets
from datetime import datetime

from fastapi import (
    APIRouter,
    Depends,
    File,
    HTTPException,
    Request,
    UploadFile,
    status,
)
from pydantic import Field, field_validator
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import current_moderator
from app.db.session import get_db
from app.models.legal import LegalDocument
from app.models.user import User
from app.schemas.common import ApiModel
from app.services import legal

router = APIRouter(prefix="/admin/legal", tags=["admin"])

#: Bitta tildagi matn chegarasi. Eng uzun hujjat (maxfiylik) ~11 ming belgi.
MAX_BODY_CHARS = 200_000
MAX_PDF_BYTES = 10 * 1024 * 1024
_FILE_DIR = "legal"


def _three(value: dict[str, str], limit: int, what: str) -> dict[str, str]:
    cleaned = {
        k: v.strip()[:limit]
        for k, v in value.items()
        if k in legal.LOCALES and v and v.strip()
    }
    if "uz" not in cleaned:
        raise ValueError(f"{what}ni kamida o'zbekcha yozing.")
    return cleaned


class LegalDocIn(ApiModel):
    title: dict[str, str]
    body: dict[str, str]
    is_published: bool = True
    position: int = Field(default=0, ge=-1000, le=1000)

    @field_validator("title")
    @classmethod
    def _title(cls, value: dict[str, str]) -> dict[str, str]:
        return _three(value, 200, "Sarlavha")

    @field_validator("body")
    @classmethod
    def _body(cls, value: dict[str, str]) -> dict[str, str]:
        return _three(value, MAX_BODY_CHARS, "Matn")


class LegalDocAdminOut(ApiModel):
    slug: str
    title: dict[str, str]
    body: dict[str, str]
    url: str
    file_url: str | None
    is_published: bool
    position: int
    is_core: bool
    has_placeholders: bool
    updated_at: datetime


def _out(doc: LegalDocument) -> LegalDocAdminOut:
    return LegalDocAdminOut(
        slug=doc.slug,
        title=doc.title,
        body=doc.body,
        url=legal.public_url(doc.slug),
        file_url=doc.file_url,
        is_published=doc.is_published,
        position=doc.position,
        is_core=doc.slug in legal.CORE_SLUGS,
        has_placeholders=legal.has_placeholders(doc),
        updated_at=doc.updated_at,
    )


def _check_slug(slug: str) -> None:
    if not legal.SLUG_RE.match(slug):
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            "Manzil nomi: kichik lotin harflari, raqam va «-», 2–40 belgi.",
        )


async def _get(db: AsyncSession, slug: str, *, lock: bool = False) -> LegalDocument:
    query = select(LegalDocument).where(LegalDocument.slug == slug)
    if lock:
        query = query.with_for_update()
    doc = await db.scalar(query)
    if doc is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Hujjat topilmadi.")
    return doc


def _remove_file(url: str | None) -> None:
    if not url:
        return
    name = url.rsplit("/", 1)[-1]
    path = settings.media_root / _FILE_DIR / name
    if path.is_file():
        path.unlink()


@router.get("", response_model=list[LegalDocAdminOut])
async def list_documents(
    _: User = Depends(current_moderator), db: AsyncSession = Depends(get_db)
) -> list[LegalDocAdminOut]:
    docs = (
        await db.scalars(
            select(LegalDocument).order_by(LegalDocument.position, LegalDocument.slug)
        )
    ).all()
    return [_out(d) for d in docs]


@router.put("/{slug}", response_model=LegalDocAdminOut)
async def save_document(
    slug: str,
    payload: LegalDocIn,
    me: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> LegalDocAdminOut:
    """Yangi hujjat yaratadi yoki borini yangilaydi."""
    _check_slug(slug)
    if slug in legal.CORE_SLUGS and not payload.is_published:
        # Ilova va do'konlar shu havolaga ishonadi: yashirilsa, ular 404 oladi.
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "Asosiy hujjatni yashirib bo'lmaydi — ilova va do'konlar unga havola qiladi.",
        )
    doc = await db.scalar(
        select(LegalDocument).where(LegalDocument.slug == slug).with_for_update()
    )
    if doc is None:
        doc = LegalDocument(slug=slug)
        db.add(doc)
    doc.title = payload.title
    doc.body = payload.body
    doc.is_published = payload.is_published
    doc.position = payload.position
    doc.updated_by = me.id
    await db.commit()
    await db.refresh(doc)
    return _out(doc)


@router.delete("/{slug}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_document(
    slug: str,
    _: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> None:
    if slug in legal.CORE_SLUGS:
        raise HTTPException(
            status.HTTP_409_CONFLICT, "Asosiy hujjatni o'chirib bo'lmaydi."
        )
    doc = await _get(db, slug, lock=True)
    _remove_file(doc.file_url)
    await db.delete(doc)
    await db.commit()


@router.post("/{slug}/file", response_model=LegalDocAdminOut)
async def upload_file(
    slug: str,
    request: Request,
    file: UploadFile = File(...),
    me: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> LegalDocAdminOut:
    """Hujjatning PDF nusxasi — sahifada «PDF yuklab olish» bo'lib chiqadi."""
    doc = await _get(db, slug, lock=True)
    raw = await file.read(MAX_PDF_BYTES + 1)
    if len(raw) > MAX_PDF_BYTES:
        raise HTTPException(
            status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, "PDF 10 MB dan oshmasin."
        )
    # Kengaytma yoki Content-Type'ga emas, faylning o'ziga qaraymiz.
    if not raw.startswith(b"%PDF-"):
        raise HTTPException(
            status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, "Faqat PDF fayl yuklanadi."
        )
    folder = settings.media_root / _FILE_DIR
    folder.mkdir(parents=True, exist_ok=True)
    # Tasodifiy qo'shimcha: yangi fayl eski nusxa keshidan qochadi.
    name = f"{slug}-{secrets.token_hex(4)}.pdf"
    (folder / name).write_bytes(raw)
    _remove_file(doc.file_url)
    doc.file_url = (
        str(request.base_url).rstrip("/")
        + f"{settings.media_url_prefix}/{_FILE_DIR}/{name}"
    )
    doc.updated_by = me.id
    await db.commit()
    await db.refresh(doc)
    return _out(doc)


@router.delete("/{slug}/file", response_model=LegalDocAdminOut)
async def delete_file(
    slug: str,
    me: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> LegalDocAdminOut:
    doc = await _get(db, slug, lock=True)
    _remove_file(doc.file_url)
    doc.file_url = None
    doc.updated_by = me.id
    await db.commit()
    await db.refresh(doc)
    return _out(doc)
