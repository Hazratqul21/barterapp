"""Ishlab turgan serverda o'zgartiriladigan sozlamalar.

Maxfiy qiymat yozilishi mumkin, o'qilishi mumkin emas. Panelga kirish
huquqi bo'lgan hisob — yoki o'g'irlangan sessiya — kalitni ko'chirib olib
keta olmasin. Almashtirish uchun yozish yetarli.
"""

from __future__ import annotations

import hashlib

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.setting import AppSetting

#: Firebase service account JSON (server tomon — xabar yuborish uchun).
FCM_SERVICE_ACCOUNT = "fcm_service_account"

#: Mijoz tomoni uchun Firebase parametrlari. Maxfiy emas — ular baribir
#: ilova ichida bo'ladi va Google hujjatlari ham ularni ochiq deb ataydi.
FIREBASE_CLIENT = "firebase_client"

SECRET_KEYS = {FCM_SERVICE_ACCOUNT}


async def get(db: AsyncSession, key: str) -> str | None:
    return await db.scalar(select(AppSetting.value).where(AppSetting.key == key))


async def put(db: AsyncSession, key: str, value: str) -> None:
    statement = (
        insert(AppSetting)
        .values(key=key, value=value, is_secret=key in SECRET_KEYS)
        .on_conflict_do_update(index_elements=["key"], set_={"value": value})
    )
    await db.execute(statement)


async def drop(db: AsyncSession, key: str) -> None:
    row = await db.get(AppSetting, key)
    if row is not None:
        await db.delete(row)


def fingerprint(value: str) -> str:
    """
    Qiymatning o'zi emas, uning izi.

    Panelda ko'rsatiladi: odam qaysi kalit turganini ajrata olsin, lekin
    kalitning o'zi hech qayerga chiqmasin.
    """
    return hashlib.sha256(value.encode()).hexdigest()[:12]
