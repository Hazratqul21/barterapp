"""Panel orqali bildirishnoma yuborish.

Asosiy talab: bu **alohida yo'l bo'lmasin**. Xabar mavjud navbatga
tushsin va boshqa hamma narsa bilan bir xil qoidalarga bo'ysunsin —
foydalanuvchi sozlamalari, sokin soatlar, qurilmasizlar. Alohida yo'l
qurilsa, bularning hammasini ikkinchi marta yozish kerak bo'lardi va
ikkinchisi birinchisidan farq qila boshlardi.

Ikkinchi talab: matn **har bir odamning o'z tilida** yozilsin. Bitta
tilda yuborish uchdan ikki foydalanuvchiga tushunarsiz xabar berardi.
"""

import asyncio
import sys
import uuid
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.db.session import SessionLocal  # noqa: E402
from app.models.social import Notification  # noqa: E402
from app.models.user import User  # noqa: E402

BASE = "http://127.0.0.1:8010"
MODERATOR_PHONE = "+998901234122"

_loop = asyncio.new_event_loop()
asyncio.set_event_loop(_loop)
run = _loop.run_until_complete


def check(label: str, ok: bool, extra: str = "") -> None:
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f"  → {extra}" if extra else ""))
    if not ok:
        raise SystemExit(1)


def login(c: httpx.Client, phone: str) -> tuple[str, str]:
    code = c.post("/auth/otp/request", json={"phone": phone}).json()["debug_code"]
    body = c.post("/auth/otp/verify", json={"phone": phone, "code": code}).json()
    me = c.get(
        "/me", headers={"Authorization": f"Bearer {body['access_token']}"}
    ).json()
    return body["access_token"], me["id"]


def auth(t: str) -> dict:
    return {"Authorization": f"Bearer {t}"}


async def make_moderator() -> None:
    from sqlalchemy import select

    async with SessionLocal() as db:
        user = await db.scalar(select(User).where(User.phone == MODERATOR_PHONE))
        user.is_moderator = True
        await db.commit()


run(make_moderator())

RUN = uuid.uuid4().hex[:6]
TITLE = {"uz": f"Sarlavha {RUN}", "ru": f"Заголовок {RUN}", "en": f"Title {RUN}"}
BODY = {"uz": "Matn uz", "ru": "Текст ru", "en": "Body en"}


async def notes_for(user_id: str) -> list[Notification]:
    from sqlalchemy import select

    async with SessionLocal() as db:
        rows = await db.scalars(
            select(Notification).where(
                Notification.user_id == uuid.UUID(user_id),
                Notification.title.like(f"%{RUN}%"),
            )
        )
        return list(rows.all())


with httpx.Client(base_url=BASE, timeout=30) as c:
    mod, mod_id = login(c, MODERATOR_PHONE)
    plain, plain_id = login(c, "+998901237001")
    russian, ru_id = login(c, "+998901237002")

    c.patch("/me", headers=auth(russian), json={"locale": "ru"})

    # --- kirish huquqi -------------------------------------------------------

    r = c.post("/admin/push", json={"title": TITLE, "body": BODY})
    check("anonim yubora olmaydi", r.status_code == 401, str(r.status_code))

    r = c.post("/admin/push", headers=auth(plain), json={"title": TITLE, "body": BODY})
    check("oddiy foydalanuvchi uchun 404", r.status_code == 404, str(r.status_code))

    check(
        "holat moderatorga ochiq",
        c.get("/admin/push/status", headers=auth(mod)).status_code == 200,
    )

    # --- yarim tarjima rad etiladi -------------------------------------------

    r = c.post(
        "/admin/push",
        headers=auth(mod),
        json={"title": {"uz": "a", "ru": "", "en": "c"}, "body": BODY},
    )
    check(
        "yarim tarjima 422 beradi",
        r.status_code == 422,
        "bitta tilda yuborish uchdan ikkisiga tushunarsiz bo'lardi",
    )

    # --- sinov yurishi hech narsa yozmaydi -----------------------------------

    r = c.post(
        "/admin/push",
        headers=auth(mod),
        json={"segment": "everyone", "title": TITLE, "body": BODY, "dry_run": True},
    ).json()
    check("sinov qabul qiluvchilarni sanaydi", r["recipients"] > 0, str(r))
    check("sinov hech narsa navbatga qo'ymaydi", r["queued"] == 0)
    check(
        "sinovdan keyin bildirishnoma yo'q",
        run(notes_for(plain_id)) == [],
        "«hammaga» qaytarib bo'lmaydigan tugma — avval sanash kerak",
    )
    expected = r["recipients"]

    # --- haqiqiy yuborish ----------------------------------------------------

    r = c.post(
        "/admin/push",
        headers=auth(mod),
        json={"segment": "everyone", "title": TITLE, "body": BODY},
    ).json()
    check("yuborildi", r["queued"] == expected, f"{r['queued']} / {expected}")

    mine = run(notes_for(plain_id))
    check("bildirishnoma yozildi", len(mine) == 1, str(len(mine)))
    check("o'zbekcha odam o'zbekchasini oldi", mine[0].title == TITLE["uz"], mine[0].title)

    theirs = run(notes_for(ru_id))
    check(
        "ruscha odam ruschasini oldi",
        theirs and theirs[0].title == TITLE["ru"],
        theirs[0].title if theirs else "yo'q",
    )
    check("matn ham tarjima qilingan", theirs[0].body == BODY["ru"], theirs[0].body)

    # --- ilova ichidagi ro'yxatda ko'rinadi ----------------------------------

    inbox = c.get("/notifications", headers=auth(plain)).json()
    check(
        "ilovadagi ro'yxatga tushdi",
        any(TITLE["uz"] in n["title"] for n in inbox),
        "alohida yo'l emas — mavjud navbatga tushadi",
    )

    # --- segmentlar ----------------------------------------------------------

    everyone = c.post(
        "/admin/push",
        headers=auth(mod),
        json={"segment": "everyone", "title": TITLE, "body": BODY, "dry_run": True},
    ).json()["recipients"]

    with_l = c.post(
        "/admin/push",
        headers=auth(mod),
        json={"segment": "with_listings", "title": TITLE, "body": BODY, "dry_run": True},
    ).json()["recipients"]

    without_l = c.post(
        "/admin/push",
        headers=auth(mod),
        json={
            "segment": "without_listings",
            "title": TITLE,
            "body": BODY,
            "dry_run": True,
        },
    ).json()["recipients"]

    check(
        "ikki segment birgalikda hammasini beradi",
        with_l + without_l == everyone,
        f"{with_l} + {without_l} = {with_l + without_l}, hammasi {everyone}",
    )
    check("e'loni borlar bor", with_l > 0, str(with_l))

    r = c.post(
        "/admin/push",
        headers=auth(mod),
        json={"segment": "region", "title": TITLE, "body": BODY, "dry_run": True},
    )
    check("viloyatsiz region segmenti 400 beradi", r.status_code == 400, str(r.status_code))

    regions = c.get("/regions").json()
    r = c.post(
        "/admin/push",
        headers=auth(mod),
        json={
            "segment": "region",
            "region": regions[0],
            "title": TITLE,
            "body": BODY,
            "dry_run": True,
        },
    ).json()
    check(
        "viloyat segmenti hammadan kam",
        r["recipients"] <= everyone,
        f"{r['recipients']} <= {everyone}",
    )

    # --- o'chirilgan hisobga yuborilmaydi ------------------------------------

    doomed, doomed_id = login(c, "+998901237003")
    before = c.post(
        "/admin/push",
        headers=auth(mod),
        json={"segment": "everyone", "title": TITLE, "body": BODY, "dry_run": True},
    ).json()["recipients"]

    c.request("DELETE", "/me", headers=auth(doomed), json={"confirm": True})

    after = c.post(
        "/admin/push",
        headers=auth(mod),
        json={"segment": "everyone", "title": TITLE, "body": BODY, "dry_run": True},
    ).json()["recipients"]

    check(
        "o'chirilgan hisob qabul qiluvchilardan chiqadi",
        after == before - 1,
        f"{before} → {after}",
    )

    # --- holat rostini aytadi ------------------------------------------------

    status = c.get("/admin/push/status", headers=auth(mod)).json()
    check("holatda qurilma soni bor", "devices" in status, str(status))
    check(
        "transport tayyor emasligi ochiq aytiladi",
        status["transport_ready"] is False,
        "«yubordim, lekin hech kim olmadi» holatining eng ko'p sababi shu",
    )
    check("navbat ko'rsatiladi", status["queued"] > 0, str(status["queued"]))
