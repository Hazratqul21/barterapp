"""Moderator huquqini berish yoki olib qo'yish.

    python -m app.grant_moderator +998901234567
    python -m app.grant_moderator ism@gmail.com       # Google bilan kirgan hisob
    python -m app.grant_moderator +998901234567 --revoke
    python -m app.grant_moderator +998901234567 --create --password 'parol'

`--create` — hisob hali yo'q bo'lsa, shu raqam bilan ochadi (SMS hali
ishlamaganda admin panelga kirish uchun). `--password` — parol qo'yadi yoki
almashtiradi; admin panelda «Parol bilan kirish» shu parol bilan ishlaydi.

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
from app.services.login_credentials import hash_password


async def main(
    phone: str, *, revoke: bool, create: bool = False, password: str | None = None
) -> int:
    column = User.email if "@" in phone else User.phone
    value = phone.strip().lower() if "@" in phone else phone
    async with SessionLocal() as db:
        user = await db.scalar(
            select(User).where(column == value, User.deleted_at.is_(None))
        )
        if user is None and create and "@" not in phone and not revoke:
            user = User(phone=value, first_name="Admin", last_name="MAB")
            db.add(user)
            print(f"Yangi hisob ochildi: {phone}")
        if user is None:
            print(f"Bunday hisob yo'q: {phone}  (ochish uchun: --create)")
            return 1

        user.is_moderator = not revoke
        if password:
            if len(password) < 8:
                print("DIQQAT: parol 8 belgidan qisqa — tezroq almashtiring.")
            user.password_hash = await hash_password(password)
        await db.commit()

        holat = "olib qo'yildi" if revoke else "berildi"
        print(f"{user.full_name} ({phone}) — moderator huquqi {holat}."
              + (" Parol o'rnatildi." if password else ""))
        return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phone", help="+998XXXXXXXXX yoki Google email")
    parser.add_argument(
        "--revoke", action="store_true", help="Huquqni olib qo'yish."
    )
    parser.add_argument(
        "--create", action="store_true", help="Hisob yo'q bo'lsa, ochish."
    )
    parser.add_argument("--password", help="Parol qo'yish yoki almashtirish.")
    args = parser.parse_args()

    raise SystemExit(
        asyncio.run(
            main(args.phone, revoke=args.revoke, create=args.create, password=args.password)
        )
    )
