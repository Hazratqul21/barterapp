from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter, Depends, status
from pydantic import Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import current_user
from app.db.session import get_db
from app.models.device import Device, DevicePlatform
from app.models.user import User
from app.schemas.common import ApiModel

router = APIRouter(tags=["devices"])


class DeviceIn(ApiModel):
    token: str = Field(min_length=8, max_length=500)
    platform: DevicePlatform
    locale: str = Field(default="uz", pattern="^(uz|ru|en)$")


@router.post("/devices", status_code=status.HTTP_204_NO_CONTENT)
async def register_device(
    payload: DeviceIn,
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    """
    Register (or refresh) this installation for push.

    Safe to call on every launch — that is what keeps `last_seen_at` current,
    and it is the only way the server learns a token was rotated.

    A token already on file is *reassigned* rather than rejected. The same
    phone can be handed to somebody else, and without this the new owner's
    notifications would keep going to the previous account.
    """
    now = datetime.now(UTC)
    existing = await db.scalar(select(Device).where(Device.token == payload.token))

    if existing is not None:
        existing.user_id = me.id
        existing.platform = payload.platform
        existing.locale = payload.locale
        existing.last_seen_at = now
    else:
        db.add(
            Device(
                user_id=me.id,
                token=payload.token,
                platform=payload.platform,
                locale=payload.locale,
                last_seen_at=now,
            )
        )

    await db.commit()


@router.delete("/devices/{token}", status_code=status.HTTP_204_NO_CONTENT)
async def unregister_device(
    token: str,
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    """
    Stop pushing to this installation — sign-out, or notifications turned off.

    Only your own device is removed. Idempotent: an unknown token is not an
    error, because the client calls this while signing out and has no way to
    retry a failure.
    """
    existing = await db.scalar(
        select(Device).where(Device.token == token, Device.user_id == me.id)
    )
    if existing is not None:
        await db.delete(existing)
        await db.commit()
