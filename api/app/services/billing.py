"""Narx, chegirma, buyurtma va to'lov natijasini qo'llash.

Payme'ga bog'liq bo'lmagan hamma narsa shu yerda: keyin Click yoki Uzum
qo'shilganda ular ham `fulfil` va `checkout_url` ga o'xshash funksiyalarni
chaqiradi, narx mantiqi esa bitta joyda qoladi.
"""

from __future__ import annotations

from sqlalchemy import update

import base64
import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.listing import Listing
from app.models.payment import OrderStatus, PaymentOrder, Product, ProductKind
from app.models.user import User
from app.services import settings_store

#: Admin paneldagi kalit: "true" bo'lsa bepul kvota tugaganda e'lon pullik.
#: Sukut bo'yicha o'chiq — narxlar belgilanmaguncha hech kim to'lovga
#: yo'naltirilmasin.
LISTING_FEE_ENABLED = "listing_fee_enabled"


def final_price(product: Product, now: datetime | None = None) -> int:
    """Chegirmadan keyingi narx, butun so'mgacha yaxlitlangan (tiyinda)."""
    now = now or datetime.now(UTC)
    percent = product.discount_percent
    if percent and (product.discount_until is None or product.discount_until > now):
        discounted = product.price_minor * (100 - percent) // 100
        return discounted - discounted % 100
    return product.price_minor


def discount_active(product: Product, now: datetime | None = None) -> bool:
    return final_price(product, now) != product.price_minor


def title_for(product: Product, locale: str) -> str:
    title = product.title or {}
    return title.get(locale) or title.get("uz") or next(iter(title.values()), product.code)


async def listing_fee_enabled(db: AsyncSession) -> bool:
    return (await settings_store.get(db, LISTING_FEE_ENABLED)) == "true"


def checkout_url(order: PaymentOrder, locale: str = "uz") -> str:
    """
    Payme to'lov sahifasi. Karta raqami, muddati va SMS kod shu sahifada
    kiritiladi — ular bizning serverga umuman kelmaydi.
    """
    return_url = settings.payme_return_url.replace("{order_id}", str(order.id))
    params = ";".join(
        [
            f"m={settings.payme_merchant_id}",
            f"ac.order_id={order.id}",
            f"a={order.amount_minor}",
            f"l={locale if locale in ('uz', 'ru', 'en') else 'uz'}",
            f"c={return_url}",
        ]
    )
    encoded = base64.b64encode(params.encode()).decode()
    return f"{settings.payme_checkout_url.rstrip('/')}/{encoded}"


def new_order(
    user: User, product: Product, locale: str, listing: Listing | None = None
) -> PaymentOrder:
    return PaymentOrder(
        id=uuid.uuid4(),
        user_id=user.id,
        product_code=product.code,
        kind=product.kind,
        listing_id=listing.id if listing else None,
        quantity=product.quantity,
        duration_days=product.duration_days,
        amount_minor=final_price(product),
        title=title_for(product, locale)[:200],
        status=OrderStatus.pending,
    )


async def fulfil(db: AsyncSession, order: PaymentOrder) -> None:
    """
    To'langan buyurtmani qo'llaydi. Chaqiruvchi tranzaksiyani commit qiladi —
    to'lov holati va uning natijasi bitta tranzaksiyada saqlansin.
    """
    now = datetime.now(UTC)
    order.status = OrderStatus.paid
    order.paid_at = now

    if order.kind == ProductKind.listing_pack and order.user_id:
        # One statement, so a listing published at the same moment (which
        # spends a credit the same way) cannot overwrite the purchase.
        await db.execute(
            update(User)
            .where(User.id == order.user_id)
            .values(free_listings_left=User.free_listings_left + order.quantity)
        )

    elif order.kind == ProductKind.boost and order.listing_id:
        listing = await db.get(Listing, order.listing_id, with_for_update=True)
        if listing is not None:
            # Muddat ustiga qo'shiladi: hali tugamagan boost'ni qayta sotib
            # olgan odam qolgan kunlarini yo'qotmasin.
            start = listing.premium_until if (
                listing.premium_until and listing.premium_until > now
            ) else now
            listing.is_premium = True
            listing.premium_until = start + timedelta(days=order.duration_days or 1)


def premium_now(listing: Listing, now: datetime | None = None) -> bool:
    """Boost muddati tugagan e'lon premium bo'lib ko'rinmasin."""
    if not listing.is_premium:
        return False
    if listing.premium_until is None:
        return True
    return listing.premium_until > (now or datetime.now(UTC))
