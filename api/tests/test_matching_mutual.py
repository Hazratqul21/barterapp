"""F01: o'zaro moslik — A ning narsasi B ga kerak VA B niki A ga.

1) Toza funksiya: ikki yo'nalish, valyuta, bayroq.
2) API: uch savdogar — o'zaro (B), bir tomonlama (C); o'zaro birinchi.
"""
import json, os, sys, urllib.error, urllib.request

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app.models.desire import Desire  # noqa: E402
from app.models.listing import Listing, ListingTag  # noqa: E402
from app.services.matching import (  # noqa: E402
    MUTUAL_BONUS, REASONS, RULES_VERSION, evaluate_pair,
)

BASE = "http://127.0.0.1:8010"


def ok(label, cond, extra=""):
    print(("PASS  " if cond else "FAIL  ") + label + (f"  — {extra}" if extra else ""))
    if not cond:
        sys.exit(1)


# ── 1. toza funksiya ──────────────────────────────────────────────────────────
def listing(tag, value, currency="UZS"):
    return Listing(tag=tag, value_minor=value, currency=currency)


def want(category):
    return Desire(category=category, will_add_cash=False, wants_cash=False)


laptop = listing(ListingTag.electronics, 1_000_000_00)
rice = listing(ListingTag.agri, 1_000_000_00)
kw = dict(distance_km=10.0, their_rating=None, their_verified=True)

v = evaluate_pair(laptop, rice, my_desires=[want(ListingTag.agri)],
                  their_desires=[want(ListingTag.electronics)], **kw)
ok("ikki tomon xohlasa — mutual", v is not None and v.mutual)
ok("sabablar: mutual, named_category, value_close, nearby, verified",
   v.reasons == ["mutual", "named_category", "value_close", "nearby", "verified"],
   str(v.reasons))
ok("barcha sabab kodlari ro'yxatda", set(v.reasons) <= set(REASONS))

one = evaluate_pair(laptop, rice, my_desires=[want(ListingTag.agri)],
                    their_desires=[want(ListingTag.livestock)], **kw)
ok("ular boshqa narsa xohlasa — bir tomonlama", one is not None and not one.mutual)
ok("o'zaro moslik bonus oladi", v.score == min(100, one.score + MUTUAL_BONUS),
   f"{v.score} vs {one.score}")

ok("men xohlamagan narsa — moslik emas",
   evaluate_pair(laptop, rice, my_desires=[want(ListingTag.transport)],
                 their_desires=[want(ListingTag.electronics)], **kw) is None)

usd_rice = listing(ListingTag.agri, 1_000_00, currency="USD")
ok("har xil valyutalar solishtirilmaydi",
   evaluate_pair(laptop, usd_rice, my_desires=[want(ListingTag.agri)],
                 their_desires=[want(ListingTag.electronics)], **kw) is None)

off = evaluate_pair(laptop, rice, my_desires=[want(ListingTag.agri)],
                    their_desires=[want(ListingTag.electronics)],
                    mutual_enabled=False, **kw)
ok("bayroq o'chiq — eski bir tomonlama xatti-harakat",
   off is not None and not off.mutual and "mutual" not in off.reasons)


# ── 2. API ────────────────────────────────────────────────────────────────────
def call(method, path, body=None, token=None):
    req = urllib.request.Request(BASE + path, method=method)
    req.add_header("Accept-Language", "uz")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, data) as r:
            return r.status, json.loads(r.read() or b"null")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"null")


def login(phone):
    _, r = call("POST", "/auth/otp/request", {"phone": phone})
    _, t = call("POST", "/auth/otp/verify", {"phone": phone, "code": r["debug_code"]})
    return t["access_token"]


def tri(v):
    return {"uz": v, "ru": v, "en": v}


def post(token, tag, title, wants_category):
    body = {
        "tag": tag,
        "title": tri(title),
        "description": tri(title),
        "image_alt": tri(title),
        "category": tri(title),
        "condition": tri("Yaxshi"),
        "quantity": tri("1"),
        "wants_summary": tri("x"),
        "wants": [tri("x")],
        "desires": [{"category": wants_category, "will_add_cash": False,
                     "wants_cash": False}],
        "photos": [],
        "value": {"minor": 900_000_000, "currency": "UZS"},
        "cash_ok": False,
    }
    st, created = call("POST", "/listings", body, token=token)
    ok(f"e'lon joylandi: {title}", st == 201, str(created)[:200])
    return created["id"]


a = login("+998901120001")
b = login("+998901120002")
c = login("+998901120003")
b_id = post(b, "agri", "F01 Guruch", "electronics")    # o'zaro
c_id = post(c, "agri", "F01 Bug'doy", "livestock")     # bir tomonlama
# A oxirida: joylash mosliklarni darhol qayta hisoblaydi (force), B va C
# allaqachon bozorda.
post(a, "electronics", "F01 Noutbuk", "agri")

st, matches = call("GET", "/matches", token=a)
ok("mosliklar keldi", st == 200 and isinstance(matches, list), str(matches)[:200])
by_listing = {m["theirs"]["id"]: m for m in matches}
ok("B topildi", b_id in by_listing)
ok("C topildi", c_id in by_listing)

mb, mc = by_listing[b_id], by_listing[c_id]
ok("B — o'zaro", mb["mutual"] is True and "mutual" in mb["reason_codes"])
ok("C — bir tomonlama", mc["mutual"] is False and "mutual" not in mc["reason_codes"])
ok("qoidalar versiyasi yozilgan", mb["rules_version"] == RULES_VERSION)
ok("o'zaro moslik matni", "Ikki tomon" in mb["reason"], mb["reason"])

flags = [m["mutual"] for m in matches]
ok("o'zaro mosliklar ro'yxat boshida", flags == sorted(flags, reverse=True), str(flags))
ok("B, C dan oldin", matches.index(mb) < matches.index(mc))
