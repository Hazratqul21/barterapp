"""Ochiq huquqiy hujjatlar: https://mab.uz/privacy, /terms, /offer va h.k.

nginx bu manzillarni shu yerga yo'naltiradi (`deploy/nginx/mab-legal.conf`).
Ilova va do'konlar havolani brauzerda ochadi, shuning uchun javob — tayyor
HTML sahifa. Ro'yxat (`GET /legal`) ilova ichidagi menyu uchun JSON.
"""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, Header, HTTPException, Query, status
from fastapi.responses import HTMLResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.models.legal import LegalDocument
from app.schemas.common import ApiModel
from app.services import legal

router = APIRouter(prefix="/legal", tags=["legal"])

#: Sahifaga hech qanday skript kerak emas — brauzer ham ruxsat bermasin.
_CSP = (
    "default-src 'none'; style-src 'unsafe-inline'; img-src https: data:; "
    "base-uri 'none'; form-action 'none'; frame-ancestors 'none'"
)


class LegalDocOut(ApiModel):
    slug: str
    title: dict[str, str]
    url: str
    file_url: str | None
    updated_at: datetime


async def _published(db: AsyncSession) -> list[LegalDocument]:
    return list(
        (
            await db.scalars(
                select(LegalDocument)
                .where(LegalDocument.is_published.is_(True))
                .order_by(LegalDocument.position, LegalDocument.slug)
            )
        ).all()
    )


@router.get("", response_model=list[LegalDocOut])
async def list_documents(db: AsyncSession = Depends(get_db)) -> list[LegalDocOut]:
    return [
        LegalDocOut(
            slug=d.slug,
            title=d.title,
            url=legal.public_url(d.slug),
            file_url=d.file_url,
            updated_at=d.updated_at,
        )
        for d in await _published(db)
    ]


@router.get("/{slug}", response_class=HTMLResponse)
async def document_page(
    slug: str,
    lang: str | None = Query(default=None, max_length=5),
    accept_language: str | None = Header(default=None),
    db: AsyncSession = Depends(get_db),
) -> HTMLResponse:
    docs = await _published(db)
    doc = next((d for d in docs if d.slug == slug), None)
    if doc is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Hujjat topilmadi.")
    locale = legal.pick_locale(lang, accept_language)
    return HTMLResponse(
        legal.render_page(doc, locale, docs),
        headers={
            "Content-Security-Policy": _CSP,
            "Cache-Control": "public, max-age=300",
            "Vary": "Accept-Language",
        },
    )
