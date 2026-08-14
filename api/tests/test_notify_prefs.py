"""Bildirishnoma sozlamalari va ularning pushga ta'siri.

Talablar:

- Sozlamaga tegmagan hisob ham javob olsin (standart qiymatlar), 404 emas.
- O'chirilgan tur push olmasin, lekin bildirishnomaning o'zi yozilaversin —
  "matchlarni o'chirdim" degani "ularni mendan yashir" degani emas.
- Sokin soatlar yarim tundan o'tsin: 22 dan 7 gacha — odatiy holat va aynan
  shu holatda oddiy `boshi <= soat < oxiri` taqqoslash butun kunni jimitib
  qo'yadi.
- Sokin soatlarda xabar yo'qolmasin — kutsin va vaqti kelganda ketsin. Lekin
  cheksiz kutmasin: eskirgan "yangi taklif" xabari — xabar emas, shovqin.
"""

import asyncio
import sys
import uuid
from datetime import UTC, datetime, timedelta
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.db.session import SessionLocal  # noqa: E402
from app.models.device import Device, DevicePlatform  # noqa: E402
from app.models.notify_pref import NotificationSetting  # noqa: E402
from app.models.social import (  # noqa: E402
    Notification,
    NotifyKind,
    NotifyTargetType,
)
from app.services.push import (  # noqa: E402
    MAX_HOLD_HOURS,
    PushMessage,
    Transport,
    deliver_pending,
    in_quiet_hours,
)

BASE = "http://127.0.0.1:8010"


def check(label: str, ok: bool, extra: str = "") -> None:
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f"  — {extra}" if extra else ""))
    if not ok:
        raise SystemExit(1)


def login(c: httpx.Client, phone: str) -> tuple[str, str]:
    code = c.post("/auth/otp/request", json={"phone": phone}).json()["debug_code"]
    token = c.post(
        "/auth/otp/verify", json={"phone": phone, "code": code}
    ).json()["access_token"]
    me = c.get("/me", headers={"Authorization": f"Bearer {token}"}).json()
    return token, me["id"]


def auth(t: str) -> dict:
    return {"Authorization": f"Bearer {t}"}


class Collecting(Transport):
    def __init__(self) -> None:
        self.seen: list[PushMessage] = []

    async def send(self, message: PushMessage) -> bool:
        self.seen.append(message)
        return True


# --- 1. Yarim tundan o'tuvchi oraliq (sof mantiq, bazasiz) -------------------


def at(hour_local: int) -> datetime:
    """Toshkent vaqti bo'yicha shu soatga to'g'ri keluvchi UTC lahzasi."""
    return datetime(2026, 8, 14, (hour_local - 5) % 24, 30, tzinfo=UTC)


night = NotificationSetting(user_id=uuid.uuid4(), quiet_from=22, quiet_to=7)

check("23:30 — jim", in_quiet_hours(night, at(23)))
check("02:30 — jim", in_quiet_hours(night, at(2)))
check("06:30 — jim", in_quiet_hours(night, at(6)))
check("07:30 — jim emas", not in_quiet_hours(night, at(7)), "oxirgi soat kirmaydi")
check("12:30 — jim emas", not in_quiet_hours(night, at(12)))
check("21:30 — jim emas", not in_quiet_hours(night, at(21)))
check("22:30 — jim", in_quiet_hours(night, at(22)), "boshlanish soati kiradi")

day = NotificationSetting(user_id=uuid.uuid4(), quiet_from=9, quiet_to=17)
check("kunduzgi oraliq: 12:30 jim", in_quiet_hours(day, at(12)))
check("kunduzgi oraliq: 20:30 jim emas", not in_quiet_hours(day, at(20)))

check("sozlamasiz — hech qachon jim emas", not in_quiet_hours(None, at(3)))

empty = NotificationSetting(user_id=uuid.uuid4())
check("oraliq ko'rsatilmagan — jim emas", not in_quiet_hours(empty, at(3)))


# --- 2. Endpoint ------------------------------------------------------------

TOKEN = f"tok-pref-{uuid.uuid4().hex}"

with httpx.Client(base_url=BASE, timeout=30) as c:
    tok, user_id = login(c, "+998901234901")

    r = c.get("/notification-settings")
    check("sozlama autentifikatsiya talab qiladi", r.status_code == 401)

    r = c.get("/notification-settings", headers=auth(tok))
    check("tegilmagan hisob 200 oladi", r.status_code == 200, str(r.status_code))

    body = r.json()
    check(
        "standart holatda hammasi yoqilgan",
        all(body[k] for k in ("offers", "matches", "messages", "system")),
        str(body),
    )
    check(
        "standart holatda sokin soat yo'q",
        body["quiet_from"] is None and body["quiet_to"] is None,
    )

    r = c.patch(
        "/notification-settings", headers=auth(tok), json={"matches": False}
    )
    check("bitta turni o'chirish", r.status_code == 200, str(r.status_code))
    check("o'chirilgani qaytdi", r.json()["matches"] is False)
    check(
        "qolganlari tegilmadi",
        r.json()["offers"] is True and r.json()["messages"] is True,
        "faqat yuborilgan maydon o'zgaradi",
    )

    r = c.patch(
        "/notification-settings",
        headers=auth(tok),
        json={"quiet_from": 22, "quiet_to": 7},
    )
    check("sokin soatlar saqlandi", r.json()["quiet_from"] == 22)
    check("o'chirilgan tur saqlanib qoldi", r.json()["matches"] is False)

    # Oxirini olib tashlash boshini yolg'iz qoldiradi — aynan shu yarim holat
    # rad etilishi kerak.
    r = c.patch("/notification-settings", headers=auth(tok), json={"quiet_to": None})
    check(
        "yarim oraliq qabul qilinmaydi",
        r.status_code == 400,
        f"{r.status_code} — boshi bor, oxiri yo'q",
    )

    r = c.get("/notification-settings", headers=auth(tok)).json()
    check(
        "rad etilgan o'zgarish saqlanmadi",
        r["quiet_from"] == 22 and r["quiet_to"] == 7,
        f"{r['quiet_from']}–{r['quiet_to']} — 400 dan keyin qator eski holida",
    )

    r = c.patch("/notification-settings", headers=auth(tok), json={"quiet_from": 25})
    check("24 dan katta soat 422 beradi", r.status_code == 422, str(r.status_code))

    r = c.patch(
        "/notification-settings",
        headers=auth(tok),
        json={"quiet_from": None, "quiet_to": None},
    )
    check("sokin soatlarni o'chirish", r.json()["quiet_from"] is None)

    # Qurilma bo'lmasa push umuman urinilmaydi, shuning uchun kerak.
    c.post("/devices", headers=auth(tok), json={"token": TOKEN, "platform": "android"})


# --- 3. Sozlamaning pushga ta'siri ------------------------------------------


def note_for(owner: uuid.UUID, kind: NotifyKind, *, age_hours: int = 0) -> Notification:
    return Notification(
        user_id=owner,
        kind=kind,
        target_type=NotifyTargetType.listing,
        target_id=uuid.uuid4(),
        title=f"Sinov · {kind.value}",
        body="Sozlama tekshiruvi",
        created_at=datetime.now(UTC) - timedelta(hours=age_hours),
    )


async def push_checks() -> None:
    from sqlalchemy import delete, select

    async with SessionLocal() as db:
        owner = uuid.UUID(user_id)

        # Navbatni tozalab olamiz.
        await deliver_pending(db, transport=Collecting())

        setting = await db.scalar(
            select(NotificationSetting).where(NotificationSetting.user_id == owner)
        )
        check("sozlama qatori yaratilgan", setting is not None)

        # --- o'chirilgan tur ------------------------------------------------

        muted = note_for(owner, NotifyKind.match)
        wanted = note_for(owner, NotifyKind.offer)
        db.add_all([muted, wanted])
        await db.commit()

        sink = Collecting()
        report = await deliver_pending(db, transport=sink)

        check("o'chirilgan tur push olmadi", report.muted == 1, str(report.muted))
        check("yoqilgan tur push oldi", report.sent == 1, str(report.sent))
        check(
            "faqat bitta xabar ketdi",
            len(sink.seen) == 1 and "offer" in sink.seen[0].title,
            str([m.title for m in sink.seen]),
        )

        await db.refresh(muted)
        check(
            "o'chirilgan qator navbatdan chiqadi",
            muted.pushed_at is not None,
            "bu kutish emas, rad javobi",
        )

        found = await db.scalar(
            select(Notification).where(Notification.id == muted.id)
        )
        check(
            "o'chirilgan bo'lsa ham bildirishnoma qoladi",
            found is not None,
            "push o'chirish — yashirish emas",
        )

        # --- sokin soatlar ---------------------------------------------------

        setting.quiet_from = 0
        setting.quiet_to = 23  # deyarli butun kun — hozir albatta jim
        await db.commit()

        fresh = note_for(owner, NotifyKind.offer)
        db.add(fresh)
        await db.commit()

        report = await deliver_pending(db, transport=Collecting())
        check("sokin soatda ushlab qolindi", report.held == 1, str(report.held))
        check("sokin soatda hech narsa yuborilmadi", report.sent == 0)

        await db.refresh(fresh)
        check(
            "ushlangan qator navbatda qoladi",
            fresh.pushed_at is None,
            "vaqti kelganda yuboriladi, yo'qolmaydi",
        )

        # --- juda uzoq kutgan xabar ------------------------------------------

        stale = note_for(owner, NotifyKind.offer, age_hours=MAX_HOLD_HOURS + 1)
        db.add(stale)
        await db.commit()

        report = await deliver_pending(db, transport=Collecting())
        check(
            "eskirgan xabar cheksiz kutmaydi",
            report.muted >= 1,
            f"{MAX_HOLD_HOURS} soatdan oshgani tashlanadi",
        )

        await db.refresh(stale)
        check("eskirgan qator navbatdan chiqdi", stale.pushed_at is not None)

        # --- jimlik tugagach --------------------------------------------------

        setting.quiet_from = None
        setting.quiet_to = None
        await db.commit()

        sink = Collecting()
        report = await deliver_pending(db, transport=sink)
        check(
            "jimlik tugagach ushlangan xabar yetkaziladi",
            report.sent >= 1,
            "aynan shu sababli u navbatda saqlangan edi",
        )

        await db.refresh(fresh)
        check("ushlangan xabar nihoyat yuborildi", fresh.pushed_at is not None)

        # Tozalash.
        await db.execute(
            delete(Notification).where(Notification.user_id == owner)
        )
        await db.execute(delete(Device).where(Device.token == TOKEN))
        await db.commit()


asyncio.run(push_checks())
