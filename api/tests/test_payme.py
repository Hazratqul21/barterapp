"""Payme Merchant API va to'lov oqimi.

Payme sinov muhiti (test.paycom.uz) bizga aynan shunday so'rovlar yuboradi.
Bu yerda ular qo'lda yuboriladi — kassa sinovdan o'tishi uchun har birining
javobi Payme hujjatidagidek bo'lishi shart:

- noto'g'ri kalit → -32504; noto'g'ri summa → -31001; buyurtma yo'q → -31050;
- bir xil `CreateTransaction` qayta kelsa — o'sha tranzaksiya qaytadi;
- `PerformTransaction` ikki marta kelsa — e'lon kvotasi bir marta qo'shiladi;
- bitta buyurtmaga ikkinchi tranzaksiya → -31052 (ikki marta pul yechilmasin);
- 12 soatdan eski tranzaksiya bajarilmaydi (-31008) va bekor qilinadi (sabab 4);
- bajarilgan tranzaksiyani bekor qilib bo'lmaydi (-31007);
- `GetStatement` davrdagi tranzaksiyalarni qaytaradi.

Narx admin paneldan qo'yiladi; pullik e'lon kaliti o'chiq bo'lsa 402 yo'q.

Talab: server PAYME_MERCHANT_ID va PAYME_KEY bilan ishga tushgan bo'lsin.
"""

import asyncio
import base64
import sys
import time
import uuid
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import select, update  # noqa: E402

from app.core.config import settings  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402
from app.models.payment import PaymeTransaction  # noqa: E402
from app.models.user import User  # noqa: E402

BASE = "http://127.0.0.1:8010"
MODERATOR_PHONE = "+998901234122"
BUYER_PHONE = "+998901110001"

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


def payme_auth(key: str) -> dict:
    token = base64.b64encode(f"Paycom:{key}".encode()).decode()
    return {"Authorization": f"Basic {token}"}


async def set_moderator() -> None:
    async with SessionLocal() as db:
        user = await db.scalar(select(User).where(User.phone == MODERATOR_PHONE))
        user.is_moderator = True
        await db.commit()


async def free_left(phone: str) -> int:
    async with SessionLocal() as db:
        return (await db.scalar(select(User).where(User.phone == phone))).free_listings_left


async def age_transaction(payme_id: str, hours: int) -> None:
    async with SessionLocal() as db:
        await db.execute(
            update(PaymeTransaction)
            .where(PaymeTransaction.payme_id == payme_id)
            .values(create_time=PaymeTransaction.create_time - hours * 3600 * 1000)
        )
        await db.commit()


def rpc(c: httpx.Client, method: str, params: dict, key: str | None = None) -> dict:
    body = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
    r = c.post("/payments/payme", json=body, headers=payme_auth(key or settings.payme_key))
    assert r.status_code == 200, r.text
    return r.json()


def code_of(resp: dict) -> int | None:
    return (resp.get("error") or {}).get("code")


if not settings.payme_enabled:
    print("FAIL  PAYME_MERCHANT_ID / PAYME_KEY berilmagan — test ishlay olmaydi")
    raise SystemExit(1)

run(set_moderator())

with httpx.Client(base_url=BASE, timeout=20) as c:
    mod = login(c, MODERATOR_PHONE)
    buyer = login(c, BUYER_PHONE)

    # --- 1. Admin narx qo'yadi ------------------------------------------------
    r = c.put(
        "/admin/billing/settings", json={"listing_fee_enabled": True}, headers=auth(mod)
    )
    check("tarifsiz pullik e'lonni yoqib bo'lmaydi", r.status_code == 409, r.text)

    r = c.put(
        "/admin/billing/products/test_pack3",
        json={
            "kind": "listing_pack",
            "title": {"uz": "3 ta e'lon", "ru": "3 объявления"},
            "price_minor": 1_500_000,  # 15 000 so'm
            "discount_percent": 20,
            "quantity": 3,
            "is_active": True,
        },
        headers=auth(mod),
    )
    check("admin tarif qo'shadi", r.status_code == 200, r.text)
    row = next(p for p in r.json()["products"] if p["code"] == "test_pack3")
    check("chegirma narxga qo'llanadi", row["final_price_minor"] == 1_200_000, str(row))

    r = c.put(
        "/admin/billing/products/test_boost",
        json={"kind": "boost", "title": {"uz": "Boost"}, "price_minor": 500_000},
        headers=auth(mod),
    )
    check("boost kunsiz rad etiladi", r.status_code == 422, r.text)

    r = c.put(
        "/admin/billing/products/x",
        json={"kind": "listing_pack", "title": {"uz": "x"}, "price_minor": 100},
        headers=auth(buyer),
    )
    check("oddiy foydalanuvchi narxni o'zgartira olmaydi", r.status_code == 404)

    r = c.get("/payments/products", headers={"Accept-Language": "ru"})
    mine = [p for p in r.json() if p["code"] == "test_pack3"]
    check(
        "foydalanuvchi faol tarifni o'z tilida ko'radi",
        mine and mine[0]["title"] == "3 объявления" and mine[0]["final_price_minor"] == 1_200_000,
        str(mine),
    )

    # --- 2. Buyurtma va Payme sahifasi ----------------------------------------
    r = c.post("/payments/orders", json={"product_code": "test_pack3"}, headers=auth(buyer))
    check("buyurtma yaratiladi", r.status_code == 201, r.text)
    order = r.json()
    order_id = order["id"]
    check("buyurtma summasi chegirmali narx", order["amount_minor"] == 1_200_000)
    url = order["checkout_url"] or ""
    decoded = base64.b64decode(url.rsplit("/", 1)[-1]).decode()
    check(
        "checkout havolasida kassa, buyurtma va summa bor",
        f"m={settings.payme_merchant_id}" in decoded
        and f"ac.order_id={order_id}" in decoded
        and "a=1200000" in decoded,
        decoded,
    )

    # Narx o'zgarsa, ochilgan buyurtma summasi o'zgarmaydi.
    c.put(
        "/admin/billing/products/test_pack3",
        json={
            "kind": "listing_pack",
            "title": {"uz": "3 ta e'lon"},
            "price_minor": 9_900_000,
            "quantity": 3,
            "is_active": True,
        },
        headers=auth(mod),
    )

    account = {"order_id": order_id}

    # --- 3. Payme'ning tekshiruvlari ------------------------------------------
    resp = rpc(c, "CheckPerformTransaction", {"amount": 1_200_000, "account": account}, key="wrong")
    check("noto'g'ri kalit → -32504", code_of(resp) == -32504, str(resp))

    resp = c.post("/payments/payme", content=b"{not json", headers=payme_auth(settings.payme_key)).json()
    check("buzuq JSON → -32700", code_of(resp) == -32700, str(resp))

    resp = rpc(c, "Unknown", {})
    check("noma'lum metod → -32601", code_of(resp) == -32601, str(resp))

    resp = rpc(c, "CheckPerformTransaction", {"amount": 100, "account": account})
    check("noto'g'ri summa → -31001", code_of(resp) == -31001, str(resp))

    resp = rpc(
        c,
        "CheckPerformTransaction",
        {"amount": 1_200_000, "account": {"order_id": str(uuid.uuid4())}},
    )
    check("buyurtma yo'q → -31050", code_of(resp) == -31050, str(resp))

    resp = rpc(c, "CheckPerformTransaction", {"amount": 1_200_000, "account": account})
    check("to'g'ri buyurtma → allow", resp.get("result", {}).get("allow") is True, str(resp))

    # --- 4. Tranzaksiya: yaratish, takror, ikkinchisi -------------------------
    t1 = f"test-{uuid.uuid4().hex[:20]}"
    now_ms = int(time.time() * 1000)
    resp = rpc(
        c, "CreateTransaction",
        {"id": t1, "time": now_ms, "amount": 1_200_000, "account": account},
    )
    check("CreateTransaction → state 1", resp.get("result", {}).get("state") == 1, str(resp))
    our_tx = resp["result"]["transaction"]

    resp = rpc(
        c, "CreateTransaction",
        {"id": t1, "time": now_ms, "amount": 1_200_000, "account": account},
    )
    check(
        "takroriy CreateTransaction o'sha tranzaksiyani qaytaradi",
        resp.get("result", {}).get("transaction") == our_tx,
        str(resp),
    )

    resp = rpc(
        c, "CreateTransaction",
        {"id": f"other-{uuid.uuid4().hex[:16]}", "time": now_ms, "amount": 1_200_000,
         "account": account},
    )
    check("bitta buyurtmaga ikkinchi to'lov → -31052", code_of(resp) == -31052, str(resp))

    # --- 5. Bajarish va idempotentlik -----------------------------------------
    before = run(free_left(BUYER_PHONE))
    resp = rpc(c, "PerformTransaction", {"id": t1})
    check("PerformTransaction → state 2", resp.get("result", {}).get("state") == 2, str(resp))
    resp2 = rpc(c, "PerformTransaction", {"id": t1})
    check(
        "takroriy Perform o'sha natijani qaytaradi",
        resp2.get("result", {}).get("perform_time") == resp["result"]["perform_time"],
        str(resp2),
    )
    after = run(free_left(BUYER_PHONE))
    check("e'lon kvotasi bir marta +3", after - before == 3, f"{before} → {after}")

    r = c.get(f"/payments/orders/{order_id}", headers=auth(buyer))
    check(
        "buyurtma paid, havola yo'q",
        r.json()["status"] == "paid" and r.json()["checkout_url"] is None,
        r.text,
    )

    resp = rpc(c, "CancelTransaction", {"id": t1, "reason": 5})
    check("bajarilganini bekor qilib bo'lmaydi → -31007", code_of(resp) == -31007, str(resp))

    resp = rpc(c, "CheckTransaction", {"id": t1})
    check("CheckTransaction holatni beradi", resp.get("result", {}).get("state") == 2, str(resp))

    resp = rpc(c, "CheckPerformTransaction", {"amount": 1_200_000, "account": account})
    check("to'langan buyurtma qayta to'lanmaydi → -31051", code_of(resp) == -31051, str(resp))

    resp = rpc(c, "CheckTransaction", {"id": "no-such-tx"})
    check("noma'lum tranzaksiya → -31003", code_of(resp) == -31003, str(resp))

    # --- 6. Bekor qilish va muddat --------------------------------------------
    o2 = c.post("/payments/orders", json={"product_code": "test_pack3"}, headers=auth(buyer)).json()
    check("yangi buyurtma yangi narxda", o2["amount_minor"] == 9_900_000, str(o2))
    t2 = f"test-{uuid.uuid4().hex[:20]}"
    rpc(c, "CreateTransaction", {"id": t2, "time": now_ms, "amount": 9_900_000,
                                 "account": {"order_id": o2["id"]}})
    resp = rpc(c, "CancelTransaction", {"id": t2, "reason": 3})
    check("yaratilganini bekor qilish → state -1", resp.get("result", {}).get("state") == -1, str(resp))
    r = c.get(f"/payments/orders/{o2['id']}", headers=auth(buyer))
    check("buyurtma cancelled", r.json()["status"] == "cancelled", r.text)
    resp = rpc(c, "PerformTransaction", {"id": t2})
    check("bekor qilingani bajarilmaydi → -31008", code_of(resp) == -31008, str(resp))

    o3 = c.post("/payments/orders", json={"product_code": "test_pack3"}, headers=auth(buyer)).json()
    t3 = f"test-{uuid.uuid4().hex[:20]}"
    rpc(c, "CreateTransaction", {"id": t3, "time": now_ms, "amount": 9_900_000,
                                 "account": {"order_id": o3["id"]}})
    run(age_transaction(t3, 13))
    resp = rpc(c, "PerformTransaction", {"id": t3})
    check("12 soatdan eski → -31008", code_of(resp) == -31008, str(resp))
    resp = rpc(c, "CheckTransaction", {"id": t3})
    check(
        "eskirgani sabab 4 bilan bekor qilingan",
        resp["result"]["state"] == -1 and resp["result"]["reason"] == 4,
        str(resp),
    )

    # --- 7. Hisobot -----------------------------------------------------------
    resp = rpc(c, "GetStatement", {"from": now_ms - 60_000, "to": int(time.time() * 1000) + 60_000})
    ids = {t["id"] for t in resp.get("result", {}).get("transactions", [])}
    check("GetStatement davrdagi tranzaksiyalarni beradi", {t1, t2} <= ids, str(ids))

    # --- 8. Boost: faqat o'z e'loni -------------------------------------------
    c.put(
        "/admin/billing/products/test_boost",
        json={"kind": "boost", "title": {"uz": "Boost 7 kun"}, "price_minor": 500_000,
              "duration_days": 7, "is_active": True},
        headers=auth(mod),
    )
    r = c.post("/payments/orders", json={"product_code": "test_boost"}, headers=auth(buyer))
    check("boost e'lonsiz → 422", r.status_code == 422, r.text)
    foreign = c.get("/listings", headers=auth(buyer)).json()
    foreign = foreign.get("items", foreign) if isinstance(foreign, dict) else foreign
    other = next((l for l in foreign if l.get("id")), None)
    if other:
        r = c.post(
            "/payments/orders",
            json={"product_code": "test_boost", "listing_id": other["id"]},
            headers=auth(buyer),
        )
        check("birovning e'loniga boost → 404", r.status_code == 404, r.text)

    own = c.get("/me/listings", headers=auth(buyer)).json()
    own = next((l for l in own if l.get("status") in ("active", None)), own[0] if own else None)
    check("xaridorning o'z e'loni bor (seed)", own is not None)
    r = c.post(
        "/payments/orders",
        json={"product_code": "test_boost", "listing_id": own["id"]},
        headers=auth(buyer),
    )
    check("o'z e'loniga boost buyurtma", r.status_code == 201, r.text)
    ob = r.json()
    tb = f"test-{uuid.uuid4().hex[:20]}"
    rpc(c, "CreateTransaction", {"id": tb, "time": now_ms, "amount": ob["amount_minor"],
                                 "account": {"order_id": ob["id"]}})
    rpc(c, "PerformTransaction", {"id": tb})
    detail = c.get(f"/listings/{own['id']}").json()
    check("to'langan boost e'lonni premium qiladi", detail.get("is_premium") is True, str(detail)[:200])

    # --- 9. Pullik e'lon kaliti -----------------------------------------------
    r = c.put("/admin/billing/settings", json={"listing_fee_enabled": True}, headers=auth(mod))
    check("tarif bor — pullik e'lon yoqiladi", r.json()["listing_fee_enabled"] is True, r.text)
    r = c.get("/payments/status", headers=auth(buyer))
    check("ilova holatni ko'radi", r.json()["listing_fee_enabled"] is True, r.text)
    r = c.put("/admin/billing/settings", json={"listing_fee_enabled": False}, headers=auth(mod))
    check("pullik e'lon o'chiriladi", r.json()["listing_fee_enabled"] is False, r.text)

    r = c.get("/admin/billing/orders?status=paid", headers=auth(mod))
    check(
        "admin to'langan buyurtmalarni ko'radi",
        any(o["id"] == order_id for o in r.json()),
        r.text[:300],
    )

    # Tozalash: sinov tariflari foydalanuvchiga ko'rinmasin.
    for code in ("test_pack3", "test_boost"):
        c.put(
            f"/admin/billing/products/{code}",
            json={"kind": "listing_pack" if code == "test_pack3" else "boost",
                  "title": {"uz": code}, "price_minor": 100, "duration_days": 1,
                  "is_active": False},
            headers=auth(mod),
        )
