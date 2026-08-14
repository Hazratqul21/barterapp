"""Eski hodisalarni tozalash.

    python -m app.events_prune [--days 180] [--dry-run]

Bu jadval boshqalardan yuz barobar tez o'sadi: bitta odam bitta o'tirishda
yuzlab ko'rsatish hodisasi qoldiradi. Cheklovsiz u bir yilda bazaning eng
katta qismiga aylanadi va zaxira nusxa olishni ham, so'rovlarni ham
sekinlashtiradi.

Muddat ataylab uzun (180 kun). Mavsumiylik — barterda kuchli omil: kuzda
kerak bo'lgan narsa bahorda kerak emas, va buni ko'rish uchun kamida bir
yillik siklning yarmi kerak. Undan eskisi esa model uchun ham foydasiz,
chunki bozorning o'zi o'zgargan bo'ladi.
"""

from __future__ import annotations

import argparse
import asyncio
from datetime import UTC, datetime, timedelta

from sqlalchemy import delete, func, select

from app.db.session import SessionLocal
from app.models.event import Event

DEFAULT_DAYS = 180


async def main(*, days: int, dry_run: bool) -> None:
    cutoff = datetime.now(UTC) - timedelta(days=days)

    async with SessionLocal() as db:
        doomed = await db.scalar(
            select(func.count()).select_from(Event).where(Event.occurred_at < cutoff)
        )
        total = await db.scalar(select(func.count()).select_from(Event))

        if not dry_run and doomed:
            await db.execute(delete(Event).where(Event.occurred_at < cutoff))
            await db.commit()

    print(
        f"{'[quruq yurish] ' if dry_run else ''}"
        f"{cutoff:%Y-%m-%d} dan eski: {doomed} ta · "
        f"jami: {total} ta"
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--days", type=int, default=DEFAULT_DAYS)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Nechtasi o'chishini ko'rsatadi, lekin o'chirmaydi.",
    )
    args = parser.parse_args()

    asyncio.run(main(days=args.days, dry_run=args.dry_run))
