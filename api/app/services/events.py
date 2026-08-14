"""Hodisalarni yozish.

Ikkita qoida butun modulni belgilaydi:

1. **Hodisa yozish asosiy amalni yiqitmasin.** Taklif yuborildi-yu, tahlil
   qatori yozilmadi — bu kichik yo'qotish. Tahlil qatori yozilmagani uchun
   taklif yuborilmadi — bu falokat. Shu sababli server tomonidagi yozuv
   xatoni yutadi va logga qoldiradi.

2. **Takroriy yuborish sonlarni buzmasin.** Tarmoq uzilganda mijoz paketni
   qayta yuboradi. `dedupe_key` bo'yicha `ON CONFLICT DO NOTHING` —
   usiz ko'rsatishlar ikki marta sanalib, CTR jimgina ikki barobar
   pasayardi. Bu eng yomon xato turi: raqamlar bor, lekin ular yolg'on.
"""

from __future__ import annotations

import logging
import uuid
from datetime import UTC, datetime

from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.event import Event, EventKind

log = logging.getLogger("barter.events")

#: Bir paketda nechta hodisa. Lentaning bir sahifasi 20 ta ko'rsatish beradi,
#: shuning uchun 100 — bir necha sahifalik aylanish, lekin so'rovni
#: cheksiz kattalashtirmaydi.
MAX_BATCH = 100


def row(
    kind: EventKind,
    *,
    user_id: uuid.UUID | None = None,
    session_id: str | None = None,
    target_type: str | None = None,
    target_id: uuid.UUID | None = None,
    payload: dict | None = None,
    locale: str | None = None,
    platform: str | None = None,
    dedupe_key: str | None = None,
    occurred_at: datetime | None = None,
) -> dict:
    """Bitta hodisani lug'at ko'rinishida — to'plamli qo'yish uchun."""
    return {
        "kind": kind.value,
        "user_id": user_id,
        "session_id": session_id,
        "target_type": target_type,
        "target_id": target_id,
        "payload": payload or {},
        "locale": locale,
        "platform": platform,
        "dedupe_key": dedupe_key,
        "occurred_at": occurred_at or datetime.now(UTC),
    }


async def write(db: AsyncSession, rows: list[dict]) -> int:
    """
    Yozadi va nechtasi haqiqatan qo'shilganini qaytaradi.

    Takrorlar jimgina tashlanadi — mijoz uchun bu xato emas, muvaffaqiyatli
    qayta yuborish. Qaytgan son esa tahlil uchun: agar u doim yuborilgandan
    kam bo'lsa, mijoz keraksiz takrorlayapti degani.
    """
    if not rows:
        return 0

    statement = insert(Event).values(rows)
    # Faqat `dedupe_key` bo'yicha. Kalitsiz hodisalar (server tomonidagilar)
    # hech qachon to'qnashmaydi, chunki NULL o'zi bilan teng emas.
    statement = statement.on_conflict_do_nothing(index_elements=["dedupe_key"])

    result = await db.execute(statement)
    return result.rowcount or 0


async def record(db: AsyncSession, kind: EventKind, **fields) -> None:
    """
    Server tomonidagi bitta hodisa.

    Ataylab commit qilmaydi: hodisa uni keltirib chiqargan o'zgarish bilan
    **bir tranzaksiyada** yozilsin. Aks holda qaytarilgan savdo tahlilda
    bo'lgan bo'lib qolardi va voronka hech qachon to'g'ri chiqmasdi.

    SAVEPOINT ichida, chunki PostgreSQL'da yiqilgan buyruq butun tranzaksiyani
    zaharlaydi: oddiy `try/except` xatoni ushlagan bo'lardi-yu, keyingi
    `commit()` baribir yiqilardi — ya'ni tahlil qatori tufayli savdoning o'zi
    yo'qolardi. Ichki nuqta faqat shu qo'yishni qaytaradi va asosiy amal
    o'z yo'lida davom etadi.
    """
    try:
        async with db.begin_nested():
            await write(db, [row(kind, **fields)])
    except Exception:
        # Birinchi qoida: tahlil asosiy amalni yiqitmaydi.
        log.exception("hodisa yozilmadi: %s", kind.value)
