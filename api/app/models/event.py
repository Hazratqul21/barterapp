from __future__ import annotations

import enum
import uuid
from datetime import datetime

from sqlalchemy import (
    BigInteger,
    DateTime,
    ForeignKey,
    Index,
    String,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class EventKind(str, enum.Enum):
    """
    Nima sodir bo'lgani.

    Ro'yxatning yarmi — **sodir bo'lmagan** narsalar: ko'rsatilib bosilmagan
    e'lon, hech narsa topmagan qidiruv, rad etilgan moslik. Modelni o'rgatadigan
    ma'lumotning katta qismi aynan shular. Faqat muvaffaqiyatlarni yozadigan
    tizim "hamma narsa zo'r" deb ko'rsatadi va nima uchun odamlar ketayotganini
    hech qachon tushuntira olmaydi.
    """

    # Lenta
    listing_impression = "listing_impression"
    listing_view = "listing_view"
    listing_dwell = "listing_dwell"

    # Qidiruv
    search = "search"
    search_empty = "search_empty"
    filter_applied = "filter_applied"

    # Niyat
    favorite_add = "favorite_add"
    favorite_remove = "favorite_remove"
    offer_sent = "offer_sent"
    chat_opened = "chat_opened"

    # Moslik
    match_shown = "match_shown"
    match_dismissed = "match_dismissed"
    match_opened = "match_opened"

    # Natija
    offer_accepted = "offer_accepted"
    offer_declined = "offer_declined"
    trade_completed = "trade_completed"


class Event(Base):
    """
    Bir marta sodir bo'lgan narsa.

    Bu jadval boshqa hammasidan bitta jihati bilan farq qiladi: **uni orqaga
    qaytib to'ldirib bo'lmaydi**. Kod keyin ham yoziladi, model keyin ham
    o'rgatiladi, lekin bugun yozilmagan hodisa butunlay yo'qoladi. Shu sababli
    u modeldan oldin qurildi.

    Yozuvlar hech qachon o'zgartirilmaydi va o'chirilmaydi (saqlash muddatidan
    tashqari): bu tarix, holat emas.
    """

    __tablename__ = "events"

    # UUID emas, bigserial: bu jadval boshqalardan yuz barobar tez o'sadi va
    # tartiblangan butun son ham kichikroq, ham indeksda tezroq. Vaqt bo'yicha
    # tabiiy tartib ham shu ustundan chiqadi.
    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)

    occurred_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )

    # SET NULL, CASCADE emas: hisob o'chirilganda tahlil yo'qolmasin, lekin
    # hodisa endi hech kimga bog'lanmasin. CASCADE bo'lsa bitta hisobning
    # o'chirilishi oylik hisobotni jimgina o'zgartirib yuborardi.
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL")
    )

    #: Kirmagan odamning ko'rish seansi. Anonim ko'rish tahlilning yarmi —
    #: odam aynan ro'yxatdan o'tishdan oldin nima izlaganini bilish kerak.
    session_id: Mapped[str | None] = mapped_column(String(64))

    # Enum emas, String: yangi hodisa turi migratsiyasiz qo'shilsin. Tekshiruv
    # API darajasida (`EventKind`), ya'ni noto'g'ri nom bazaga umuman
    # yetib bormaydi — lekin yangi nom qo'shish uchun jadvalni qulflash
    # kerak emas.
    kind: Mapped[str] = mapped_column(String(40), nullable=False)

    target_type: Mapped[str | None] = mapped_column(String(20))
    target_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True))

    #: Turga qarab o'zgaradigan qo'shimchalar: qidiruv matni, lentadagi o'rin,
    #: qo'llanilgan filtrlar, ko'rish davomiyligi.
    #:
    #: ⚠️ Bu yerga shaxsiy ma'lumot yozilmaydi — telefon, manzil, xabar matni.
    #: Tahlil uchun ular kerak emas, sizib chiqish uchun esa yetarli.
    payload: Mapped[dict] = mapped_column(JSONB, nullable=False, server_default="{}")

    locale: Mapped[str | None] = mapped_column(String(2))
    platform: Mapped[str | None] = mapped_column(String(10))

    #: Mijoz bergan noyob kalit. Tarmoq uzilganda mijoz paketni qayta yuboradi;
    #: usiz o'sha ko'rsatishlar ikki marta sanalardi va CTR jimgina ikki
    #: barobar pasayib ketardi — ya'ni raqamlar bor, lekin ular yolg'on.
    dedupe_key: Mapped[str | None] = mapped_column(String(64))

    __table_args__ = (
        UniqueConstraint("dedupe_key", name="uq_event_dedupe"),
        # Tahlilning deyarli hammasi "oxirgi N kun, shu turdagi hodisalar".
        Index("ix_events_kind_time", "kind", "occurred_at"),
        # Bitta e'lon yoki moslik bo'yicha voronka.
        Index("ix_events_target", "target_type", "target_id", "occurred_at"),
        # Bitta odamning yo'li — seans tahlili va takroriy xatti-harakat.
        Index("ix_events_user_time", "user_id", "occurred_at"),
    )
