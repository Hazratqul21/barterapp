"""Foydalanuvchi uchun to'lov API: tariflar ro'yxati va buyurtma.

Oqim:

1. Ilova `GET /payments/products` dan narxlarni oladi (admin belgilagan).
2. `POST /payments/orders` — buyurtma yaratiladi, javobda Payme sahifasi
   manzili (`checkout_url`) keladi. Ilova uni brauzerda ochadi.
3. Foydalanuvchi Payme sahifasida karta raqami, muddati va SMS kodni
   kiritadi. Payme bizning `/payments/payme` ga murojaat qiladi va
   to'lov bajarilganda buyurtma `paid` bo'ladi.
4. Ilova `GET /payments/orders/{id}` orqali holatni tekshiradi.
"""

from __future__ import annotations

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.locale import resolve_locale
from app.core.security import current_user
from app.db.session import get_db
from app.models.listing import Listing, ListingStatus
from app.models.payment import OrderStatus, PaymentOrder, Product, ProductKind
from app.models.user import User
from app.schemas.common import ApiModel
from app.services import billing

router = APIRouter(prefix="/payments", tags=["payments"])


class ProductOut(ApiModel):
    code: str
    kind: ProductKind
    title: str
    #: Chegirmasiz narx, tiyinda.
    price_minor: int
    #: To'lanadigan narx (chegirma bilan), tiyinda.
    final_price_minor: int
    discount_percent: int
    discount_until: datetime | None
    quantity: int
    duration_days: int | None


class OrderIn(ApiModel):
    product_code: str = Field(min_length=1, max_length=40)
    #: `boost` uchun majburiy — qaysi e'lon ko'tariladi.
    listing_id: uuid.UUID | None = None


class OrderOut(ApiModel):
    id: uuid.UUID
    product_code: str
    kind: ProductKind
    title: str
    amount_minor: int
    status: OrderStatus
    listing_id: uuid.UUID | None
    quantity: int
    duration_days: int | None
    created_at: datetime
    paid_at: datetime | None
    #: Faqat `pending` buyurtmada.
    checkout_url: str | None = None


class BillingStatus(ApiModel):
    #: To'lov tizimi ulanganmi (Payme kaliti bor).
    payments_enabled: bool
    #: Bepul kvota tugaganda e'lon pullikmi.
    listing_fee_enabled: bool
    free_listings_left: int


def product_out(product: Product, locale: str) -> ProductOut:
    return ProductOut(
        code=product.code,
        kind=product.kind,
        title=billing.title_for(product, locale),
        price_minor=product.price_minor,
        final_price_minor=billing.final_price(product),
        discount_percent=product.discount_percent if billing.discount_active(product) else 0,
        discount_until=product.discount_until if billing.discount_active(product) else None,
        quantity=product.quantity,
        duration_days=product.duration_days,
    )


def order_out(order: PaymentOrder, locale: str) -> OrderOut:
    out = OrderOut.model_validate(order)
    if order.status == OrderStatus.pending and settings.payme_enabled:
        out.checkout_url = billing.checkout_url(order, locale)
    return out


@router.get("/status", response_model=BillingStatus)
async def billing_status(
    me: User = Depends(current_user), db: AsyncSession = Depends(get_db)
) -> BillingStatus:
    return BillingStatus(
        payments_enabled=settings.payme_enabled,
        listing_fee_enabled=await billing.listing_fee_enabled(db),
        free_listings_left=me.free_listings_left,
    )


@router.get("/products", response_model=list[ProductOut])
async def list_products(
    kind: ProductKind | None = None,
    locale: str = Depends(resolve_locale),
    db: AsyncSession = Depends(get_db),
) -> list[ProductOut]:
    query = select(Product).where(Product.is_active.is_(True), Product.price_minor > 0)
    if kind is not None:
        query = query.where(Product.kind == kind)
    rows = (await db.scalars(query.order_by(Product.position, Product.code))).all()
    return [product_out(p, locale) for p in rows]


@router.post("/orders", response_model=OrderOut, status_code=status.HTTP_201_CREATED)
async def create_order(
    payload: OrderIn,
    locale: str = Depends(resolve_locale),
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> OrderOut:
    if not settings.payme_enabled:
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE, "To'lov tizimi hali ulanmagan."
        )
    product = await db.get(Product, payload.product_code)
    if product is None or not product.is_active or billing.final_price(product) <= 0:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Tarif topilmadi.")

    listing = None
    if product.kind == ProductKind.boost:
        if payload.listing_id is None:
            raise HTTPException(
                status.HTTP_422_UNPROCESSABLE_ENTITY, "Qaysi e'lonni ko'tarishni tanlang."
            )
        listing = await db.get(Listing, payload.listing_id)
        # Boshqa birovning e'loni ham "topilmadi": kimningdir e'loni borligini
        # bu endpoint orqali bilib bo'lmasin.
        if listing is None or listing.owner_id != me.id:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "E'lon topilmadi.")
        if listing.status not in (ListingStatus.active, ListingStatus.in_negotiation):
            raise HTTPException(
                status.HTTP_409_CONFLICT, "Faqat faol e'lonni ko'tarish mumkin."
            )

    order = billing.new_order(me, product, locale, listing)
    db.add(order)
    await db.commit()
    await db.refresh(order)
    return order_out(order, locale)


@router.get("/orders", response_model=list[OrderOut])
async def my_orders(
    limit: int = Query(default=50, ge=1, le=100),
    locale: str = Depends(resolve_locale),
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> list[OrderOut]:
    rows = (
        await db.scalars(
            select(PaymentOrder)
            .where(PaymentOrder.user_id == me.id)
            .order_by(PaymentOrder.created_at.desc())
            .limit(limit)
        )
    ).all()
    return [order_out(o, locale) for o in rows]


@router.get("/orders/{order_id}", response_model=OrderOut)
async def get_order(
    order_id: uuid.UUID,
    locale: str = Depends(resolve_locale),
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> OrderOut:
    order = await db.get(PaymentOrder, order_id)
    if order is None or order.user_id != me.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Buyurtma topilmadi.")
    return order_out(order, locale)
