"""Admin panel: narxlar, chegirmalar, pullik e'lon kaliti va buyurtmalar.

Narx reliz bilan emas, shu yerdan o'zgaradi. Yangi narx faqat **yangi**
buyurtmalarga ta'sir qiladi: ochilgan buyurtma o'z summasini saqlaydi,
chunki Payme to'lovni aynan o'sha summa bilan tekshiradi.
"""

from __future__ import annotations

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import Field, field_validator
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import current_moderator
from app.db.session import get_db
from app.models.payment import OrderStatus, PaymentOrder, Product, ProductKind
from app.models.user import User
from app.schemas.common import ApiModel
from app.services import billing, settings_store

router = APIRouter(prefix="/admin/billing", tags=["admin"])


class ProductIn(ApiModel):
    kind: ProductKind
    #: Kamida o'zbekcha nom; qolgan tillar bo'sh bo'lsa o'zbekchasi ko'rsatiladi.
    title: dict[str, str]
    price_minor: int = Field(ge=0)
    discount_percent: int = Field(default=0, ge=0, le=100)
    discount_until: datetime | None = None
    quantity: int = Field(default=1, ge=1, le=10_000)
    duration_days: int | None = Field(default=None, ge=1, le=365)
    is_active: bool = False
    position: int = 0
    mxik_code: str | None = Field(default=None, max_length=20)
    package_code: str | None = Field(default=None, max_length=20)
    vat_percent: int = Field(default=0, ge=0, le=100)

    @field_validator("title")
    @classmethod
    def _title(cls, value: dict[str, str]) -> dict[str, str]:
        cleaned = {
            k: v.strip()[:200]
            for k, v in value.items()
            if k in ("uz", "ru", "en") and v and v.strip()
        }
        if "uz" not in cleaned:
            raise ValueError("Tarif nomini kamida o'zbekcha yozing.")
        return cleaned


class ProductAdminOut(ApiModel):
    code: str
    kind: ProductKind
    title: dict[str, str]
    price_minor: int
    final_price_minor: int
    discount_percent: int
    discount_until: datetime | None
    quantity: int
    duration_days: int | None
    is_active: bool
    position: int
    mxik_code: str | None
    package_code: str | None
    vat_percent: int
    #: Shu tarif bo'yicha to'langan buyurtmalar soni.
    paid_orders: int = 0


class BillingOverview(ApiModel):
    payme_configured: bool
    #: Sinov (test.paycom.uz) yoki jangovar (checkout.paycom.uz).
    payme_checkout_url: str
    listing_fee_enabled: bool
    products: list[ProductAdminOut]


class BillingSettingsIn(ApiModel):
    listing_fee_enabled: bool


class OrderAdminOut(ApiModel):
    id: uuid.UUID
    user_id: uuid.UUID | None
    user_phone: str | None = None
    product_code: str
    title: str
    amount_minor: int
    status: OrderStatus
    created_at: datetime
    paid_at: datetime | None


async def _overview(db: AsyncSession) -> BillingOverview:
    products = (await db.scalars(select(Product).order_by(Product.position, Product.code))).all()
    paid = dict(
        (
            await db.execute(
                select(PaymentOrder.product_code, func.count())
                .where(PaymentOrder.status == OrderStatus.paid)
                .group_by(PaymentOrder.product_code)
            )
        ).all()
    )
    return BillingOverview(
        payme_configured=settings.payme_enabled,
        payme_checkout_url=settings.payme_checkout_url,
        listing_fee_enabled=await billing.listing_fee_enabled(db),
        products=[
            ProductAdminOut(
                **{
                    c: getattr(p, c)
                    for c in ProductAdminOut.model_fields
                    if c not in ("final_price_minor", "paid_orders")
                },
                final_price_minor=billing.final_price(p),
                paid_orders=paid.get(p.code, 0),
            )
            for p in products
        ],
    )


@router.get("", response_model=BillingOverview)
async def overview(
    _: User = Depends(current_moderator), db: AsyncSession = Depends(get_db)
) -> BillingOverview:
    return await _overview(db)


@router.put("/settings", response_model=BillingOverview)
async def update_settings(
    payload: BillingSettingsIn,
    _: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> BillingOverview:
    if payload.listing_fee_enabled:
        active = await db.scalar(
            select(func.count()).where(
                Product.kind == ProductKind.listing_pack,
                Product.is_active.is_(True),
                Product.price_minor > 0,
            )
        )
        # Pullik e'lonni yoqib, sotib olinadigan tarif qoldirmaslik —
        # foydalanuvchini to'lov qila olmaydigan devor oldida qoldirish.
        if not active:
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                "Avval kamida bitta faol, narxi belgilangan e'lon tarifini qo'shing.",
            )
    await settings_store.put(
        db, billing.LISTING_FEE_ENABLED, "true" if payload.listing_fee_enabled else "false"
    )
    await db.commit()
    return await _overview(db)


@router.put("/products/{code}", response_model=BillingOverview)
async def upsert_product(
    code: str,
    payload: ProductIn,
    _: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> BillingOverview:
    code = code.strip().lower()
    if not code or len(code) > 40 or not all(ch.isalnum() or ch == "_" for ch in code):
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            "Kod faqat lotin harflari, raqam va _ dan iborat bo'lsin (masalan boost_7d).",
        )
    if payload.kind == ProductKind.boost and not payload.duration_days:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY, "Boost uchun necha kunligini kiriting."
        )
    product = await db.get(Product, code)
    if product is None:
        product = Product(code=code)
        db.add(product)
    for field, value in payload.model_dump().items():
        setattr(product, field, value)
    await db.commit()
    return await _overview(db)


@router.get("/orders", response_model=list[OrderAdminOut])
async def list_orders(
    status_filter: OrderStatus | None = Query(default=None, alias="status"),
    limit: int = Query(default=100, ge=1, le=500),
    _: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> list[OrderAdminOut]:
    query = (
        select(PaymentOrder, User.phone)
        .outerjoin(User, User.id == PaymentOrder.user_id)
        .order_by(PaymentOrder.created_at.desc())
        .limit(limit)
    )
    if status_filter is not None:
        query = query.where(PaymentOrder.status == status_filter)
    rows = (await db.execute(query)).all()
    return [
        OrderAdminOut(
            id=o.id,
            user_id=o.user_id,
            user_phone=phone,
            product_code=o.product_code,
            title=o.title,
            amount_minor=o.amount_minor,
            status=o.status,
            created_at=o.created_at,
            paid_at=o.paid_at,
        )
        for o, phone in rows
    ]
