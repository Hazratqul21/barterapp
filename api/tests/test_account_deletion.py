"""Hisobni o'chirish.

Do'konlar buni talab qiladi (Apple 5.1.1(v), Google Play), lekin talab
"qatorni o'chir" degani emas. `users.id` ga o'nlab jadval CASCADE bilan
bog'langan; qator o'chirilsa yakunlangan savdolar, suhbatlar va sharhlar
ham ketadi — ularning yarmi esa **qarshi tomonga** tegishli.

Shuning uchun bu sinovning asosiy savoli ikkitadan iborat:

1. O'chirgan odamdan hech narsa qolmadimi (ism, telefon, surat, kirish,
   e'lonlar, ochiq takliflar)?
2. **Qarshi tomonda** hamma narsa joyidami (savdo tarixi, sharhlar,
   yozishmalar)?

Ikkinchisi muhimroq: birinchisi buzilsa maxfiylik muammosi, ikkinchisi
buzilsa boshqa odamning mehnati yo'qoladi.
"""

import asyncio
import sys
import uuid
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.db.session import SessionLocal  # noqa: E402
from app.models.device import Device  # noqa: E402
from app.models.favorite import Favorite  # noqa: E402
from app.models.listing import Listing, ListingStatus  # noqa: E402
from app.models.offer import Message, Offer, OfferStatus  # noqa: E402
from app.models.review import Review  # noqa: E402
from app.models.user import RefreshToken, User  # noqa: E402

BASE = "http://127.0.0.1:8010"

_loop = asyncio.new_event_loop()
asyncio.set_event_loop(_loop)
run = _loop.run_until_complete


def check(label: str, ok: bool, extra: str = "") -> None:
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f"  → {extra}" if extra else ""))
    if not ok:
        raise SystemExit(1)


def login(c: httpx.Client, phone: str) -> tuple[str, str, str]:
    code = c.post("/auth/otp/request", json={"phone": phone}).json()["debug_code"]
    body = c.post("/auth/otp/verify", json={"phone": phone, "code": code}).json()
    me = c.get("/me", headers={"Authorization": f"Bearer {body['access_token']}"}).json()
    return body["access_token"], body["refresh_token"], me["id"]


def auth(t: str) -> dict:
    return {"Authorization": f"Bearer {t}"}


def tri(u, ru, en):
    return {"uz": u, "ru": ru, "en": en}


def new_listing(c: httpx.Client, token: str, title: str) -> str:
    r = c.post(
        "/listings",
        headers=auth(token),
        json={
            "tag": "agri",
            "title": tri(title, title, title),
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
    assert r.status_code == 201, r.text[:200]
    return r.json()["id"]


# `+998` dan keyin aynan 9 raqam (server shakli: ^\+998\d{9}$).
# Tasodifiy, chunki sinov o'chirilgan hisob qoldiradi va ikkinchi yurishda
# o'sha raqam boshqa holatda bo'lardi.
def _phone(prefix: str) -> str:
    return f"+998{prefix}{uuid.uuid4().int % 10_000_000:07d}"


LEAVER = _phone("70")
PEER = _phone("71")

with httpx.Client(base_url=BASE, timeout=30) as c:
    leaver, leaver_refresh, leaver_id = login(c, LEAVER)
    peer, _, peer_id = login(c, PEER)

    # Ketayotgan odamga tanish qiyofa beramiz — keyin uning izi qolmaganini
    # tekshirish uchun.
    c.patch(
        "/me",
        headers=auth(leaver),
        json={
            "first_name": "Ketuvchi",
            "last_name": "Foydalanuvchi",
            "region": "Samarqand",
            "address": "Ko'cha 1",
            "avatar_url": "https://example.uz/a.jpg",
        },
    )

    mine = new_listing(c, leaver, "Ketuvchining eloni")
    theirs = new_listing(c, peer, "Qarshi tomon eloni")

    c.post("/devices", headers=auth(leaver), json={"token": f"tok-{uuid.uuid4().hex}", "platform": "ios"})
    c.post(f"/listings/{theirs}/favorite", headers=auth(leaver))

    # --- yakunlangan savdo: bu qolishi SHART ---------------------------------

    made = c.post(
        "/offers",
        headers=auth(leaver),
        json={
            "listing_id": theirs,
            "offered_listing_ids": [mine],
            "cash_delta_minor": 0,
            "currency": "UZS",
            "message": "Almashamizmi?",
        },
    )
    check("taklif yuborildi", made.status_code == 201, made.text[:120])
    done_offer = made.json()["id"]

    c.patch(f"/offers/{done_offer}", headers=auth(peer), json={"action": "accept"})
    c.patch(f"/offers/{done_offer}", headers=auth(peer), json={"action": "complete"})
    # F02: ikkala tomon tasdiqlaydi.
    r = c.patch(f"/offers/{done_offer}", headers=auth(leaver), json={"action": "confirm"})
    check("savdo yakunlandi", r.status_code == 200 and r.json()["status"] == "completed",
          r.text[:120])

    r = c.post(
        "/reviews",
        headers=auth(peer),
        json={"offer_id": done_offer, "rating": 5, "body": "Yaxshi savdogar."},
    )
    check("qarshi tomon sharh yozdi", r.status_code == 201, r.text[:120])

    # --- ochiq savdo: bu bekor qilinishi kerak -------------------------------

    another = new_listing(c, leaver, "Ikkinchi elon")
    open_target = new_listing(c, peer, "Ochiq maqsad")
    r = c.post(
        "/offers",
        headers=auth(leaver),
        json={
            "listing_id": open_target,
            "offered_listing_ids": [another],
            "cash_delta_minor": 0,
            "currency": "UZS",
        },
    )
    open_offer = r.json()["id"]

    # --- o'chirish -----------------------------------------------------------

    r = c.request("DELETE", "/me", headers=auth(leaver), json={"confirm": False})
    check("tasdiqsiz o'chirilmaydi", r.status_code == 400, str(r.status_code))

    r = c.request("DELETE", "/me", json={"confirm": True})
    check("autentifikatsiyasiz o'chirilmaydi", r.status_code == 401, str(r.status_code))

    r = c.request("DELETE", "/me", headers=auth(leaver), json={"confirm": True})
    check("hisob o'chirildi", r.status_code == 204, str(r.status_code))

    # --- kirish yopildi ------------------------------------------------------

    r = c.get("/me", headers=auth(leaver))
    check(
        "eski token darhol ishlamaydi",
        r.status_code == 401,
        f"{r.status_code} — aks holda hisob yana bir soat tirik bo'lardi",
    )

    r = c.post("/auth/refresh", json={"refresh_token": leaver_refresh})
    check("refresh token ham bekor", r.status_code == 401, str(r.status_code))

    r = c.get("/listings", headers=auth(leaver), params={"limit": 5})
    check("lenta mehmon sifatida ochiladi", r.status_code == 200, str(r.status_code))

    # --- bozordan chiqdi -----------------------------------------------------

    feed = c.get("/listings", headers=auth(peer), params={"limit": 50}).json()
    check(
        "e'lonlari lentadan yo'qoldi",
        mine not in [i["id"] for i in feed["items"]]
        and another not in [i["id"] for i in feed["items"]],
    )

    offers = c.get("/offers", headers=auth(peer)).json()
    still_open = [o for o in offers if o["id"] == open_offer]
    check(
        "ochiq taklif bekor qilindi",
        still_open and still_open[0]["status"] == "expired",
        f"{still_open[0]['status'] if still_open else 'topilmadi'} — "
        "qarshi tomon kelmaydigan javobni kutmasin",
    )

    # --- QARSHI TOMONDA HAMMA NARSA JOYIDA -----------------------------------

    done = [o for o in offers if o["id"] == done_offer]
    check(
        "yakunlangan savdo qarshi tomonda qoldi",
        done and done[0]["status"] == "completed",
        "ikkala tomonning tarixi",
    )

    reviews = c.get(f"/users/{leaver_id}/reviews").json()
    check(
        "yozilgan sharh yo'qolmadi",
        any(r["body"] == "Yaxshi savdogar." for r in reviews),
        f"{len(reviews)} ta — boshqa odamning mehnati",
    )

    threads = c.get("/conversations", headers=auth(peer)).json()
    check("suhbat qarshi tomonda qoldi", len(threads) >= 1, str(len(threads)))

    if threads:
        thread = c.get(f"/conversations/{threads[0]['id']}", headers=auth(peer)).json()
        check(
            "xabarlar joyida",
            any(m["body"] == "Almashamizmi?" for m in thread.get("messages", [])),
            "qarshi tomon o'z yozishmasini yo'qotmaydi",
        )

    # --- tashqaridan ismsiz ko'rinadi ----------------------------------------

    profile = c.get(f"/users/{leaver_id}")
    check("profil hali ham ochiladi", profile.status_code == 200, str(profile.status_code))
    check(
        "o'chirilgani belgilangan",
        profile.json().get("is_deleted") is True,
        str(profile.json().get("is_deleted")),
    )
    check(
        "ismi ko'rinmaydi",
        profile.json()["name"] == "—",
        f"{profile.json()['name']} — mijoz o'z tilida yozadi",
    )

    # --- telefon bo'shatildi -------------------------------------------------

    again, _, new_id = login(c, LEAVER)
    check(
        "o'sha raqam bilan qayta ro'yxatdan o'tish mumkin",
        again is not None,
        "raqam bo'shatilmasa kirish umuman imkonsiz bo'lardi",
    )
    check(
        "bu yangi hisob, eskisi emas",
        new_id != leaver_id,
        f"{new_id} ≠ {leaver_id}",
    )

    me = c.get("/me", headers=auth(again)).json()
    check(
        "yangi hisob toza",
        not me["name"].strip() and me["region"] is None,
        f"name={me['name']!r} region={me['region']!r}",
    )


# --- bazadagi holat ---------------------------------------------------------


async def db_checks() -> None:
    from sqlalchemy import func, select

    async with SessionLocal() as db:
        gone = uuid.UUID(leaver_id)
        user = await db.get(User, gone)

        check("foydalanuvchi qatori saqlanib qoldi", user is not None)
        check("o'chirilgan deb belgilangan", user.deleted_at is not None)

        for field in ("first_name", "last_name"):
            check(f"{field} tozalandi", getattr(user, field) == "")
        for field in ("handle", "avatar_url", "cover_url", "bio", "region",
                      "district", "address", "latitude", "longitude", "tax_id"):
            check(f"{field} tozalandi", getattr(user, field) is None)

        check(
            "telefon raqami saqlanmadi",
            not user.phone.startswith("+998"),
            f"{user.phone} — qayta ro'yxatdan o'tish uchun bo'shatilgan",
        )
        check("moderator huquqi olindi", user.is_moderator is False)
        check("tasdiq belgisi olindi", user.is_verified is False)

        live_tokens = await db.scalar(
            select(func.count())
            .select_from(RefreshToken)
            .where(RefreshToken.user_id == gone, RefreshToken.revoked_at.is_(None))
        )
        check("ochiq sessiya qolmadi", live_tokens == 0, str(live_tokens))

        for model, name in ((Device, "qurilma"), (Favorite, "saqlangan")):
            left = await db.scalar(
                select(func.count()).select_from(model).where(model.user_id == gone)
            )
            check(f"{name} o'chirildi", left == 0, str(left))

        live_listings = await db.scalar(
            select(func.count())
            .select_from(Listing)
            .where(
                Listing.owner_id == gone,
                Listing.status.in_(
                    (ListingStatus.active, ListingStatus.draft,
                     ListingStatus.in_negotiation)
                ),
            )
        )
        check("faol e'lon qolmadi", live_listings == 0, str(live_listings))

        # Va endi eng muhimi — qarshi tomonning narsalari.

        kept = await db.scalar(
            select(func.count())
            .select_from(Offer)
            .where(
                (Offer.from_user_id == gone) | (Offer.to_user_id == gone),
                Offer.status == OfferStatus.completed,
            )
        )
        check(
            "yakunlangan savdo bazada qoldi",
            kept >= 1,
            f"{kept} ta — CASCADE bo'lganda nolga tushardi",
        )

        about = await db.scalar(
            select(func.count()).select_from(Review).where(Review.about_id == gone)
        )
        check("u haqidagi sharh qoldi", about >= 1, str(about))

        messages = await db.scalar(
            select(func.count()).select_from(Message).where(Message.sender_id == gone)
        )
        check(
            "yozgan xabarlari qoldi",
            messages >= 1,
            f"{messages} ta — qarshi tomonning yozishmasi",
        )


run(db_checks())
