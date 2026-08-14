"""Moderator huquqini berish yoki olib qo'yish.

    python -m app.grant_moderator +998901234567
    python -m app.grant_moderator +998901234567 --revoke

Ataylab CLI, endpoint emas. Hisobni moderatorga aylantira oladigan API —
noto'g'ri hisobni moderatorga aylantirishga aldash mumkin bo'lgan API; bu
bayroqning butun ma'nosi esa uni o'z-o'ziga bera olmaslikda.
"""

from __future__ import annotations

import argparse
import asyncio

from sqlalchemy import select

from app.db.session import SessionLocal
from app.models.user import User


async def main(phone: str, *, revoke: bool) -> int:
    async with SessionLocal() as db:
        user = await db.scalar(select(User).where(User.phone == phone))
        if user is None:
            print(f"Bunday raqamli hisob yo'q: {phone}")
            return 1

        user.is_moderator = not revoke
        await db.commit()

        holat = "olib qo'yildi" if revoke else "berildi"
        print(f"{user.full_name} ({phone}) — moderator huquqi {holat}.")
        return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phone", help="+998XXXXXXXXX")
    parser.add_argument(
        "--revoke", action="store_true", help="Huquqni olib qo'yish."
    )
    args = parser.parse_args()

    raise SystemExit(asyncio.run(main(args.phone, revoke=args.revoke)))
