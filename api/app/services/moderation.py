"""Bloklashning kuchga kirishi.

Bir joyda saqlanadi, chunki blok lentada, taklifda va chatda — uchalasida ham
amal qilishi shart. Faqat bittasida tekshirilsa, blok tugmasi bezakka
aylanadi: odam lentadan yo'qoladi-yu, xabar yozishda davom etadi.
"""

from __future__ import annotations

import uuid

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.moderation import Block


async def blocked_ids(db: AsyncSession, user_id: uuid.UUID) -> set[uuid.UUID]:
    """
    Everyone this account must not see, in either direction.

    Both directions on purpose. If only `blocker_id` counted, the blocked side
    would keep seeing the other person's listings and keep opening chats — the
    one outcome the button exists to prevent. So a block hides the pair from
    each other, while only the person who set it can lift it.
    """
    rows = await db.execute(
        select(Block.blocker_id, Block.blocked_id).where(
            or_(Block.blocker_id == user_id, Block.blocked_id == user_id)
        )
    )
    return {
        other
        for blocker, blocked in rows
        for other in (blocker, blocked)
        if other != user_id
    }


async def is_blocked(
    db: AsyncSession, a: uuid.UUID, b: uuid.UUID
) -> bool:
    """Whether these two are barred from dealing with each other, either way."""
    if a == b:
        return False
    found = await db.scalar(
        select(Block.id)
        .where(
            or_(
                (Block.blocker_id == a) & (Block.blocked_id == b),
                (Block.blocker_id == b) & (Block.blocked_id == a),
            )
        )
        .limit(1)
    )
    return found is not None
