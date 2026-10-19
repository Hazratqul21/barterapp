"""To'lovlar: tariflar (narxlar admin paneldan), buyurtmalar, Payme tranzaksiyalari.

Narx kodda emas, bazada: narxlar hali belgilanmagan va tez-tez o'zgaradi,
chegirma beriladi. Har o'zgarish uchun reliz chiqarish kerak bo'lmasin.

Buyurtma narxni **yaratilgan paytdagi** holatida saqlaydi. Payme pulni
buyurtma summasiga qarab tekshiradi; admin narxni to'lov o'rtasida
o'zgartirsa, foydalanuvchi ko'rgan summa bilan Payme so'ragan summa
farq qilib qolmasin.
"""

from __future__ import annotations

import enum
import uuid
from datetime import datetime

from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Integer,
    SmallInteger,
    String,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, Timestamps, UUIDPrimaryKey


class ProductKind(str, enum.Enum):
    #: N ta e'lon joylash huquqi (`quantity`).
    listing_pack = "listing_pack"
    #: E'lonni `duration_days` kunga yuqoriga ko'tarish (premium belgisi).
    boost = "boost"


class OrderStatus(str, enum.Enum):
    pending = "pending"
    paid = "paid"
    cancelled = "cancelled"


class Product(Base, Timestamps):
    """Sotiladigan narsa. Admin narxini, chegirmasini va holatini boshqaradi."""

    __tablename__ = "products"

    #: Barqaror nom (`listing_1`, `boost_7d`): ilova va hisobotlar shunga
    #: tayanadi, shuning uchun UUID emas.
    code: Mapped[str] = mapped_column(String(40), primary_key=True)
    kind: Mapped[ProductKind] = mapped_column(
        Enum(ProductKind, name="product_kind"), nullable=False
    )
    #: {"uz": ..., "ru": ..., "en": ...}
    title: Mapped[dict] = mapped_column(JSONB, nullable=False)
    #: Tiyinda (1 so'm = 100 tiyin) — Payme ham tiyinda ishlaydi.
    price_minor: Mapped[int] = mapped_column(BigInteger, nullable=False)
    discount_percent: Mapped[int] = mapped_column(
        Integer, nullable=False, server_default="0"
    )
    #: Bo'sh — chegirma muddatsiz; to'lgan bo'lsa chegirma o'z-o'zidan tugaydi.
    discount_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    quantity: Mapped[int] = mapped_column(Integer, nullable=False, server_default="1")
    duration_days: Mapped[int | None] = mapped_column(Integer)
    is_active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default="false"
    )
    position: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")

    #: Fiskal chek uchun (MXIK / IKPU va o'lchov birligi kodi). Payme chekni
    #: shu ma'lumot bilan chiqaradi; bo'sh bo'lsa chek tafsiloti yuborilmaydi.
    mxik_code: Mapped[str | None] = mapped_column(String(20))
    package_code: Mapped[str | None] = mapped_column(String(20))
    vat_percent: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")

    __table_args__ = (
        CheckConstraint("price_minor >= 0", name="price_non_negative"),
        CheckConstraint(
            "discount_percent >= 0 AND discount_percent <= 100", name="discount_range"
        ),
        CheckConstraint("quantity >= 1", name="quantity_positive"),
    )


class PaymentOrder(Base, UUIDPrimaryKey, Timestamps):
    """Bitta xarid. Payme `account.order_id` sifatida shu ID'ni oladi."""

    __tablename__ = "payment_orders"

    #: Hisob o'chirilsa ham moliyaviy yozuv qoladi — buxgalteriya va
    #: Payme bilan solishtirish uchun.
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL")
    )
    product_code: Mapped[str] = mapped_column(String(40), nullable=False)
    kind: Mapped[ProductKind] = mapped_column(
        Enum(ProductKind, name="product_kind"), nullable=False
    )
    listing_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("listings.id", ondelete="SET NULL")
    )
    quantity: Mapped[int] = mapped_column(Integer, nullable=False, server_default="1")
    duration_days: Mapped[int | None] = mapped_column(Integer)
    amount_minor: Mapped[int] = mapped_column(BigInteger, nullable=False)
    #: Buyurtma paytidagi mahsulot nomi (keyin o'zgarsa ham chekda shu qoladi).
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    status: Mapped[OrderStatus] = mapped_column(
        Enum(OrderStatus, name="order_status"),
        nullable=False,
        server_default="pending",
    )
    provider: Mapped[str] = mapped_column(String(20), nullable=False, server_default="payme")
    paid_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    __table_args__ = (
        CheckConstraint("amount_minor > 0", name="amount_positive"),
        Index("ix_payment_orders_user", "user_id", "created_at"),
    )


class PaymeTransaction(Base, UUIDPrimaryKey, Timestamps):
    """
    Payme tomonidagi tranzaksiya. Vaqtlar — Payme kabi millisekundda.

    Holatlar (Payme hujjati bo'yicha): 1 — yaratilgan, 2 — bajarilgan,
    -1 — bajarilmasdan bekor qilingan, -2 — bajarilgandan keyin bekor qilingan.
    """

    __tablename__ = "payme_transactions"

    payme_id: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    order_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("payment_orders.id"), nullable=False
    )
    amount_minor: Mapped[int] = mapped_column(BigInteger, nullable=False)
    state: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    #: Payme'dagi yaratilish vaqti (`params.time`).
    payme_time: Mapped[int] = mapped_column(BigInteger, nullable=False)
    create_time: Mapped[int] = mapped_column(BigInteger, nullable=False)
    perform_time: Mapped[int] = mapped_column(BigInteger, nullable=False, server_default="0")
    cancel_time: Mapped[int] = mapped_column(BigInteger, nullable=False, server_default="0")
    reason: Mapped[int | None] = mapped_column(SmallInteger)

    __table_args__ = (
        Index("ix_payme_transactions_order", "order_id"),
        Index("ix_payme_transactions_create_time", "create_time"),
    )
