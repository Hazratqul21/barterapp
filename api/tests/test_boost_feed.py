"""Boost: ko'tarilgan e'lon lentaning tepasida, uzoqroq muddatlisi yuqoriroq,
ikki marta ko'rinmaydi, muddati tugagani oddiy. Oylik bepul e'lonlar
yangilanadi, sotib olingani yo'qolmaydi."""

import asyncio
import sys
import uuid
from datetime import UTC, datetime, timedelta
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import select, update  # noqa: E402

from app import quota_refill  # noqa: E402
from app.db.session import SessionLocal, engine  # noqa: E402
from app.models.listing import Listing  # noqa: E402
from app.models.user import User  # noqa: E402
from app.services import settings_store  # noqa: E402

BASE = "http://127.0.0.1:8010"
MARK = f"boost{uuid.uuid4().hex[:8]}"


def check(label: str, ok: bool, extra: str = "") -> None:
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f"  — {extra}" if extra else ""))
    if not ok:
        raise SystemExit(1)


def login(c: httpx.Client, phone: str) -> dict:
    code = c.post("/auth/otp/request", json={"phone": phone}).json()["debug_code"]
    token = c.post("/auth/otp/verify", json={"phone": phone, "code": code}).json()
    return {"Authorization": f"Bearer {token['access_token']}"}


def create(c: httpx.Client, auth: dict, title: str, value: int) -> str:
    tri = lambda s: {"uz": s, "ru": s, "en": s}  # noqa: E731
    body = {
        "tag": "electronics",
        "title": tri(f"{MARK} {title}"),
        "description": tri("Sinov"),
        "image_alt": tri(title),
        "category": tri("Telefon"),
        "condition": tri("Yangi"),
        "quantity": tri("1 dona"),
        "wants_summary": tri("Noutbuk"),
        "value": {"minor": value, "currency": "UZS"},
        "cash_ok": True,
    }
    r = c.post("/listings", json=body, headers=auth)
    check(f"e'lon yaratildi: {title}", r.status_code == 201, r.text[:200])
    return r.json()["id"]


async def boost(plan: dict[str, datetime | None]) -> None:
    async with SessionLocal() as db:
        for listing_id, until in plan.items():
            await db.execute(
                update(Listing)
                .where(Listing.id == uuid.UUID(listing_id))
                .values(is_premium=True, premium_until=until)
            )
        await db.commit()
    # Har asyncio.run o'z event loop'ida: pool keyingisiga o'tmasin.
    await engine.dispose()


def feed(c: httpx.Client, **params) -> list[dict]:
    items, cursor = [], None
    while True:
        query = {"q": MARK, "limit": 2, **params}
        if cursor:
            query["cursor"] = cursor
        page = c.get("/listings", params=query).json()
        items += page["items"]
        cursor = page["next_cursor"]
        if not cursor:
            return items


async def quota_checks(phone_low: str, phone_rich: str) -> None:
    async with SessionLocal() as db:
        await db.execute(update(User).where(User.phone == phone_low).values(free_listings_left=0))
        await db.execute(update(User).where(User.phone == phone_rich).values(free_listings_left=5))
        await settings_store.drop(db, quota_refill.REFILLED_MONTH)
        await db.commit()

        first = await quota_refill.refill(db)
        check("oy boshida bepul e'lonlar yangilandi", first is not None and first >= 1, str(first))
        left = lambda phone: db.scalar(  # noqa: E731
            select(User.free_listings_left).where(User.phone == phone)
        )
        check("0 qolgan odamga 2 ta berildi", await left(phone_low) == quota_refill.FREE_PER_MONTH)
        check("sotib olingan 5 ta yo'qolmadi", await left(phone_rich) == 5)

        await db.execute(update(User).where(User.phone == phone_low).values(free_listings_left=0))
        await db.commit()
        check("shu oy ikkinchi marta yangilanmaydi", await quota_refill.refill(db) is None)
        check("ikkinchi yurishda qoldiq tegilmadi", await left(phone_low) == 0)

        next_month = datetime.now(UTC).replace(day=28) + timedelta(days=5)
        check("keyingi oy yana yangilanadi",
              (await quota_refill.refill(db, now=next_month)) is not None)
        check("keyingi oyda 2 ta bo'ldi", await left(phone_low) == quota_refill.FREE_PER_MONTH)
        await settings_store.drop(db, quota_refill.REFILLED_MONTH)
        await db.commit()
    await engine.dispose()


with httpx.Client(base_url=BASE, timeout=30, headers={"Accept-Language": "uz"}) as c:
    seller = login(c, "+998901110071")
    plain = create(c, seller, "oddiy", 1_000_000_00)
    week = create(c, seller, "hafta", 2_000_000_00)
    day = create(c, seller, "kun", 3_000_000_00)
    expired = create(c, seller, "eskirgan", 4_000_000_00)

    now = datetime.now(UTC)
    asyncio.run(boost({
        week: now + timedelta(days=7),
        day: now + timedelta(days=1),
        expired: now - timedelta(hours=1),
    }))

    items = feed(c)
    ids = [i["id"] for i in items]
    check("hamma e'lon lentada, takrorsiz", sorted(ids) == sorted({plain, week, day, expired}),
          str(len(ids)))
    check("ko'tarilganlar tepada, uzoqroq muddatlisi birinchi", ids[:2] == [week, day])
    check("ko'tarilganlarda Premium belgisi", all(i["is_premium"] for i in items[:2]))
    check("muddati tugagani oddiy",
          not next(i for i in items if i["id"] == expired)["is_premium"])
    check("qolganlari yangi → eski tartibda", ids[2:] == [expired, plain])

    cheap = [i["id"] for i in feed(c, sort="cheap")]
    check("narx bo'yicha tartibda ko'tarish yo'q", cheap == [plain, week, day, expired])

    other = c.get("/listings", params={"q": MARK, "tag": "agri"}).json()["items"]
    check("ko'tarilgan e'lon boshqa kategoriyada chiqmaydi", other == [])

    login(c, "+998901110072")
    asyncio.run(quota_checks("+998901110071", "+998901110072"))
