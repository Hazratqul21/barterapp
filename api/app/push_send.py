"""Yuborilmagan bildirishnomalarni push qilish.

    python -m app.push_send [--dry-run] [--limit N]

Doimiy ishlashi uchun cron yoki systemd timer'ga qo'yiladi, masalan har
daqiqada. Ikki nusxa bir vaqtda yurса ham xavfsiz: har biri o'z paketini
oladi va commit qilingandan keyingina `pushed_at` yoziladi.
"""

from __future__ import annotations

import argparse
import asyncio
import logging

from app.db.session import SessionLocal
from app.services.push import BATCH, deliver_pending, transport_for


async def main(*, dry_run: bool, limit: int) -> None:
    async with SessionLocal() as db:
        transport = await transport_for(db)
        report = await deliver_pending(
            db, transport=transport, limit=limit, dry_run=dry_run
        )

    print(
        f"{'[quruq yurish] ' if dry_run else ''}"
        f"yuborildi: {report.sent} · "
        f"qurilmasiz: {report.skipped} · "
        f"muvaffaqiyatsiz: {report.failed} · "
        f"xabarlar: {len(report.messages)}"
    )


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(message)s")

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Nima yuborilishini ko'rsatadi, lekin hech narsani belgilamaydi.",
    )
    parser.add_argument("--limit", type=int, default=BATCH)
    args = parser.parse_args()

    asyncio.run(main(dry_run=args.dry_run, limit=args.limit))
