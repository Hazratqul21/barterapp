"""Eskirgan kirish kodlari va sessiyalarni tozalash.

    python -m app.auth_prune [--dry-run]

`otp_challenges` va `refresh_tokens` har kirishda o'sadi va o'zi hech
qachon kamaymaydi. Kod bir kundan keyin kerak emas — kunlik noto'g'ri
urinishlar chegarasi (`auth.MAX_FAILED_PER_DAY`) shu oxirgi bir kunga
qaraydi. Muddati o'tgan yoki bekor qilingan sessiya ham bir haftadan
keyin hech narsaga kerak emas: qayta ishlatish aniqlanishi faqat tirik
sessiyalar oilasiga tegishli.
"""

from __future__ import annotations

import argparse
import asyncio
from datetime import UTC, datetime, timedelta

from sqlalchemy import delete, func, or_, select

from app.db.session import SessionLocal
from app.models.user import OtpChallenge, RefreshToken


async def main(*, dry_run: bool) -> None:
    now = datetime.now(UTC)
    otp_cutoff = now - timedelta(days=2)
    token_cutoff = now - timedelta(days=7)
    otp_where = OtpChallenge.created_at < otp_cutoff
    token_where = or_(
        RefreshToken.expires_at < token_cutoff,
        RefreshToken.revoked_at < token_cutoff,
    )

    async with SessionLocal() as db:
        otps = await db.scalar(select(func.count()).select_from(OtpChallenge).where(otp_where))
        tokens = await db.scalar(select(func.count()).select_from(RefreshToken).where(token_where))
        if not dry_run:
            await db.execute(delete(OtpChallenge).where(otp_where))
            await db.execute(delete(RefreshToken).where(token_where))
            await db.commit()

    print(f"{'[quruq yurish] ' if dry_run else ''}kodlar: {otps} ta · sessiyalar: {tokens} ta")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    asyncio.run(main(dry_run=args.dry_run))
