from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter, Depends, status
from pydantic import Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from fastapi import HTTPException, status as http_status

from app.core.security import current_user
from app.db.session import get_db
from app.models.device import Device, DevicePlatform
from app.models.notify_pref import NotificationSetting
from app.models.user import User
from app.schemas.common import ApiModel

router = APIRouter(tags=["devices"])


class DeviceIn(ApiModel):
    token: str = Field(min_length=8, max_length=500)
    platform: DevicePlatform
    locale: str = Field(default="uz", pattern="^(uz|ru|en)$")


class NotificationSettingOut(ApiModel):
    offers: bool
    matches: bool
    messages: bool
    system: bool
    quiet_from: int | None
    quiet_to: int | None


class NotificationSettingIn(ApiModel):
    offers: bool | None = None
    matches: bool | None = None
    messages: bool | None = None
    system: bool | None = None
    quiet_from: int | None = Field(default=None, ge=0, le=23)
    quiet_to: int | None = Field(default=None, ge=0, le=23)


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


DEFAULTS = NotificationSettingOut(
    offers=True,
    matches=True,
    messages=True,
    system=True,
    quiet_from=None,
    quiet_to=None,
)


@router.get("/notification-settings", response_model=NotificationSettingOut)
async def read_notification_settings(
    me: User = Depends(current_user), db: AsyncSession = Depends(get_db)
) -> NotificationSettingOut:
    """
    What this account agrees to be pushed about.

    An account that never touched the screen has no row; the defaults are
    returned rather than 404, so the client renders the same toggles either
    way and does not have to know the difference.
    """
    row = await db.scalar(
        select(NotificationSetting).where(NotificationSetting.user_id == me.id)
    )
    if row is None:
        return DEFAULTS

    return NotificationSettingOut(
        offers=row.offers,
        matches=row.matches,
        messages=row.messages,
        system=row.system,
        quiet_from=row.quiet_from,
        quiet_to=row.quiet_to,
    )


@router.patch("/notification-settings", response_model=NotificationSettingOut)
async def update_notification_settings(
    payload: NotificationSettingIn,
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> NotificationSettingOut:
    """
    Change some of them. Only the fields actually sent are touched.

    ⚠️ These govern the **push** only. The notification is still written and
    still appears in the in-app list — switching "matches" off means "stop
    buzzing my phone", not "hide these from me". Conflating the two is how
    somebody misses an offer they never asked to hide.
    """
    fields = payload.model_dump(exclude_unset=True)

    row = await db.scalar(
        select(NotificationSetting).where(NotificationSetting.user_id == me.id)
    )
    if row is None:
        row = NotificationSetting(user_id=me.id)
        db.add(row)

    for field_name, value in fields.items():
        setattr(row, field_name, value)

    # Yarim to'ldirilgan oraliq sozlama emas, xato: "22 dan" deb yozib
    # "nechagacha" ni aytmaslik kechasi bilan jimlikni ham, jimlikning
    # yo'qligini ham anglatmaydi. Bazada ham cheklov bor; bu yerda esa
    # foydalanuvchi o'qiydigan javob qaytariladi.
    if (row.quiet_from is None) != (row.quiet_to is None):
        raise HTTPException(
            http_status.HTTP_400_BAD_REQUEST,
            "Sokin soatlarning boshi ham, oxiri ham ko'rsatilishi kerak.",
        )

    await db.commit()
    await db.refresh(row)

    return NotificationSettingOut(
        offers=row.offers,
        matches=row.matches,
        messages=row.messages,
        system=row.system,
        quiet_from=row.quiet_from,
        quiet_to=row.quiet_to,
    )
