"""Qurilma ro'yxati va push outbox'i.

Muhim talablar:

- Bir qurilma tokeni bitta hisobga tegishli bo'lsin. Telefon boshqa odamga
  o'tsa, token yangi hisobga ko'chsin — aks holda yangi egasi eskisining
  bildirishnomalarini olardi.
- Bildirishnoma savdo o'zgarishi bilan bir tranzaksiyada yoziladi, push esa
  keyin yuboriladi. Shu sababli qaytarilgan tranzaksiya "savdo bo'ldi" degan
  push qoldirmaydi.
- Qurilmasi yo'q odamning bildirishnomasi navbatda abadiy qolmasin.
- Yuborilgan qator ikkinchi marta yuborilmasin.
- Transport yiqilsa qator navbatda qolsin — yo'qolgan bildirishnoma o'rniga
  takroriy urinish.
"""

import asyncio
import sys
import uuid
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.db.session import SessionLocal  # noqa: E402
from app.models.device import Device  # noqa: E402
from app.models.social import (  # noqa: E402
    Notification,
    NotifyKind,
    NotifyTargetType,
)
from app.services.push import PushMessage, Transport, deliver_pending  # noqa: E402

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
    """Hech qayerga yubormaydi, faqat nima ketganini yozib oladi."""

    def __init__(self) -> None:
        self.seen: list[PushMessage] = []

    async def send(self, message: PushMessage) -> bool:
        self.seen.append(message)
        return True


class Broken(Transport):
    """Har doim yiqiladi — qayta urinish mantiqini tekshirish uchun."""

    async def send(self, message: PushMessage) -> bool:
        raise RuntimeError("tashqi xizmat javob bermadi")


TOKEN_A = f"tok-a-{uuid.uuid4().hex}"
TOKEN_B = f"tok-b-{uuid.uuid4().hex}"

with httpx.Client(base_url=BASE, timeout=30) as c:
    ann, ann_id = login(c, "+998901234801")
    bob, bob_id = login(c, "+998901234802")

    # --- ro'yxatdan o'tkazish ------------------------------------------------

    r = c.post("/devices", json={"token": TOKEN_A, "platform": "ios"})
    check("qurilma autentifikatsiya talab qiladi", r.status_code == 401)

    r = c.post(
        "/devices",
        headers=auth(ann),
        json={"token": TOKEN_A, "platform": "ios", "locale": "uz"},
    )
    check("qurilma ro'yxatdan o'tdi", r.status_code == 204, str(r.status_code))

    r = c.post(
        "/devices",
        headers=auth(ann),
        json={"token": TOKEN_A, "platform": "ios", "locale": "ru"},
    )
    check(
        "har ochilishda qayta yuborish xato emas",
        r.status_code == 204,
        "mijoz buni har ishga tushganda chaqiradi",
    )

    r = c.post(
        "/devices", headers=auth(ann), json={"token": "qisqa", "platform": "ios"}
    )
    check("juda qisqa token 422 beradi", r.status_code == 422, str(r.status_code))

    r = c.post(
        "/devices",
        headers=auth(ann),
        json={"token": TOKEN_B, "platform": "bunday-platforma-yoq"},
    )
    check("noma'lum platforma 422 beradi", r.status_code == 422)


async def db_checks() -> None:
    """Bitta hodisa halqasi — aks holda engine ikki halqaga bo'linib ketadi."""
    async with SessionLocal() as db:
        from sqlalchemy import delete, select

        # --- token ko'chishi -------------------------------------------------

        rows = (await db.scalars(select(Device).where(Device.token == TOKEN_A))).all()
        check("token bo'yicha bitta qator", len(rows) == 1, str(len(rows)))
        check(
            "qayta yuborilgan locale yangilandi",
            rows[0].locale == "ru",
            rows[0].locale,
        )
        first_owner = rows[0].user_id

        # Bob o'sha telefonga kirdi.
        with httpx.Client(base_url=BASE, timeout=30) as c2:
            bob_token, bob_id2 = login(c2, "+998901234802")
            c2.post(
                "/devices",
                headers={"Authorization": f"Bearer {bob_token}"},
                json={"token": TOKEN_A, "platform": "ios"},
            )

        # Sessiya `expire_on_commit=False` bilan ochilgan, shuning uchun yuqorida
        # o'qilgan Device nusxasi identity map'da qolgan va HTTP orqali
        # kiritilgan o'zgarishni ko'rmaydi. Tozalamasak, sinov bazani emas,
        # o'zining keshini tekshirgan bo'lardi.
        db.expunge_all()
        rows = (await db.scalars(select(Device).where(Device.token == TOKEN_A))).all()
        check("token hali ham bitta qator", len(rows) == 1, str(len(rows)))
        check(
            "token yangi egasiga ko'chdi",
            str(rows[0].user_id) == bob_id2 and rows[0].user_id != first_owner,
            "aks holda yangi egasi eskisining xabarlarini olardi",
        )
        owner_id = rows[0].user_id

        # --- outbox ----------------------------------------------------------

        # Toza boshlash uchun mavjud navbatni yopamiz.
        await deliver_pending(db, transport=Collecting())

        report = await deliver_pending(db, transport=Collecting())
        check("navbat bo'shagach hech narsa yuborilmaydi", report.sent == 0)

        note = Notification(
            user_id=owner_id,
            kind=NotifyKind.system,
            target_type=NotifyTargetType.listing,
            target_id=uuid.uuid4(),
            title="Sinov xabari",
            body="Outbox tekshiruvi",
            created_at=__import__("datetime").datetime.now(
                __import__("datetime").UTC
            ),
        )
        db.add(note)
        await db.commit()

        # --- quruq yurish hech narsani belgilamaydi --------------------------

        dry = await deliver_pending(db, transport=Collecting(), dry_run=True)
        check("quruq yurish xabarni ko'radi", dry.sent == 1, str(dry.sent))

        await db.refresh(note)
        check(
            "quruq yurish pushed_at qo'ymaydi",
            note.pushed_at is None,
            "aks holda ko'rib chiqish yuborishga aylanardi",
        )

        # --- transport yiqilsa navbatda qoladi -------------------------------

        broken = await deliver_pending(db, transport=Broken())
        check("yiqilgan transport muvaffaqiyatsiz deb belgilanadi", broken.failed == 1)

        await db.refresh(note)
        check(
            "yiqilgandan keyin qator navbatda qoladi",
            note.pushed_at is None,
            "yo'qolgan bildirishnoma o'rniga takroriy urinish",
        )

        # --- haqiqiy yuborish -------------------------------------------------

        sink = Collecting()
        good = await deliver_pending(db, transport=sink)
        check("xabar yuborildi", good.sent == 1, str(good.sent))
        check("qurilmaga yetdi", len(sink.seen) == 1, str(len(sink.seen)))

        sent = sink.seen[0]
        check("push sarlavhani tashiydi", sent.title == "Sinov xabari", sent.title)
        check(
            "push yo'nalishni tashiydi",
            sent.target_type == "listing" and sent.target_id is not None,
            "mijoz shunga qarab qaysi ekranni ochishni biladi",
        )
        check("push qurilma tokeniga ketdi", sent.token == TOKEN_A)

        await db.refresh(note)
        check("yuborilgach pushed_at qo'yiladi", note.pushed_at is not None)

        again = await deliver_pending(db, transport=Collecting())
        check(
            "ikkinchi marta yuborilmaydi",
            again.sent == 0,
            "har cron yurishida takror push kelmasligi kerak",
        )

        # --- qurilmasi yo'q foydalanuvchi -------------------------------------

        await db.execute(delete(Device).where(Device.token == TOKEN_A))
        await db.commit()

        orphan = Notification(
            user_id=owner_id,
            kind=NotifyKind.system,
            target_type=NotifyTargetType.listing,
            target_id=uuid.uuid4(),
            title="Qurilmasiz",
            body="Bu odamda qurilma yo'q",
            created_at=__import__("datetime").datetime.now(
                __import__("datetime").UTC
            ),
        )
        db.add(orphan)
        await db.commit()

        report = await deliver_pending(db, transport=Collecting())
        check("qurilmasiz bildirishnoma o'tkazib yuborildi", report.skipped >= 1)

        await db.refresh(orphan)
        check(
            "qurilmasiz qator ham navbatdan chiqadi",
            orphan.pushed_at is not None,
            "aks holda har yurishda qaytadan ko'rib chiqilardi",
        )

        await db.execute(delete(Notification).where(Notification.id == note.id))
        await db.execute(delete(Notification).where(Notification.id == orphan.id))
        await db.commit()


def unregister_checks() -> None:
    """HTTP qismi — sinxron, shuning uchun halqa ichidan bemalol chaqiriladi."""
    with httpx.Client(base_url=BASE, timeout=30) as c:
        ann, _ = login(c, "+998901234801")
        c.post(
            "/devices", headers=auth(ann), json={"token": TOKEN_B, "platform": "android"}
        )

        r = c.delete(f"/devices/{TOKEN_B}", headers=auth(ann))
        check("qurilma o'chirildi", r.status_code == 204, str(r.status_code))

        r = c.delete(f"/devices/{TOKEN_B}", headers=auth(ann))
        check(
            "yo'q qurilmani o'chirish xato emas",
            r.status_code == 204,
            "chiqishda mijozda qayta urinish imkoni yo'q",
        )

        bob, _ = login(c, "+998901234802")
        c.post(
            "/devices", headers=auth(ann), json={"token": TOKEN_B, "platform": "android"}
        )
        r = c.delete(f"/devices/{TOKEN_B}", headers=auth(bob))
        check("boshqaning qurilmasi o'chmaydi", r.status_code == 204)


async def still_there() -> None:
    from sqlalchemy import delete, select

    async with SessionLocal() as db:
        found = await db.scalar(select(Device).where(Device.token == TOKEN_B))
        check(
            "begona o'chirish qurilmani yo'qotmadi",
            found is not None,
            "204 qaytdi, lekin qator joyida",
        )
        await db.execute(delete(Device).where(Device.token == TOKEN_B))
        await db.commit()


async def everything() -> None:
    """
    Hammasi bitta hodisa halqasida.

    Ikkita alohida `asyncio.run()` async engine'ni ikki halqaga bo'lib
    yuboradi va ulanish "attached to a different loop" bilan yiqiladi —
    sinovning o'zi buzilgani uchun, tekshirilayotgan kod emas.
    """
    await db_checks()
    unregister_checks()
    await still_there()


asyncio.run(everything())
