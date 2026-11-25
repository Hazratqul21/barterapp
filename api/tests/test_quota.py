"""Bepul e'lonlar, birinchi foydalanuvchilar aksiyasi va Payme kaliti panelda.

- Kvota va aksiya yangi hisobga beriladi; joy tugagach oddiy kvota.
- Parallel ro'yxatdan o'tishda joydan ortiq berilmaydi.
- Oldin kirganlarga tarqatish takror berilmaydi va kreditni kamaytirmaydi.
- Biznes hisob to'lovdan ozod emas, moderator ozod.
- Payme kaliti qaytmaydi, paneldagi `.env` dan ustun, o'chirilsa `.env` ga qaytadi.
"""

import asyncio
import base64
import sys
import uuid
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import select, update  # noqa: E402

from app.core.config import settings  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402
from app.models.user import User, UserType  # noqa: E402

BASE = "http://127.0.0.1:8010"
MOD = "+998901234122"
B = "/admin/billing"
_loop = asyncio.new_event_loop()
asyncio.set_event_loop(_loop)
run = _loop.run_until_complete
_n = iter(range(100, 999))


def phone() -> str:
    return f"+99890555{next(_n):04d}"


def check(label: str, ok: bool, extra: str = "") -> None:
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f"  → {extra}" if extra else ""))
    if not ok:
        raise SystemExit(1)


def login(c: httpx.Client, p: str) -> dict:
    code = c.post("/auth/otp/request", json={"phone": p}).json()["debug_code"]
    t = c.post("/auth/otp/verify", json={"phone": p, "code": code}).json()["access_token"]
    return {"Authorization": f"Bearer {t}"}


async def set_user(p: str, **values) -> None:
    async with SessionLocal() as db:
        await db.execute(update(User).where(User.phone == p).values(**values))
        await db.commit()


async def get(p: str) -> User:
    async with SessionLocal() as db:
        return await db.scalar(select(User).where(User.phone == p))


def left(c, h) -> int:
    return c.get("/payments/status", headers=h).json()["free_listings_left"]


def body(title: str) -> dict:
    t = {"uz": title}
    return {"tag": "agri", "title": t, "description": t, "image_alt": t, "category": t,
            "condition": t, "quantity": t, "wants_summary": t,
            "value": {"minor": 100000, "currency": "UZS"}}


def payme(c, key: str) -> int | None:
    token = base64.b64encode(f"Paycom:{key}".encode()).decode()
    r = c.post("/payments/payme", headers={"Authorization": f"Basic {token}"},
               json={"id": 1, "method": "CheckPerformTransaction",
                     "params": {"amount": 1, "account": {"order_id": str(uuid.uuid4())}}})
    return r.json()["error"]["code"]


with httpx.Client(base_url=BASE, timeout=30) as c:
    mod = login(c, MOD)
    run(set_user(MOD, is_moderator=True))
    plain_phone = phone()
    plain = login(c, plain_phone)

    for method, path in (("PUT", "/quota"), ("POST", "/quota/grant"), ("PUT", "/payme"), ("DELETE", "/payme")):
        check(f"{path} oddiy odamga yopiq",
              c.request(method, B + path, headers=plain, json={"free_listings": 5}).status_code == 404)

    # --- kvota ---------------------------------------------------------------
    check("sukut bo'yicha 2 ta", left(c, plain) == 2)
    r = c.put(f"{B}/quota", headers=mod, json={"free_listings": 3})
    check("kvota saqlandi", r.status_code == 200 and r.json()["quota"]["free_listings"] == 3, r.text[:150])
    check("eski hisobga tegilmadi", left(c, plain) == 2)
    check("yangi hisob 3 ta oldi", left(c, login(c, phone())) == 3)
    check("manfiy son rad", c.put(f"{B}/quota", headers=mod, json={"free_listings": -1}).status_code == 422)

    # --- aksiya --------------------------------------------------------------
    c.put(f"{B}/quota", headers=mod, json={"free_listings": 3, "promo_users": 2, "promo_listings": 10})
    a, b, d = (login(c, phone()) for _ in range(3))
    check("birinchi ikkitasi 10, uchinchisi 3", [left(c, x) for x in (a, b, d)] == [10, 10, 3])
    check("sanoq to'g'ri", c.get(B, headers=mod).json()["quota"]["promo_used"] == 2)

    c.put(f"{B}/quota", headers=mod, json={"free_listings": 3, "promo_users": 5, "promo_listings": 10})
    phones = [phone() for _ in range(8)]

    async def burst() -> None:
        async with httpx.AsyncClient(base_url=BASE, timeout=30) as ac:
            async def one(p):
                code = (await ac.post("/auth/otp/request", json={"phone": p})).json()["debug_code"]
                await ac.post("/auth/otp/verify", json={"phone": p, "code": code})
            await asyncio.gather(*[one(p) for p in phones])

    run(burst())
    got = [run(get(p)).free_listings_left for p in phones]
    check("parallel ro'yxatda faqat 3 ta joy qolgan edi", got.count(10) == 3 and got.count(3) == 5, str(got))

    # --- oldin kirganlarga ----------------------------------------------------
    run(set_user(plain_phone, free_listings_left=50))
    c.put(f"{B}/quota", headers=mod, json={"free_listings": 3, "promo_users": 1000, "promo_listings": 10})
    n = c.post(f"{B}/quota/grant", headers=mod).json()["granted"]
    check("mavjudlarga berildi", n > 0, str(n))
    check("ko'p krediti bor odam kamaymadi", left(c, plain) == 50)
    check("takror bosish hech kimga bermaydi", c.post(f"{B}/quota/grant", headers=mod).json()["granted"] == 0)
    check("moderator olmaydi", run(get(MOD)).promo_granted_at is None)
    check("3 ta olgan endi 10", left(c, d) == 10)
    c.put(f"{B}/quota", headers=mod, json={"free_listings": 2})
    check("aksiya o'chiq bo'lsa tarqatilmaydi", c.post(f"{B}/quota/grant", headers=mod).json()["granted"] == 0)

    # --- pullik rejim: biznes teshigi -----------------------------------------
    c.put(f"{B}/products/qq_pack", headers=mod, json={
        "kind": "listing_pack", "title": {"uz": "Paket"}, "price_minor": 500000, "quantity": 5, "is_active": True})
    check("pullik e'lon yoqildi", c.put(f"{B}/settings", headers=mod, json={"listing_fee_enabled": True}).status_code == 200)
    try:
        biz = phone()
        h = login(c, biz)
        run(set_user(biz, user_type=UserType.business, tax_id="301234567", free_listings_left=1))
        check("biznes krediti bilan joylaydi", c.post("/listings", headers=h, json=body("A")).status_code == 201)
        check("krediti tugagan biznes 402", c.post("/listings", headers=h, json=body("B")).status_code == 402)
        run(set_user(MOD, free_listings_left=0))
        check("moderator ozod", c.post("/listings", headers=mod, json=body("M")).status_code == 201)
        r = c.patch("/me", headers=plain, json={"user_type": "business", "tax_id": "309999999", "free_listings_left": 999})
        u = run(get(plain_phone))
        check("o'zini biznes qilib bo'lmaydi", u.user_type == UserType.individual and u.free_listings_left == 50, r.text[:80])

        # --- Payme kaliti ------------------------------------------------------
        check("env kaliti ishlaydi", payme(c, settings.payme_key) == -31050)
        key = "panel-kaliti-Maxfiy-123"
        r = c.put(f"{B}/payme", headers=mod, json={"merchant_id": " 5e730e8e0b852a417aa49ceb ", "key": key, "test": True})
        check("panelga saqlandi", r.status_code == 200 and r.json()["payme_source"] == "panel", r.text[:150])
        check("kalit va to'liq ID qaytmaydi", key not in r.text and "5e730e8e0b852a417aa49ceb" not in r.text)
        check("kalit umumiy ko'rinishda ham yo'q", key not in c.get(B, headers=mod).text)
        check("panel kaliti o'tdi, env kaliti endi o'tmaydi",
              payme(c, key) == -31050 and payme(c, settings.payme_key) == -32504)
        o = c.post("/payments/orders", headers=plain, json={"product_code": "qq_pack"}).json()
        host = "https://test.paycom.uz"
        enc = o["checkout_url"].removeprefix(host + "/")
        check("to'lov sahifasi panel kassasi bilan", o["checkout_url"].startswith(host + "/")
              and "m=5e730e8e0b852a417aa49ceb" in base64.b64decode(enc).decode())
        c.put(f"{B}/payme", headers=mod, json={"merchant_id": "5e730e8e0b852a417aa49ceb", "key": key, "test": False})
        o = c.get(f"/payments/orders/{o['id']}", headers=plain).json()
        check("jangovar rejim manzili", o["checkout_url"].startswith("https://checkout.paycom.uz/"))
        check("qisqa kalit rad", c.put(f"{B}/payme", headers=mod, json={"merchant_id": "5e730e8e0b852a417aa49ceb", "key": "x"}).status_code == 422)
        check("ID ichiga parametr tiqib bo'lmaydi",
              c.put(f"{B}/payme", headers=mod, json={"merchant_id": "abcdefghij;a=1", "key": key}).status_code == 422)
        r = c.delete(f"{B}/payme", headers=mod)
        check("o'chirilsa env ga qaytadi, pullik rejim qoladi",
              r.json()["payme_source"] == "env" and r.json()["listing_fee_enabled"] is True)
        check("env kaliti yana ishlaydi", payme(c, settings.payme_key) == -31050 and payme(c, key) == -32504)
    finally:
        c.put(f"{B}/settings", headers=mod, json={"listing_fee_enabled": False})
        c.delete(f"{B}/payme", headers=mod)
        # Urug' tariflarga tegmaydi: boshqa sinovga faol tarif qolmasin.
        c.put(f"{B}/products/qq_pack", headers=mod, json={
            "kind": "listing_pack", "title": {"uz": "Paket"}, "price_minor": 500000, "quantity": 5})
        c.put(f"{B}/quota", headers=mod, json={"free_listings": 2})
