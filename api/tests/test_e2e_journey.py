"""End-to-end: ikki odamning butun yo'li.

Boshqa sinovlar bittadan bo'lakni tekshiradi. Bu esa **butun mahsulotni**
boshidan oxirigacha yuritadi — ro'yxatdan o'tishdan sharh yozishgacha —
va har bosqichda holat qarshi tomonda ham to'g'ri ko'rinishini tasdiqlaydi.

Nega kerak: har bir bo'lak alohida ishlashi mumkin, lekin ular orasidagi
o'tishlar buzilgan bo'lishi mumkin. Masalan taklif yakunlanganda e'lon
lentadan chiqishi, raqib takliflar bekor bo'lishi va ikkala tomonning
statistikasi o'zgarishi kerak — bularning hech biri bitta endpointga
tegishli emas.
"""

import asyncio
import io
import sys
import uuid
from pathlib import Path

import httpx
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.db.session import SessionLocal  # noqa: E402
from app.models.user import User  # noqa: E402

BASE = "http://127.0.0.1:8010"
MODERATOR_PHONE = "+998901234122"

_loop = asyncio.new_event_loop()
asyncio.set_event_loop(_loop)
run = _loop.run_until_complete

STEP = 0


def step(title: str) -> None:
    global STEP
    STEP += 1
    print(f"\n── {STEP}. {title} " + "─" * max(0, 52 - len(title)))


def check(label: str, ok: bool, extra: str = "") -> None:
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f"  → {extra}" if extra else ""))
    if not ok:
        raise SystemExit(1)


def phone(p: str) -> str:
    return f"+998{p}{uuid.uuid4().int % 10_000_000:07d}"


def tri(v: str) -> dict:
    return {"uz": v, "ru": f"{v} ru", "en": f"{v} en"}


def auth(t: str) -> dict:
    return {"Authorization": f"Bearer {t}"}


async def make_moderator() -> None:
    from sqlalchemy import select

    async with SessionLocal() as db:
        user = await db.scalar(select(User).where(User.phone == MODERATOR_PHONE))
        user.is_moderator = True
        await db.commit()


run(make_moderator())

FARMER = phone("60")
SHOP = phone("61")

with httpx.Client(base_url=BASE, timeout=40) as c:

    # ═══════════════════════════════════════════════════════════════════
    step("Ro'yxatdan o'tish")

    r = c.post("/auth/otp/request", json={"phone": FARMER})
    check("kod so'raldi", r.status_code == 200, str(r.status_code))
    code = r.json()["debug_code"]

    r = c.post("/auth/otp/verify", json={"phone": FARMER, "code": code})
    check("kod tasdiqlandi", r.status_code == 200, str(r.status_code))
    check("yangi foydalanuvchi deb belgilandi", r.json()["is_new_user"] is True)

    farmer = r.json()["access_token"]
    farmer_refresh = r.json()["refresh_token"]

    me = c.get("/me", headers=auth(farmer)).json()
    farmer_id = me["id"]
    check("ism hali bo'sh", not me["name"].strip(), repr(me["name"]))
    check("telefon tasdiqlandi", me["trust_score"] >= 20, str(me["trust_score"]))

    # Ikkinchi tomon.
    code = c.post("/auth/otp/request", json={"phone": SHOP}).json()["debug_code"]
    body = c.post("/auth/otp/verify", json={"phone": SHOP, "code": code}).json()
    shop = body["access_token"]
    shop_id = c.get("/me", headers=auth(shop)).json()["id"]

    # ═══════════════════════════════════════════════════════════════════
    step("Profilni to'ldirish")

    r = c.patch(
        "/me",
        headers=auth(farmer),
        json={"first_name": "Anvar", "last_name": "Qodirov", "region": "Samarqand"},
    )
    check("profil saqlandi", r.status_code == 200, str(r.status_code))

    me = r.json()
    check("ism ko'rinadi", me["name"] == "Anvar Qodirov", me["name"])
    check(
        "viloyat koordinatani ham beradi",
        me["location"] is not None,
        "masofa moslik balining 30% i — hududsiz hisob hech qachon yaqin chiqmaydi",
    )

    c.patch(
        "/me",
        headers=auth(shop),
        json={"first_name": "Dilshod", "last_name": "Rasulov", "region": "Toshkent shahri"},
    )

    # ═══════════════════════════════════════════════════════════════════
    step("Surat yuklash")

    buf = io.BytesIO()
    Image.new("RGB", (2400, 1800), (40, 140, 110)).save(buf, format="JPEG")

    r = c.post(
        "/uploads",
        headers=auth(farmer),
        files={"file": ("hosil.jpg", buf.getvalue(), "image/jpeg")},
    )
    check("surat yuklandi", r.status_code == 201, r.text[:120])

    photo = r.json()
    check(
        "surat kichraytirildi",
        max(photo["width"], photo["height"]) <= 1600,
        f"{photo['width']}x{photo['height']} — lenta mobil internetda ochilsin",
    )
    check("surat ochiladi", c.get(photo["url"]).status_code == 200)

    # ═══════════════════════════════════════════════════════════════════
    step("E'lon joylash")

    r = c.post(
        "/listings",
        headers=auth(farmer),
        json={
            "tag": "agri",
            "title": tri("Qishki bug'doy, 3 tonna"),
            "description": tri("Yangi hosil, quruq saqlangan"),
            "image_alt": tri("Bug'doy qoplari"),
            "category": tri("Don"),
            "condition": tri("Yangi"),
            "quantity": tri("3 tonna"),
            "wants_summary": tri("Texnika yoki chorva"),
            "wants": [tri("Traktor"), tri("Sigir")],
            "desires": [{"category": "machinery", "will_add_cash": True, "wants_cash": False}],
            "photos": [photo["url"]],
            "value": {"minor": 4500000000, "currency": "UZS"},
            "cash_ok": True,
        },
    )
    check("e'lon joylandi", r.status_code == 201, r.text[:200])
    wheat = r.json()["id"]
    check("surat biriktirildi", r.json()["image_url"] == photo["url"])

    r = c.post(
        "/listings",
        headers=auth(shop),
        json={
            "tag": "machinery",
            "title": tri("Mini traktor"),
            "description": tri("Ishchi holatda"),
            "image_alt": tri("Traktor"),
            "category": tri("Texnika"),
            "condition": tri("Ishlatilgan"),
            "quantity": tri("1 dona"),
            "wants_summary": tri("Don mahsulotlari"),
            "wants": [tri("Bug'doy")],
            "desires": [{"category": "agri", "will_add_cash": False, "wants_cash": False}],
            "photos": [],
            "value": {"minor": 5000000000, "currency": "UZS"},
            "cash_ok": True,
        },
    )
    tractor = r.json()["id"]

    # ═══════════════════════════════════════════════════════════════════
    step("Lentada topish")

    feed = c.get("/listings", headers=auth(shop), params={"limit": 50}).json()
    ids = [i["id"] for i in feed["items"]]
    check("boshqaning e'loni lentada", wheat in ids)
    check("o'z e'loni lentada yo'q", tractor not in ids, "u profilda turadi")

    found = c.get(
        "/listings", headers=auth(shop), params={"q": "bug'doy", "limit": 20}
    ).json()
    check("qidiruv topadi", wheat in [i["id"] for i in found["items"]])

    ru = c.get(
        "/listings",
        headers=auth(shop),
        params={"q": "bug'doy", "limit": 20},
        headers_extra=None,
    ) if False else c.get(
        "/listings",
        headers={**auth(shop), "Accept-Language": "ru"},
        params={"q": "bug'doy", "limit": 20},
    ).json()
    check(
        "o'zbekcha so'z ruscha interfeysda ham topiladi",
        wheat in [i["id"] for i in ru["items"]],
        "mahsulot nomini yarim mamlakat o'zbekcha yozadi",
    )
    if ru["items"]:
        card = next(i for i in ru["items"] if i["id"] == wheat)
        check("javob ruschada keldi", card["title"].endswith("ru"), card["title"])

    cheap = c.get(
        "/listings", headers=auth(shop), params={"sort": "cheap", "limit": 50}
    ).json()
    values = [i["value"]["minor"] for i in cheap["items"]]
    check("saralash ishlaydi", values == sorted(values))

    # ═══════════════════════════════════════════════════════════════════
    step("Saqlash va ko'rish")

    c.post(f"/listings/{wheat}/favorite", headers=auth(shop))
    saved = c.get("/favorites", headers=auth(shop)).json()
    check("saqlanganlar ro'yxatida", wheat in [i["id"] for i in saved["items"]])

    detail = c.get(f"/listings/{wheat}", headers=auth(shop)).json()
    check("detalda is_favorite belgilangan", detail["is_favorite"] is True)
    check("gallereya bor", len(detail["gallery"]) == 1)
    check("istaklar ro'yxati bor", len(detail["wants"]) == 2, str(detail["wants"]))

    # ═══════════════════════════════════════════════════════════════════
    step("Taklif yuborish")

    r = c.post(
        "/offers",
        headers=auth(shop),
        json={
            "listing_id": wheat,
            "offered_listing_ids": [tractor],
            "cash_delta_minor": 500000000,
            "currency": "UZS",
            "message": "Traktorni bug'doyga almashamizmi?",
        },
    )
    check("taklif yuborildi", r.status_code == 201, r.text[:200])
    offer = r.json()["id"]
    check("holati pending", r.json()["status"] == "pending")

    inbox = c.get("/offers", headers=auth(farmer)).json()
    check("taklif egasiga yetdi", offer in [o["id"] for o in inbox])

    notes = c.get("/notifications", headers=auth(farmer)).json()
    check("bildirishnoma keldi", any(o["kind"] == "offer" for o in notes), str(len(notes)))

    # ═══════════════════════════════════════════════════════════════════
    step("Suhbat")

    threads = c.get("/conversations", headers=auth(farmer)).json()
    check("suhbat ochildi", len(threads) >= 1)
    thread = threads[0]["id"]

    detail = c.get(f"/conversations/{thread}", headers=auth(farmer)).json()
    check(
        "taklifdagi xabar suhbatda",
        any("almashamizmi" in m["body"].lower() for m in detail["messages"]),
    )

    r = c.post(
        f"/conversations/{thread}/messages",
        headers=auth(farmer),
        json={"body": "Ha, lekin yetkazib berish kerak."},
    )
    check("javob yozildi", r.status_code == 201, str(r.status_code))

    peer_view = c.get(f"/conversations/{thread}", headers=auth(shop)).json()
    check(
        "qarshi tomon xabarni ko'rdi",
        any("yetkazib" in m["body"] for m in peer_view["messages"]),
    )

    # ═══════════════════════════════════════════════════════════════════
    step("Savdoni yakunlash")

    r = c.patch(f"/offers/{offer}", headers=auth(farmer), json={"action": "accept"})
    check("taklif qabul qilindi", r.status_code == 200, r.text[:150])
    check("holat accepted", r.json()["status"] == "accepted")

    r = c.patch(f"/offers/{offer}", headers=auth(farmer), json={"action": "complete"})
    check("savdo yakunlandi", r.status_code == 200, r.text[:150])
    check("holat completed", r.json()["status"] == "completed")

    feed = c.get("/listings", headers=auth(shop), params={"limit": 50}).json()
    check(
        "yakunlangan e'lon lentadan chiqdi",
        wheat not in [i["id"] for i in feed["items"]],
        "narsa bozorda yo'q — u allaqachon almashtirilgan",
    )

    saved = c.get("/favorites", headers=auth(shop)).json()
    check(
        "saqlanganlardan ham tushdi",
        wheat not in [i["id"] for i in saved["items"]],
        "o'lik karta ko'rsatilmaydi",
    )

    # ═══════════════════════════════════════════════════════════════════
    step("Sharh va reyting")

    r = c.post(
        "/reviews",
        headers=auth(shop),
        json={"offer_id": offer, "rating": 5, "body": "Vaqtida yetkazdi, rahmat."},
    )
    check("sharh yozildi", r.status_code == 201, r.text[:150])

    r = c.post(
        "/reviews",
        headers=auth(shop),
        json={"offer_id": offer, "rating": 1, "body": "Ikkinchi marta"},
    )
    check("bitta savdoga ikki sharh yozilmaydi", r.status_code == 409, str(r.status_code))

    profile = c.get(f"/users/{farmer_id}").json()
    check("reyting paydo bo'ldi", profile["rating"] == 5.0, str(profile["rating"]))
    check("sharh soni", profile["review_count"] == 1, str(profile["review_count"]))
    check("yakunlangan savdo sanaldi", profile["deals"] >= 1, str(profile["deals"]))

    reviews = c.get(f"/users/{farmer_id}/reviews").json()
    check("sharh ommaviy ko'rinadi", any("rahmat" in r["body"] for r in reviews))

    # ═══════════════════════════════════════════════════════════════════
    step("Tahlil hodisalari yozildimi")

    mod_code = c.post("/auth/otp/request", json={"phone": MODERATOR_PHONE}).json()["debug_code"]
    mod = c.post(
        "/auth/otp/verify", json={"phone": MODERATOR_PHONE, "code": mod_code}
    ).json()["access_token"]

    funnel = c.get("/admin/analytics/funnel?days=1", headers=auth(mod)).json()
    check("ko'rishlar yozildi", funnel["views"] > 0, str(funnel["views"]))
    check("takliflar yozildi", funnel["offers"] > 0, str(funnel["offers"]))
    check("yakunlangan savdo yozildi", funnel["completed"] > 0, str(funnel["completed"]))
    check(
        "voronka nisbatlari hisoblandi",
        funnel.get("offers_rate") is not None,
        f"views→favorites→offers: {funnel.get('views')}→{funnel.get('favorites')}→{funnel.get('offers')}",
    )

    # ═══════════════════════════════════════════════════════════════════
    step("Sessiyani yangilash va chiqish")

    r = c.post("/auth/refresh", json={"refresh_token": farmer_refresh})
    check("token yangilandi", r.status_code == 200, str(r.status_code))
    fresh = r.json()

    check("yangi token ishlaydi", c.get("/me", headers=auth(fresh["access_token"])).status_code == 200)
    check(
        "eski refresh ikkinchi marta ishlamaydi",
        c.post("/auth/refresh", json={"refresh_token": farmer_refresh}).status_code == 401,
        "rotatsiya: bir marta ishlatiladi",
    )

    r = c.post("/auth/logout", json={"refresh_token": fresh["refresh_token"]})
    check("chiqildi", r.status_code == 204, str(r.status_code))
    check(
        "chiqqandan keyin refresh ishlamaydi",
        c.post("/auth/refresh", json={"refresh_token": fresh["refresh_token"]}).status_code == 401,
    )

print("\n" + "=" * 60)
print(f"END-TO-END: {STEP} bosqich, butun yo'l ishlaydi")
