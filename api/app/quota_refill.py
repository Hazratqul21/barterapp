"""Har oy bepul e'lonlarni yangilash.

    python -m app.quota_refill [--dry-run]

`users.free_listings_left` — «shu oydagi bepul e'lonlar». Uni hech narsa
yangilamas edi: pullik rejim yoqilsa, odamga umrbod 2 ta e'lon qolardi.
Kunlik tozalash bilan birga ishlaydi, lekin oyiga bir marta ta'sir qiladi:
oxirgi yangilangan oy sozlamalarda saqlanadi.

Sotib olingan e'lonlar yo'qolmaydi: qoldiq oylik miqdordan kam bo'lsagina
oylik miqdorgacha to'ldiriladi.
"""

from __future__ import annotations

import argparse
import asyncio
from datetime import UTC, datetime

from sqlalchemy import func, select, update

from app.db.session import SessionLocal
from app.models.user import User
from app.services import settings_store

#: Har oy beriladigan bepul e'lonlar (`users.free_listings_left` sukuti bilan bir xil).
FREE_PER_MONTH = 2

#: Oxirgi yangilangan oy, "YYYY-MM".
REFILLED_MONTH = "free_listings_month"


async def refill(db, *, now: datetime | None = None, dry_run: bool = False) -> int | None:
    """Shu oy hali yangilanmagan bo'lsa yangilaydi. Yangilanganlar soni yoki None."""
    month = (now or datetime.now(UTC)).strftime("%Y-%m")
    if await settings_store.get(db, REFILLED_MONTH) == month:
        return None

    where = (User.deleted_at.is_(None), User.free_listings_left < FREE_PER_MONTH)
    count = await db.scalar(select(func.count()).select_from(User).where(*where))
    if not dry_run:
        await db.execute(update(User).where(*where).values(free_listings_left=FREE_PER_MONTH))
        await settings_store.put(db, REFILLED_MONTH, month)
        await db.commit()
    return count


async def main(*, dry_run: bool) -> None:
    async with SessionLocal() as db:
        count = await refill(db, dry_run=dry_run)
    prefix = "[quruq yurish] " if dry_run else ""
    if count is None:
        print(f"{prefix}bepul e'lonlar: shu oy allaqachon yangilangan")
    else:
        print(f"{prefix}bepul e'lonlar yangilandi: {count} ta foydalanuvchi")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    asyncio.run(main(dry_run=args.dry_run))
