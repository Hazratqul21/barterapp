from __future__ import annotations

import enum
import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, Timestamps, UUIDPrimaryKey


class BlockKind(str, enum.Enum):
    """Lentadagi boshqariladigan bo'lak turi."""

    #: Katta rasm + sarlavha. Reklama yoki mavsumiy e'lon.
    banner = "banner"
    #: Tanlangan e'lonlar qatori ("Tahririyat tanlovi").
    promo_listings = "promo_listings"
    #: Matnli chiziq — e'lon, ogohlantirish, bayram tabrigi.
    notice = "notice"


class BlockAction(str, enum.Enum):
    """Bosilganda nima bo'ladi."""

    none = "none"
    open_listing = "open_listing"
    open_search = "open_search"
    open_category = "open_category"
    open_url = "open_url"


class FeedBlock(Base, UUIDPrimaryKey, Timestamps):
    """
    Lentaning boshqariladigan bo'lagi.

    Nega bu kerak: banner va tanlangan e'lonlar mijoz kodiga qattiq
    yozilgan edi. Bayram uchun banner almashtirish yoki mavsumiy e'lonni
    tepaga chiqarish uchun **uch platformaga yangi reliz** chiqarish
    kerak bo'lardi — App Store ko'rigi bilan birga bu bir hafta. Mavsum
    esa bir haftada o'tib ketadi.

    Endi bu jadval boshqaradi va o'zgarish darhol kuchga kiradi.
    """

    __tablename__ = "feed_blocks"

    kind: Mapped[BlockKind] = mapped_column(
        Enum(BlockKind, name="feed_block_kind"), nullable=False
    )

    #: Lentaning qaysi joyida. Mijoz shu nomga qarab joylashtiradi.
    slot: Mapped[str] = mapped_column(String(40), nullable=False)

    #: Bir slot ichidagi tartib. Kichigi tepada.
    position: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")

    is_active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default="true"
    )

    #: Rejalashtirish. Bayram banneri oldindan tayyorlanadi va o'z vaqtida
    #: o'zi paydo bo'ladi — kimdir yarim tunda tugma bosishi shart emas.
    starts_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    ends_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    image_url: Mapped[str | None] = mapped_column(Text)
    #: Fon rangi (#RRGGBB). Rasm yuklanmaguncha shu ko'rinadi.
    background: Mapped[str | None] = mapped_column(String(9))

    action: Mapped[BlockAction] = mapped_column(
        Enum(BlockAction, name="feed_block_action"),
        nullable=False,
        server_default="none",
    )
    #: Amalga bog'liq qiymat: e'lon id, qidiruv matni, kategoriya kodi, URL.
    action_value: Mapped[str | None] = mapped_column(Text)

    #: `promo_listings` uchun — vergul bilan ajratilgan e'lon id'lari.
    #: Alohida jadval emas, chunki bu tahririyat tanlovi: tartib muhim va
    #: ro'yxat qisqa (odatda 3-8 ta).
    listing_ids: Mapped[str | None] = mapped_column(Text)

    translations: Mapped[list[FeedBlockText]] = relationship(
        back_populates="block", cascade="all, delete-orphan", lazy="selectin"
    )

    __table_args__ = (
        CheckConstraint(
            "ends_at IS NULL OR starts_at IS NULL OR ends_at > starts_at",
            name="window_ordered",
        ),
        # Mijozning so'rovi: shu slotdagi faol bo'laklar, tartib bo'yicha.
        Index("ix_feed_blocks_slot", "slot", "is_active", "position"),
    )


class FeedBlockText(Base):
    """Bir tildagi matn. Uch til ham majburiy — yarim tarjima chiqmasin."""

    __tablename__ = "feed_block_texts"

    block_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("feed_blocks.id", ondelete="CASCADE"),
        primary_key=True,
    )
    locale: Mapped[str] = mapped_column(String(2), primary_key=True)

    title: Mapped[str] = mapped_column(String(160), nullable=False)
    subtitle: Mapped[str | None] = mapped_column(String(300))
    cta: Mapped[str | None] = mapped_column(String(60))

    block: Mapped[FeedBlock] = relationship(back_populates="translations")

    __table_args__ = (
        CheckConstraint("locale IN ('uz', 'ru', 'en')", name="locale_supported"),
    )
