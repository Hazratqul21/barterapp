"""Moderator huquqini berish yoki olib qo'yish.

    python -m app.grant_moderator +998901234567
    python -m app.grant_moderator ism@gmail.com       # Google bilan kirgan hisob
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
    column = User.email if "@" in phone else User.phone
    value = phone.strip().lower() if "@" in phone else phone
    async with SessionLocal() as db:
        user = await db.scalar(
            select(User).where(column == value, User.deleted_at.is_(None))
        )
        if user is None:
            print(f"Bunday hisob yo'q: {phone}")
            return 1

        user.is_moderator = not revoke
        await db.commit()

        holat = "olib qo'yildi" if revoke else "berildi"
        print(f"{user.full_name} ({phone}) — moderator huquqi {holat}.")
        return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phone", help="+998XXXXXXXXX yoki Google email")
    parser.add_argument(
        "--revoke", action="store_true", help="Huquqni olib qo'yish."
    )
    args = parser.parse_args()

    raise SystemExit(asyncio.run(main(args.phone, revoke=args.revoke)))
