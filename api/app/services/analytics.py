"""Hodisalardan chiqadigan savollar.

Bu yerdagi har bir so'rov bitta amaliy savolga javob beradi. Ular ataylab
"foydalanuvchilar soni" kabi bezak raqamlar emas — bezak raqam yaxshi
ko'rinadi va hech qanday qarorni o'zgartirmaydi. Bu yerdagilar esa nima
qilish kerakligini aytadi:

- Nima izlanib topilmayapti → bozorda nima yetishmayapti
- Nima ko'rsatilib bosilmayapti → qaysi e'lonlar (yoki qaysi turkumlar) ishlamayapti
- Voronka qayerda uzilyapti → mahsulotning eng zaif bo'g'ini
- Moslik rad etilyaptimi → matching algoritmi haqiqatan ishlayaptimi

Oxirgisi ertaga modelni baholashning asosiy o'lchovi bo'ladi.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from sqlalchemy import Integer, case, cast, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.event import Event, EventKind


def _since(days: int) -> datetime:
    return datetime.now(UTC) - timedelta(days=days)


async def empty_searches(
    db: AsyncSession, *, days: int = 30, limit: int = 50
) -> list[dict]:
    """
    Odamlar izlab topa olmagan narsalar.

    Mahsulot uchun eng qimmatli ro'yxat: har bir satr — kimdir kelgan, aniq
    nima kerakligini yozgan va quruq ketgan holat. Boshqa hech qanday
    manba buni ko'rsatmaydi, chunki bu **sodir bo'lmagan** narsa.
    """
    term = Event.payload["q"].astext
    rows = await db.execute(
        select(
            term.label("q"),
            func.count().label("times"),
            func.count(func.distinct(Event.user_id)).label("people"),
            func.max(Event.occurred_at).label("last_seen"),
        )
        .where(
            Event.kind == EventKind.search_empty.value,
            Event.occurred_at >= _since(days),
            term.isnot(None),
        )
        .group_by(term)
        .order_by(func.count().desc())
        .limit(limit)
    )
    return [
        {
            "q": r.q,
            "times": r.times,
            "people": r.people,
            "last_seen": r.last_seen,
        }
        for r in rows
    ]


async def funnel(db: AsyncSession, *, days: int = 30) -> dict:
    """
    Ko'rsatildi → ochildi → saqlandi → taklif → savdo.

    Bosqichlar orasidagi eng katta tushish — mahsulotning eng zaif bo'g'ini.
    Bu raqamlarsiz jamoa har doim eng ko'zga tashlangan joyni tuzatadi, eng
    ko'p yo'qotayotgan joyni emas.
    """
    stages = [
        ("impressions", EventKind.listing_impression),
        ("views", EventKind.listing_view),
        ("favorites", EventKind.favorite_add),
        ("offers", EventKind.offer_sent),
        ("accepted", EventKind.offer_accepted),
        ("completed", EventKind.trade_completed),
    ]

    rows = await db.execute(
        select(Event.kind, func.count().label("n"))
        .where(
            Event.kind.in_([k.value for _, k in stages]),
            Event.occurred_at >= _since(days),
        )
        .group_by(Event.kind)
    )
    counts = {kind: n for kind, n in rows}

    result: dict = {"days": days}
    previous: int | None = None
    for name, kind in stages:
        n = counts.get(kind.value, 0)
        result[name] = n
        # Har bosqichning o'tish foizi — mutlaq son emas, aynan shu nisbat
        # qayerda yo'qotayotganimizni ko'rsatadi.
        if previous is not None:
            result[f"{name}_rate"] = round(n / previous * 100, 1) if previous else None
        previous = n
    return result


async def cold_listings(
    db: AsyncSession, *, days: int = 30, min_impressions: int = 20, limit: int = 50
) -> list[dict]:
    """
    Ko'p ko'rsatilgan, lekin hech kim ochmagan e'lonlar.

    Sababi odatda uchtadan biri: surat yomon, narx haqiqatga to'g'ri
    kelmaydi, yoki sarlavha nima sotilayotganini aytmaydi. Uchalasi ham
    tuzatiladigan narsa — lekin faqat qaysi e'lon ekanini bilsak.

    `min_impressions` bo'sag'asi bor, chunki uch marta ko'rsatilib
    bosilmagan e'lon haqida hech narsa deyib bo'lmaydi — bu shovqin.
    """
    shown = (
        select(
            Event.target_id.label("listing_id"),
            func.count().label("impressions"),
        )
        .where(
            Event.kind == EventKind.listing_impression.value,
            Event.target_type == "listing",
            Event.occurred_at >= _since(days),
        )
        .group_by(Event.target_id)
        .having(func.count() >= min_impressions)
        .subquery()
    )

    opened = (
        select(
            Event.target_id.label("listing_id"),
            func.count().label("views"),
        )
        .where(
            Event.kind == EventKind.listing_view.value,
            Event.target_type == "listing",
            Event.occurred_at >= _since(days),
        )
        .group_by(Event.target_id)
        .subquery()
    )

    rows = await db.execute(
        select(
            shown.c.listing_id,
            shown.c.impressions,
            func.coalesce(opened.c.views, 0).label("views"),
        )
        .select_from(shown)
        .outerjoin(opened, opened.c.listing_id == shown.c.listing_id)
        .order_by(
            (
                cast(func.coalesce(opened.c.views, 0), Integer)
                * 1000
                / shown.c.impressions
            ).asc(),
            shown.c.impressions.desc(),
        )
        .limit(limit)
    )

    return [
        {
            "listing_id": str(r.listing_id),
            "impressions": r.impressions,
            "views": r.views,
            "ctr": round(r.views / r.impressions * 100, 2) if r.impressions else 0.0,
        }
        for r in rows
    ]


async def match_quality(db: AsyncSession, *, days: int = 30) -> dict:
    """
    Ko'rsatilgan mosliklardan nechtasi ish berdi.

    Ertaga matching modelini baholaydigan asosiy o'lchov shu. Hozirgi
    algoritm qo'lda yozilgan ball (masofa 30%, reyting 20% va hokazo) —
    u yaxshimi yoki yomonmi degan savolga bugungacha **javob yo'q edi**,
    chunki natijasi hech qayerda o'lchanmasdi.
    """
    kinds = [
        EventKind.match_shown,
        EventKind.match_opened,
        EventKind.match_dismissed,
    ]
    rows = await db.execute(
        select(Event.kind, func.count().label("n"))
        .where(
            Event.kind.in_([k.value for k in kinds]),
            Event.occurred_at >= _since(days),
        )
        .group_by(Event.kind)
    )
    counts = {kind: n for kind, n in rows}

    shown = counts.get(EventKind.match_shown.value, 0)
    opened = counts.get(EventKind.match_opened.value, 0)
    dismissed = counts.get(EventKind.match_dismissed.value, 0)

    return {
        "days": days,
        "shown": shown,
        "opened": opened,
        "dismissed": dismissed,
        "open_rate": round(opened / shown * 100, 1) if shown else None,
        "dismiss_rate": round(dismissed / shown * 100, 1) if shown else None,
    }


async def search_gaps(
    db: AsyncSession, *, days: int = 30, limit: int = 20
) -> list[dict]:
    """
    Turkum bo'yicha qidiruvning natijasizlik ulushi.

    Bitta so'z emas, butun turkum quruq qaytarayotgan bo'lsa — bu bitta
    e'lonning muammosi emas, bozorning bir tomoni bo'shligi. Qaysi tomonga
    e'lon jalb qilish kerakligini aynan shu ko'rsatadi.
    """
    tag = Event.payload["tag"].astext
    rows = await db.execute(
        select(
            tag.label("tag"),
            func.count().label("searches"),
            func.sum(
                case((Event.kind == EventKind.search_empty.value, 1), else_=0)
            ).label("empty"),
        )
        .where(
            Event.kind.in_(
                [EventKind.search.value, EventKind.search_empty.value]
            ),
            Event.occurred_at >= _since(days),
            tag.isnot(None),
        )
        .group_by(tag)
        .order_by(func.count().desc())
        .limit(limit)
    )
    return [
        {
            "tag": r.tag,
            "searches": r.searches,
            "empty": int(r.empty or 0),
            "empty_rate": round((r.empty or 0) / r.searches * 100, 1)
            if r.searches
            else 0.0,
        }
        for r in rows
    ]
