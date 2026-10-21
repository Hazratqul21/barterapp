from __future__ import annotations

import uuid

from sqlalchemy import Boolean, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, Timestamps


class LegalDocument(Base, Timestamps):
    """
    Maxfiylik siyosati, foydalanish shartlari, oferta va shu kabi hujjatlar.

    Matn kodda emas, bazada: yurist bir vergulni o'zgartirsa, reliz kerak
    bo'lmasligi kerak. Admin paneldan tahrirlanadi va https://mab.uz/<slug>
    manzilida ochiladi. `updated_at` sahifada «Oxirgi yangilanish» sanasi.
    """

    __tablename__ = "legal_documents"

    #: Manzildagi nom: `privacy` → https://mab.uz/privacy.
    slug: Mapped[str] = mapped_column(String(40), primary_key=True)
    #: {"uz": ..., "ru": ..., "en": ...}; o'zbekchasi majburiy.
    title: Mapped[dict] = mapped_column(JSONB, nullable=False)
    #: Markdown, tillar bo'yicha. Tarjimasi yo'q til o'zbekchani ko'rsatadi.
    body: Mapped[dict] = mapped_column(JSONB, nullable=False)
    #: Yuklangan PDF (ixtiyoriy) — sahifada «PDF yuklab olish» havolasi.
    file_url: Mapped[str | None] = mapped_column(Text)
    is_published: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default="true"
    )
    position: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")
    updated_by: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL")
    )
