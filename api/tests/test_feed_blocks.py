"""Lentaning boshqariladigan bo'laklari.

Nega bu kerak: banner va tanlangan e'lonlar mijoz kodiga qattiq yozilgan
edi. Bayram banneri uchun uch platformaga reliz kerak bo'lardi — App Store
ko'rigi bilan bir hafta, mavsum esa bir haftada o'tib ketadi.

Talablar:

- Rejalashtirilgan bo'lak vaqti kelmaguncha ko'rinmasin va muddati o'tgach
  o'zi yo'qolsin. Filtr **serverda**: mijozdagi soat xato bo'lishi mumkin
  va bayram banneri bir kun erta chiqib ketishi mumkin emas.
- Tanlangan e'lonlar **admin bergan tartibda** kelsin. SQL `IN` tartibni
  saqlamaydi, tahririyat tartibi esa aynan muhim.
- Ichi bo'shab qolgan tanlov umuman ko'rsatilmasin — sarlavha yolg'iz
  qolsa, buzuq ekran bo'lib ko'rinadi.
- Panel faqat moderatorga ochiq bo'lsin.
"""

import asyncio
import sys
import uuid
from datetime import UTC, datetime, timedelta
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.db.session import SessionLocal  # noqa: E402
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


def login(c: httpx.Client, phone: str) -> str:
    code = c.post("/auth/otp/request", json={"phone": phone}).json()["debug_code"]
    return c.post(
        "/auth/otp/verify", json={"phone": phone, "code": code}
    ).json()["access_token"]


def auth(t: str) -> dict:
    return {"Authorization": f"Bearer {t}"}


def tri(v: str) -> dict:
    return {"uz": f"{v} uz", "ru": f"{v} ru", "en": f"{v} en"}


async def make_moderator() -> None:
    from sqlalchemy import select

    async with SessionLocal() as db:
        user = await db.scalar(select(User).where(User.phone == MODERATOR_PHONE))
        user.is_moderator = True
        await db.commit()


run(make_moderator())

RUN = uuid.uuid4().hex[:6]
made: list[str] = []

with httpx.Client(base_url=BASE, timeout=30) as c:
    mod = login(c, MODERATOR_PHONE)
    plain = login(c, "+998901236001")

    # --- kirish huquqi -------------------------------------------------------

    check("panel anonim uchun yopiq", c.get("/admin/feed-blocks").status_code == 401)
    check(
        "oddiy foydalanuvchi uchun 404",
        c.get("/admin/feed-blocks", headers=auth(plain)).status_code == 404,
        "403 API borligini oshkor qilardi",
    )
    check(
        "moderator ko'radi",
        c.get("/admin/feed-blocks", headers=auth(mod)).status_code == 200,
    )

    # --- yaratish ------------------------------------------------------------

    r = c.post(
        "/admin/feed-blocks",
        headers=auth(mod),
        json={
            "kind": "banner",
            "slot": f"test_{RUN}",
            "position": 0,
            "title": tri("Banner"),
            "subtitle": tri("Tavsif"),
            "background": "#0D9488",
            "action": "open_category",
            "action_value": "agri",
        },
    )
    check("banner yaratildi", r.status_code == 201, r.text[:120])
    banner = r.json()["id"]
    made.append(banner)

    r = c.post(
        "/admin/feed-blocks",
        headers=auth(mod),
        json={
            "kind": "banner",
            "slot": f"test_{RUN}",
            "title": tri("Rang"),
            "background": "qizil",
        },
    )
    check("noto'g'ri rang 422 beradi", r.status_code == 422, str(r.status_code))

    # --- ommaviy javob -------------------------------------------------------

    blocks = c.get("/feed-blocks", params={"slot": f"test_{RUN}"}).json()
    check("bo'lak kirmasdan ham ko'rinadi", len(blocks) == 1, str(len(blocks)))
    check("javob bitta tilda", blocks[0]["title"] == "Banner uz", blocks[0]["title"])

    ru = c.get(
        "/feed-blocks",
        params={"slot": f"test_{RUN}"},
        headers={"Accept-Language": "ru"},
    ).json()
    check("til almashadi", ru[0]["title"] == "Banner ru", ru[0]["title"])
    check("amal va qiymat keladi", ru[0]["action"] == "open_category")

    # --- o'chirilgani ko'rinmaydi --------------------------------------------

    c.patch(
        f"/admin/feed-blocks/{banner}",
        headers=auth(mod),
        json={
            "kind": "banner",
            "slot": f"test_{RUN}",
            "is_active": False,
            "title": tri("Banner"),
        },
    )
    check(
        "o'chirilgan bo'lak lentaga chiqmaydi",
        c.get("/feed-blocks", params={"slot": f"test_{RUN}"}).json() == [],
    )
    check(
        "lekin panelda turadi",
        any(
            b["id"] == banner
            for b in c.get("/admin/feed-blocks", headers=auth(mod)).json()
        ),
    )

    # --- rejalashtirish ------------------------------------------------------

    now = datetime.now(UTC)
    future = c.post(
        "/admin/feed-blocks",
        headers=auth(mod),
        json={
            "kind": "notice",
            "slot": f"test_{RUN}",
            "title": tri("Kelajak"),
            "starts_at": (now + timedelta(days=2)).isoformat(),
        },
    ).json()["id"]
    made.append(future)

    past = c.post(
        "/admin/feed-blocks",
        headers=auth(mod),
        json={
            "kind": "notice",
            "slot": f"test_{RUN}",
            "title": tri("O'tmish"),
            "ends_at": (now - timedelta(days=1)).isoformat(),
        },
    ).json()["id"]
    made.append(past)

    live = c.post(
        "/admin/feed-blocks",
        headers=auth(mod),
        json={
            "kind": "notice",
            "slot": f"test_{RUN}",
            "title": tri("Hozir"),
            "starts_at": (now - timedelta(hours=1)).isoformat(),
            "ends_at": (now + timedelta(hours=1)).isoformat(),
        },
    ).json()["id"]
    made.append(live)

    visible = [b["id"] for b in c.get("/feed-blocks", params={"slot": f"test_{RUN}"}).json()]
    check(
        "vaqti kelmagani ko'rinmaydi",
        future not in visible,
        "bayram banneri bir kun erta chiqmasin",
    )
    check("muddati o'tgani ko'rinmaydi", past not in visible)
    check("oynasi ochig'i ko'rinadi", live in visible, str(visible))

    r = c.post(
        "/admin/feed-blocks",
        headers=auth(mod),
        json={
            "kind": "notice",
            "slot": f"test_{RUN}",
            "title": tri("Teskari"),
            "starts_at": (now + timedelta(days=2)).isoformat(),
            "ends_at": now.isoformat(),
        },
    )
    check(
        "teskari oyna toza 422 beradi",
        r.status_code == 422,
        f"{r.status_code} — 500 bo'lsa admin nimani xato yozganini bilmaydi",
    )

    # --- tanlangan e'lonlar --------------------------------------------------

    feed = c.get("/listings", params={"limit": 4}).json()["items"]
    check("sinov uchun e'lon bor", len(feed) >= 3, str(len(feed)))

    picked = [feed[2]["id"], feed[0]["id"], feed[1]["id"]]
    promo = c.post(
        "/admin/feed-blocks",
        headers=auth(mod),
        json={
            "kind": "promo_listings",
            "slot": f"test_{RUN}",
            "position": 9,
            "title": tri("Tanlov"),
            "listing_ids": picked,
        },
    ).json()["id"]
    made.append(promo)

    got = [
        b for b in c.get("/feed-blocks", params={"slot": f"test_{RUN}"}).json()
        if b["id"] == promo
    ]
    check("tanlov ko'rinadi", len(got) == 1)
    check(
        "e'lonlar to'ldirilgan holda keladi",
        len(got[0]["listings"]) == 3,
        "mijoz alohida so'rov yubormasin",
    )
    check(
        "tartib admin bergani bo'yicha",
        [x["id"] for x in got[0]["listings"]] == picked,
        "SQL IN tartibni saqlamaydi, tahririyat tartibi esa muhim",
    )

    empty = c.post(
        "/admin/feed-blocks",
        headers=auth(mod),
        json={
            "kind": "promo_listings",
            "slot": f"test_{RUN}",
            "title": tri("Bo'sh"),
            "listing_ids": [str(uuid.uuid4())],
        },
    ).json()["id"]
    made.append(empty)

    check(
        "ichi bo'sh tanlov ko'rsatilmaydi",
        empty not in [b["id"] for b in c.get("/feed-blocks", params={"slot": f"test_{RUN}"}).json()],
        "sarlavha yolg'iz qolsa buzuq ekran bo'lib ko'rinadi",
    )

    # --- tartib --------------------------------------------------------------

    order = [b["position"] for b in c.get("/feed-blocks", params={"slot": f"test_{RUN}"}).json()]
    check("tartib bo'yicha keladi", order == sorted(order), str(order))

    # --- o'chirish -----------------------------------------------------------

    check(
        "o'chirish faqat moderatorga",
        c.delete(f"/admin/feed-blocks/{banner}", headers=auth(plain)).status_code == 404,
    )

    for block_id in made:
        c.delete(f"/admin/feed-blocks/{block_id}", headers=auth(mod))

    check(
        "hammasi o'chirildi",
        c.get("/feed-blocks", params={"slot": f"test_{RUN}"}).json() == [],
    )
    check(
        "yo'q bo'lakni o'chirish xato emas",
        c.delete(f"/admin/feed-blocks/{banner}", headers=auth(mod)).status_code == 204,
    )

    # --- panel sahifasi ------------------------------------------------------

    page = c.get("/admin")
    check("admin sahifasi ochiladi", page.status_code == 200, str(page.status_code))
    check("HTML qaytadi", "text/html" in page.headers.get("content-type", ""))
