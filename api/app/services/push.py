"""Push-bildirishnomani yetkazish.

Naqsh — outbox. `notifications` jadvalining o'zi navbat vazifasini bajaradi:
`pushed_at IS NULL` bo'lgan qator hali yuborilmagan degani.

Nega aynan shunday. Bildirishnoma savdo o'zgarishi bilan **bir tranzaksiyada**
yoziladi. Agar push to'g'ridan-to'g'ri `notify()` ichidan yuborilsa, keyin
tranzaksiya qaytarilsa (masalan, taklif yaratishda xato chiqsa), odam
bo'lmagan savdo haqida xabar olardi — va ilovani ochib hech narsa topmasdi.
Outbox bunga yo'l qo'ymaydi: xabar faqat commit bo'lgan qatordan chiqadi.

Ikkinchi foyda: yuborish o'rtasida server yiqilsa, qator `pushed_at IS NULL`
bo'lib qoladi va keyingi yurishda qayta uriniladi. Yo'qolgan bildirishnoma
o'rniga takroriy urinish — bu ancha yaxshi ayirboshlash.
"""

from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass, field
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.device import Device
from app.models.notify_pref import NotificationSetting
from app.models.social import Notification, NotifyKind

log = logging.getLogger("barter.push")

#: Bir yurishda nechta bildirishnoma olinadi. Kichik, chunki har biri tashqi
#: xizmatga chiqadi va uzoq ushlab turilgan tranzaksiya hech kimga foyda emas.
BATCH = 100

#: O'zbekiston yagona vaqt mintaqasida (UTC+5). Sokin soatlar mahalliy soat
#: bo'yicha o'lchanadi — "ertalab 8 gacha bezovta qilma" degan qoida sanaga
#: emas, soatga tegishli.
TASHKENT_OFFSET_HOURS = 5

#: Sokin soatlar tugashini kutayotgan xabar shu muddatdan oshsa, umuman
#: yuborilmaydi. Ertalab uyg'onib kechagi "yangi taklif" xabarini olish —
#: xabar emas, shovqin; taklifning o'zi 48 soatda eskiradi.
MAX_HOLD_HOURS = 12

#: `NotifyKind` va sozlamadagi ustun nomi.
_KIND_FIELD = {
    NotifyKind.offer: "offers",
    NotifyKind.match: "matches",
    NotifyKind.message: "messages",
    NotifyKind.system: "system",
}


def in_quiet_hours(setting: NotificationSetting | None, now: datetime) -> bool:
    """
    Whether the phone should stay silent at this moment.

    The window may wrap midnight — 22:00 to 07:00 is the ordinary case, and it
    is the one a plain `start <= hour < end` comparison gets exactly backwards,
    silencing the whole day instead of the night.
    """
    if setting is None or setting.quiet_from is None or setting.quiet_to is None:
        return False

    hour = (now.astimezone(UTC).hour + TASHKENT_OFFSET_HOURS) % 24
    start, end = setting.quiet_from, setting.quiet_to

    if start == end:
        return False
    if start < end:
        return start <= hour < end
    return hour >= start or hour < end


def wants_push(setting: NotificationSetting | None, kind: NotifyKind) -> bool:
    """Absent row means everything on — see `NotificationSetting`."""
    if setting is None:
        return True
    return bool(getattr(setting, _KIND_FIELD[kind], True))


@dataclass
class PushMessage:
    """Bitta qurilmaga ketadigan xabar — transportdan mustaqil shakl."""

    token: str
    platform: str
    title: str
    body: str
    #: Ilova qayerga o'tishi kerakligi. Mijoz shu ikkitasiga qarab yo'naltiradi.
    target_type: str
    target_id: str | None
    notification_id: str


@dataclass
class SendReport:
    sent: int = 0
    #: Qurilmasi yo'q foydalanuvchiga tegishli bildirishnomalar. Ular ham
    #: `pushed_at` oladi — aks holda navbatda abadiy qolib, har yurishda
    #: qaytadan ko'rib chiqiladi.
    skipped: int = 0
    #: Foydalanuvchi bu turdagi pushni o'chirib qo'ygan. Qator `pushed_at`
    #: oladi: bu kutish emas, rad javobi.
    muted: int = 0
    #: Sokin soatlar tugashini kutmoqda. Belgilanmaydi — keyingi yurishda
    #: qaytadan ko'riladi va vaqti kelganda yuboriladi.
    held: int = 0
    failed: int = 0
    messages: list[PushMessage] = field(default_factory=list)


class Transport:
    """
    Push xizmatiga chiqadigan nuqta.

    Ataylab interfeys: FCM ham, APNs ham loyihaning Firebase hisobini talab
    qiladi, u esa hali yaratilmagan. Shu sababli standart amalga oshirish
    xabarni logga yozadi — butun navbat mantiqi shusiz ham to'liq ishlaydi va
    sinovdan o'tadi. Firebase kaliti paydo bo'lganda faqat shu sinf
    almashtiriladi, chaqiruvchi kod o'zgarmaydi.
    """

    async def send(self, message: PushMessage) -> bool:
        """True — yetkazildi. False — qayta urinish kerak."""
        raise NotImplementedError


class LogTransport(Transport):
    """Ishlab chiqish uchun: hech qayerga yubormaydi, faqat yozib qo'yadi."""

    async def send(self, message: PushMessage) -> bool:
        log.info(
            "push → %s [%s] %s / %s",
            message.token[:12] + "…",
            message.platform,
            message.title,
            message.body[:60],
        )
        return True


async def devices_for(
    db: AsyncSession, user_ids: list[uuid.UUID]
) -> dict[uuid.UUID, list[Device]]:
    """One round trip for the whole batch, not one per notification."""
    if not user_ids:
        return {}

    rows = (
        await db.scalars(select(Device).where(Device.user_id.in_(set(user_ids))))
    ).all()

    grouped: dict[uuid.UUID, list[Device]] = {}
    for device in rows:
        grouped.setdefault(device.user_id, []).append(device)
    return grouped


async def settings_for(
    db: AsyncSession, user_ids: list[uuid.UUID]
) -> dict[uuid.UUID, NotificationSetting]:
    """Preferences for the whole batch in one query. Missing means defaults."""
    if not user_ids:
        return {}

    rows = (
        await db.scalars(
            select(NotificationSetting).where(
                NotificationSetting.user_id.in_(set(user_ids))
            )
        )
    ).all()
    return {row.user_id: row for row in rows}


async def deliver_pending(
    db: AsyncSession,
    *,
    transport: Transport | None = None,
    limit: int = BATCH,
    dry_run: bool = False,
) -> SendReport:
    """
    Send everything still unsent, oldest first.

    `dry_run` builds the messages and reports them without marking anything —
    the same rows come back on the next call. Useful for checking what a
    deploy is about to fire off before it fires it off.
    """
    transport = transport or LogTransport()
    report = SendReport()

    pending = list(
        (
            await db.scalars(
                select(Notification)
                .where(Notification.pushed_at.is_(None))
                .order_by(Notification.created_at)
                .limit(limit)
            )
        ).all()
    )
    if not pending:
        return report

    user_ids = [n.user_id for n in pending]
    by_user = await devices_for(db, user_ids)
    prefs = await settings_for(db, user_ids)
    now = datetime.now(UTC)

    for note in pending:
        setting = prefs.get(note.user_id)

        if not wants_push(setting, note.kind):
            report.muted += 1
            if not dry_run:
                note.pushed_at = now
            continue

        if in_quiet_hours(setting, now):
            created = note.created_at
            if created.tzinfo is None:
                created = created.replace(tzinfo=UTC)

            if (now - created).total_seconds() < MAX_HOLD_HOURS * 3600:
                report.held += 1
                continue
            # Juda uzoq kutdi. Sokin soatlar uni butunlay yutib yuborishiga
            # yo'l qo'ymaymiz — lekin eskirgan xabarni ham yubormaymiz.
            report.muted += 1
            if not dry_run:
                note.pushed_at = now
            continue

        targets = by_user.get(note.user_id, [])
        if not targets:
            # Qurilmasi yo'q. Bu xato emas — odam ilovani hali telefonga
            # o'rnatmagan yoki bildirishnomaga ruxsat bermagan. Belgilanmasa,
            # bu qator navbatda abadiy qolardi.
            report.skipped += 1
            if not dry_run:
                note.pushed_at = now
            continue

        delivered = False
        for device in targets:
            message = PushMessage(
                token=device.token,
                platform=device.platform.value,
                title=note.title,
                body=note.body,
                target_type=note.target_type.value,
                target_id=str(note.target_id) if note.target_id else None,
                notification_id=str(note.id),
            )
            report.messages.append(message)

            if dry_run:
                delivered = True
                continue

            try:
                if await transport.send(message):
                    delivered = True
            except Exception:
                log.exception("push transport failed for device %s", device.id)

        if delivered:
            report.sent += 1
            if not dry_run:
                note.pushed_at = now
        else:
            # Belgilanmaydi — keyingi yurishda qayta uriniladi.
            report.failed += 1

    if not dry_run:
        await db.commit()

    return report
