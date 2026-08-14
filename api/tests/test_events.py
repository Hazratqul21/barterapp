"""Hodisalar va tahlil.

Bu jadvalning boshqalardan farqi: uni orqaga qaytib to'ldirib bo'lmaydi.
Shuning uchun yozilishi ishonchli bo'lishi shart, va uning ishonchliligi
aynan shu yerda tekshiriladi.

Talablar:

- Takroriy yuborish sonlarni ikki barobar qilmasin. Tarmoq uzilganda mijoz
  paketni qayta yuboradi; usiz CTR jimgina ikki barobar pasayardi — raqamlar
  bor, lekin ular yolg'on.
- Anonim ko'rish ham yozilsin. Odam ro'yxatdan o'tishdan oldin nima
  izlagani eng qimmatli ma'lumot; faqat kirganlardan yig'ish bu savolni
  butunlay yopadi.
- Server o'zi biladigan hodisalarni o'zi yozsin — mijozga ishonib bo'lmaydi.
- Hodisa yozilmagani asosiy amalni yiqitmasin.
- Bo'sh qidiruv alohida yozilsin: bu bozordagi bo'shliq.
"""

import asyncio
import sys
import uuid
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.db.session import SessionLocal  # noqa: E402
from app.models.event import EventKind  # noqa: E402
from app.models.user import User  # noqa: E402
from app.services import analytics  # noqa: E402

BASE = "http://127.0.0.1:8010"
MODERATOR_PHONE = "+998901234122"
RUN = uuid.uuid4().hex[:8]

#: Bitta doimiy hodisa halqasi.
#:
#: Har chaqiruvda `asyncio.run()` yangi halqa yaratadi, async engine esa
#: ulanishlarni birinchisiga bog'lab qo'ygan bo'ladi — ikkinchisida
#: "attached to a different loop" bilan yiqiladi. Bu sinovning muammosi,
#: tekshirilayotgan kodniki emas, shuning uchun halqa shu yerda ushlab
#: turiladi.
_loop = asyncio.new_event_loop()
asyncio.set_event_loop(_loop)
run = _loop.run_until_complete


def check(label: str, ok: bool, extra: str = "") -> None:
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f"  → {extra}" if extra else ""))
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


async def make_moderator() -> None:
    from sqlalchemy import select

    async with SessionLocal() as db:
        user = await db.scalar(select(User).where(User.phone == MODERATOR_PHONE))
        user.is_moderator = True
        await db.commit()


run(make_moderator())


async def count_of(kind: EventKind, target_id: str | None = None) -> int:
    from sqlalchemy import func, select

    from app.models.event import Event

    async with SessionLocal() as db:
        query = select(func.count()).select_from(Event).where(Event.kind == kind.value)
        if target_id:
            query = query.where(Event.target_id == uuid.UUID(target_id))
        return await db.scalar(query) or 0


with httpx.Client(base_url=BASE, timeout=30) as c:
    mod, mod_id = login(c, MODERATOR_PHONE)
    tok, user_id = login(c, "+998901235001")

    # --- paketli qabul -------------------------------------------------------

    listing_a = str(uuid.uuid4())
    batch = {
        "session_id": f"sess-{RUN}",
        "platform": "ios",
        "events": [
            {
                "kind": "listing_impression",
                "target_type": "listing",
                "target_id": listing_a,
                "payload": {"position": i},
                "dedupe_key": f"{RUN}-imp-{i}",
            }
            for i in range(5)
        ],
    }

    r = c.post("/events", json=batch)
    check("anonim hodisa qabul qilinadi", r.status_code == 200, str(r.status_code))
    check(
        "beshtasi ham yozildi",
        r.json()["accepted"] == 5,
        "kirmagan odamning ko'rishi tahlilning yarmi",
    )

    # --- takroriy yuborish ---------------------------------------------------

    r = c.post("/events", json=batch)
    check("takroriy paket xato emas", r.status_code == 200)
    check(
        "takror yozilmadi",
        r.json()["accepted"] == 0 and r.json()["duplicates"] == 5,
        f"{r.json()} — aks holda CTR ikki barobar pasayardi",
    )

    # Kalitsiz hodisa har safar yoziladi — mijoz kalit bermasa, dedup ham yo'q.
    nokey = {
        "events": [
            {"kind": "listing_impression", "target_type": "listing",
             "target_id": listing_a}
        ]
    }
    first = c.post("/events", json=nokey).json()["accepted"]
    second = c.post("/events", json=nokey).json()["accepted"]
    check(
        "kalitsiz hodisalar to'qnashmaydi",
        first == 1 and second == 1,
        "NULL o'zi bilan teng emas — har biri alohida qator",
    )

    # --- cheklovlar ----------------------------------------------------------

    r = c.post("/events", json={"events": []})
    check("bo'sh paket 422 beradi", r.status_code == 422, str(r.status_code))

    r = c.post(
        "/events",
        json={"events": [{"kind": "bunday-hodisa-yoq", "payload": {}}]},
    )
    check(
        "noma'lum tur 422 beradi",
        r.status_code == 422,
        "xato nom bazaga umuman yetib bormaydi",
    )

    r = c.post(
        "/events",
        json={"events": [{"kind": "listing_view", "payload": {str(i): i for i in range(25)}}]},
    )
    check("juda katta payload 422 beradi", r.status_code == 422, str(r.status_code))

    r = c.post(
        "/events",
        json={"events": [{"kind": "listing_view"}] * 101},
    )
    check("juda uzun paket 422 beradi", r.status_code == 422, str(r.status_code))

    # --- soat siljishi -------------------------------------------------------

    r = c.post(
        "/events",
        json={
            "events": [
                {
                    "kind": "listing_view",
                    "occurred_at": "2030-01-01T00:00:00Z",
                    "dedupe_key": f"{RUN}-future",
                }
            ]
        },
    )
    check("kelajakdagi vaqt rad etilmaydi", r.status_code == 200)


async def skew_check() -> None:
    from sqlalchemy import select

    from app.models.event import Event

    async with SessionLocal() as db:
        row = await db.scalar(
            select(Event).where(Event.dedupe_key == f"{RUN}-future")
        )
        check(
            "kelajakdagi vaqt serverning vaqtiga tortiladi",
            row.occurred_at.year < 2030,
            f"{row.occurred_at} — bitta noto'g'ri soat kunlik hisobotni siljitmasin",
        )


run(skew_check())


# --- server o'zi yozadigan hodisalar ----------------------------------------

with httpx.Client(base_url=BASE, timeout=30) as c:
    tok, user_id = login(c, "+998901235001")

    before_search = run(count_of(EventKind.search))
    before_empty = run(count_of(EventKind.search_empty))

    feed = c.get("/listings", headers=auth(tok), params={"limit": 50}).json()
    target = feed["items"][0]

    c.get(
        "/listings",
        headers=auth(tok),
        params={"q": target["title"].split()[0], "limit": 20},
    )
    check(
        "natijali qidiruv yozildi",
        run(count_of(EventKind.search)) == before_search + 1,
    )

    c.get("/listings", headers=auth(tok), params={"q": f"zzqw-{RUN}", "limit": 20})
    check(
        "bo'sh qidiruv alohida yozildi",
        run(count_of(EventKind.search_empty)) == before_empty + 1,
        "bozordagi bo'shliq boshqa hech qayerdan ko'rinmaydi",
    )

    # Ikkinchi sahifa yangi qidiruv emas.
    page = c.get(
        "/listings", headers=auth(tok), params={"q": "a", "limit": 1}
    ).json()
    if page["next_cursor"]:
        was = run(count_of(EventKind.search))
        c.get(
            "/listings",
            headers=auth(tok),
            params={"q": "a", "limit": 1, "cursor": page["next_cursor"]},
        )
        check(
            "sahifalash yangi qidiruv sifatida sanalmaydi",
            run(count_of(EventKind.search)) == was,
            "aks holda har aylantirish qidiruvga aylanardi",
        )

    # --- e'lon ochilgani -----------------------------------------------------

    before = run(count_of(EventKind.listing_view, target["id"]))
    c.get(f"/listings/{target['id']}", headers=auth(tok))
    check(
        "e'lon ochilgani yozildi",
        run(count_of(EventKind.listing_view, target["id"])) == before + 1,
    )

    # --- saqlash -------------------------------------------------------------

    before = run(count_of(EventKind.favorite_add, target["id"]))
    c.post(f"/listings/{target['id']}/favorite", headers=auth(tok))
    check(
        "saqlash yozildi",
        run(count_of(EventKind.favorite_add, target["id"])) == before + 1,
    )

    # Takroriy saqlash yangi hodisa yaratmaydi — holat o'zgarmadi.
    was = run(count_of(EventKind.favorite_add, target["id"]))
    c.post(f"/listings/{target['id']}/favorite", headers=auth(tok))
    check(
        "takroriy saqlash yangi hodisa yozmaydi",
        run(count_of(EventKind.favorite_add, target["id"])) == was,
        "holat o'zgarmadi, demak hodisa ham yo'q",
    )

    before_rm = run(count_of(EventKind.favorite_remove, target["id"]))
    c.delete(f"/listings/{target['id']}/favorite", headers=auth(tok))
    check(
        "olib tashlash ham yozildi",
        run(count_of(EventKind.favorite_remove, target["id"]))
        == before_rm + 1,
        "fikri o'zgargani ham ma'lumot",
    )

    # --- taklif --------------------------------------------------------------

    def tri(u, ru, en):
        return {"uz": u, "ru": ru, "en": en}

    made = c.post(
        "/listings",
        headers=auth(tok),
        json={
            "tag": "agri",
            "title": tri("Hodisa sinovi", "Тест события", "Event test"),
            "description": tri("Sinov", "Тест", "Test"),
            "image_alt": tri("Sinov", "Тест", "Test"),
            "category": tri("Sinov", "Тест", "Test"),
            "condition": tri("Yangi", "Новый", "New"),
            "quantity": tri("1 dona", "1 шт", "1 piece"),
            "wants_summary": tri("Nimadir", "Что-то", "Something"),
            "wants": [tri("Nimadir", "Что-то", "Something")],
            "desires": [{"category": None, "will_add_cash": True, "wants_cash": False}],
            "photos": [],
            "value": {"minor": 100000000, "currency": "UZS"},
            "cash_ok": True,
        },
    )
    mine = made.json()["id"]

    before_offer = run(count_of(EventKind.offer_sent, target["id"]))
    r = c.post(
        "/offers",
        headers=auth(tok),
        json={
            "listing_id": target["id"],
            "offered_listing_ids": [mine],
            "cash_delta_minor": 0,
            "currency": "UZS",
        },
    )
    check("taklif yuborildi", r.status_code == 201, r.text[:100])
    check(
        "taklif hodisasi yozildi",
        run(count_of(EventKind.offer_sent, target["id"])) == before_offer + 1,
        "voronkaning uchinchi bosqichi",
    )


# --- tahlil so'rovlari ------------------------------------------------------


async def analytics_checks() -> None:
    async with SessionLocal() as db:
        gaps = await analytics.empty_searches(db, days=30)
        found = [g for g in gaps if g["q"] == f"zzqw-{RUN}"]
        check(
            "bo'sh qidiruv hisobotda ko'rinadi",
            len(found) == 1,
            f"{len(gaps)} ta satr",
        )
        check("nechta marta sanalgan", found[0]["times"] >= 1, str(found[0]))

        f = await analytics.funnel(db, days=30)
        check("voronkada ko'rsatishlar bor", f["impressions"] > 0, str(f))
        check("voronkada ochishlar bor", f["views"] > 0, str(f))
        check("voronkada takliflar bor", f["offers"] > 0, str(f))
        check(
            "bosqichlar orasidagi nisbat hisoblanadi",
            "views_rate" in f and f["views_rate"] is not None,
            str(f.get("views_rate")),
        )

        cold = await analytics.cold_listings(db, days=30, min_impressions=1)
        check("sovuq e'lonlar ro'yxati keladi", isinstance(cold, list), str(len(cold)))
        if cold:
            check(
                "CTR hisoblangan",
                all(0 <= row["ctr"] <= 100 for row in cold),
                str(cold[0]),
            )
            check(
                "eng sovug'i birinchi turadi",
                cold[0]["ctr"] <= cold[-1]["ctr"],
                f"{cold[0]['ctr']} ≤ {cold[-1]['ctr']}",
            )

        quality = await analytics.match_quality(db, days=30)
        check(
            "moslik sifati so'rovi ishlaydi",
            "shown" in quality and "dismiss_rate" in quality,
            str(quality),
        )

        by_tag = await analytics.search_gaps(db, days=30)
        check("turkum bo'yicha bo'shliq so'rovi ishlaydi", isinstance(by_tag, list))


run(analytics_checks())


# --- admin endpointlari -----------------------------------------------------

with httpx.Client(base_url=BASE, timeout=30) as c:
    mod, _ = login(c, MODERATOR_PHONE)
    plain, _ = login(c, "+998901235002")

    for path in (
        "/admin/analytics/funnel",
        "/admin/analytics/empty-searches",
        "/admin/analytics/cold-listings",
        "/admin/analytics/match-quality",
        "/admin/analytics/search-gaps",
    ):
        r = c.get(path, headers=auth(mod))
        check(f"{path} moderatorga ochiq", r.status_code == 200, str(r.status_code))

        r = c.get(path, headers=auth(plain))
        check(f"{path} boshqaga yopiq", r.status_code == 404, str(r.status_code))
