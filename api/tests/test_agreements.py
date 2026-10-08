"""F02: band qilish, ikki tomonlama tasdiq, nizo qoidalari, operator, muddat.

Toza bazada:  .venv/bin/python -m app.seed && .venv/bin/python tests/test_agreements.py
"""
import asyncio
import sys
import uuid
from datetime import UTC, datetime, timedelta
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import select, update  # noqa: E402

from app.db.session import SessionLocal  # noqa: E402
from app.models.agreement import Reservation  # noqa: E402
from app.models.user import User  # noqa: E402

BASE = "http://127.0.0.1:8010"
RUN = f"{uuid.uuid4().int % 90 + 10}"  # ikki raqam: telefon va nomlar uchun

_loop = asyncio.new_event_loop()
asyncio.set_event_loop(_loop)
run = _loop.run_until_complete


def check(label, ok, extra=""):
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f"  — {extra}" if extra else ""))
    if not ok:
        raise SystemExit(1)


def tri(v):
    return {"uz": v, "ru": v, "en": v}


async def db_exec(stmt):
    async with SessionLocal() as db:
        await db.execute(stmt)
        await db.commit()


c = httpx.Client(base_url=BASE, timeout=30)


def user(n):
    phone = f"+99890150{RUN}{n:02d}"
    code = c.post("/auth/otp/request", json={"phone": phone}).json()["debug_code"]
    tok = c.post("/auth/otp/verify", json={"phone": phone, "code": code}).json()[
        "access_token"
    ]
    h = {"Authorization": f"Bearer {tok}", "Accept-Language": "uz"}
    c.patch("/me", headers=h, json={"first_name": f"U{n}", "last_name": "T",
                                     "region": "Samarqand"})
    return h, phone


def listing(h, title, som=1_000_000):
    r = c.post("/listings", headers=h, json={
        "tag": "electronics", "title": tri(title), "description": tri(title),
        "image_alt": tri(title), "category": tri("x"), "condition": tri("x"),
        "quantity": tri("1"), "wants_summary": tri("x"), "wants": [tri("x")],
        "desires": [{"category": None, "will_add_cash": False, "wants_cash": False}],
        "photos": [], "value": {"minor": som * 100, "currency": "UZS"}, "cash_ok": True,
    })
    check(f"e'lon: {title}", r.status_code == 201, r.text[:160])
    return r.json()["id"]


def offer(h, wanted, mine):
    r = c.post("/offers", headers=h, json={
        "listing_id": wanted, "offered_listing_ids": [mine],
        "cash_delta_minor": 0, "message": "F02",
    })
    check("taklif yuborildi", r.status_code == 201, r.text[:160])
    return r.json()["id"]


def act(h, oid, action, **extra):
    return c.patch(f"/offers/{oid}", headers=h, json={"action": action, **extra})


def listing_status(lid):
    r = c.get(f"/listings/{lid}")
    return r.json().get("status") if r.status_code == 200 else f"http {r.status_code}"


# ── 1. qabul qilish band qiladi, raqib qabul qilolmaydi ──────────────────────
A, _ = user(1)
B, _ = user(2)
C, _ = user(3)
a1 = listing(A, f"A-noutbuk-{RUN}")
b1 = listing(B, f"B-telefon-{RUN}")
c1 = listing(C, f"C-planshet-{RUN}")

o_ab = offer(A, b1, a1)
o_cb = offer(C, b1, c1)   # raqib: o'sha telefon uchun

r = act(B, o_ab, "accept")
check("qabul qilindi", r.status_code == 200 and r.json()["status"] == "accepted", r.text[:200])
check("band qilish muddati bor", r.json()["reserved_until"] is not None)
check("ikkala e'lon band (in_negotiation)",
      listing_status(a1) == "in_negotiation" and listing_status(b1) == "in_negotiation",
      f"{listing_status(a1)} {listing_status(b1)}")

r = act(B, o_cb, "accept")
check("band e'lon uchun ikkinchi qabul — 409", r.status_code == 409, r.text[:200])
check("raqib e'loni band qilinmadi", listing_status(c1) == "active")

# ── 2. ikki tomonlama tasdiq; eski 'complete' yolg'iz yakunlay olmaydi ──────
r = act(A, o_ab, "complete")
check("bitta tasdiq — savdo hali yakunlanmagan",
      r.status_code == 200 and r.json()["status"] == "accepted"
      and r.json()["confirmed_by_me"] and not r.json()["confirmed_by_peer"], r.text[:200])
r = act(A, o_ab, "confirm")
check("takroriy tasdiq xato emas, baribir yakunlanmaydi",
      r.status_code == 200 and r.json()["status"] == "accepted")
r = act(B, o_ab, "confirm")
check("ikkinchi tasdiq — yakunlandi", r.json()["status"] == "completed", r.text[:200])
check("e'lonlar yopildi", listing_status(a1) == "completed" and listing_status(b1) == "completed")
offers_c = {o["id"]: o for o in c.get("/offers", headers=C).json()}
check("raqib taklif muddati tugadi", offers_c[o_cb]["status"] == "expired")

# ── 3. nizo: kichik summa, 'kelmadi' → qoida bo'yicha bekor ─────────────────
D, _ = user(4)
E, _ = user(5)
d1 = listing(D, f"D-{RUN}", som=500_000)
e1 = listing(E, f"E-{RUN}", som=500_000)
o_de = offer(D, e1, d1)
act(E, o_de, "accept")
r = act(D, o_de, "dispute")
check("sababsiz nizo — 422", r.status_code == 422, str(r.status_code))
r = act(D, o_de, "dispute", dispute_reason="no_show", dispute_note="Kelmadi")
j = r.json()
check("qoida bo'yicha avtomatik bekor", r.status_code == 200 and j["status"] == "refunded"
      and j["dispute"]["status"] == "resolved" and j["dispute"]["resolution"] == "cancel"
      and j["dispute"]["decided_by_rule"] == "auto_cancel:no_show", r.text[:300])
check("e'lonlar sotuvga qaytdi", listing_status(d1) == "active" and listing_status(e1) == "active")

# ── 4. katta summa → operator ───────────────────────────────────────────────
F, f_phone = user(6)
G, _ = user(7)
f1 = listing(F, f"F-traktor-{RUN}", som=60_000_000)
g1 = listing(G, f"G-mashina-{RUN}", som=60_000_000)
o_fg = offer(F, g1, f1)
act(G, o_fg, "accept")
r = act(F, o_fg, "dispute", dispute_reason="no_show")
j = r.json()
check("chegaradan katta — operatorga", j["status"] == "disputed"
      and j["dispute"]["status"] == "escalated" and j["dispute"]["decided_by_rule"] == "over_limit",
      r.text[:300])
check("nizoda band muddati to'xtatildi", j["reserved_until"] is None)

check("oddiy foydalanuvchi navbatni ko'ra olmaydi",
      c.get("/admin/disputes", headers=F).status_code == 404)  # 404: mavjudligini ham oshkor qilmaydi


async def make_moderator(phone):
    async with SessionLocal() as db:
        u = await db.scalar(select(User).where(User.phone == phone))
        u.is_moderator = True
        await db.commit()


M, m_phone = user(8)
run(make_moderator(m_phone))
queue = c.get("/admin/disputes", headers=M).json()
row = next((d for d in queue if d["offer_id"] == o_fg), None)
check("operator navbatida", row is not None and row["value_minor"] >= 6_000_000_000)
r = c.post(f"/admin/disputes/{row['id']}/resolve", headers=M,
           json={"resolution": "complete", "note": "Ikkala tomon bilan gaplashildi"})
check("operator hal qildi", r.status_code == 204, r.text[:200])
fg = {o["id"]: o for o in c.get("/offers", headers=F).json()}[o_fg]
check("savdo kuchda — yakunlandi", fg["status"] == "completed"
      and fg["dispute"]["decided_by_rule"] == "operator")
r = c.post(f"/admin/disputes/{row['id']}/resolve", headers=M,
           json={"resolution": "cancel", "note": "qayta"})
check("ikkinchi marta hal qilib bo'lmaydi", r.status_code == 409)

# ── 5. qoidalarni admin o'zgartiradi ─────────────────────────────────────────
before = c.get("/admin/dispute-rules", headers=M).json()
r = c.put("/admin/dispute-rules", headers=M, json={
    "reservation_hours": 48, "auto_max_value_minor": 100_000_000,
    "auto_cancel_reasons": ["no_show", "not_received"],
})
check("qoidalar saqlandi, versiya oshdi", r.status_code == 200
      and r.json()["version"] == before["version"] + 1, r.text[:200])
check("noto'g'ri qoida — 422", c.put("/admin/dispute-rules", headers=M, json={
    "reservation_hours": 0, "auto_max_value_minor": 1, "auto_cancel_reasons": [],
}).status_code == 422)
c.put("/admin/dispute-rules", headers=M, json={   # standartga qaytarish
    "reservation_hours": before["reservation_hours"],
    "auto_max_value_minor": before["auto_max_value_minor"],
    "auto_cancel_reasons": before["auto_cancel_reasons"],
})

# ── 6. muddat o'tsa — savdo bekor, e'lonlar qaytadi ─────────────────────────
H, _ = user(9)
I, _ = user(10)
h1 = listing(H, f"H-{RUN}")
i1 = listing(I, f"I-{RUN}")
o_hi = offer(H, i1, h1)
act(I, o_hi, "accept")
run(db_exec(
    update(Reservation)
    .where(Reservation.offer_id == uuid.UUID(o_hi))
    .values(expires_at=datetime.now(UTC) - timedelta(minutes=1))
))
hi = {o["id"]: o for o in c.get("/offers", headers=H).json()}[o_hi]
check("muddati o'tgan kelishuv — expired", hi["status"] == "expired", hi["status"])
check("e'lonlar sotuvga qaytdi (muddat)", listing_status(h1) == "active"
      and listing_status(i1) == "active")

# ── 7. parallel qabul: bitta e'lon, ikki taklif, bir vaqtda ─────────────────
J, _ = user(11)
K, _ = user(12)
L, _ = user(13)
j1 = listing(J, f"J-{RUN}")
k1 = listing(K, f"K-{RUN}")
l1 = listing(L, f"L-{RUN}")
o_kj = offer(K, j1, k1)
o_lj = offer(L, j1, l1)


async def race():
    async with httpx.AsyncClient(base_url=BASE, timeout=30) as ac:
        return await asyncio.gather(
            ac.patch(f"/offers/{o_kj}", headers=J, json={"action": "accept"}),
            ac.patch(f"/offers/{o_lj}", headers=J, json={"action": "accept"}),
        )


codes = sorted(r.status_code for r in run(race()))
check("parallel qabul: biri 200, biri 409", codes == [200, 409], str(codes))
statuses = {listing_status(k1), listing_status(l1)}
check("faqat bitta raqib e'loni band", statuses == {"active", "in_negotiation"}, str(statuses))
