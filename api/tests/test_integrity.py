"""Xavfsizlik tekshiruvida topilgan savdo va to'lov xatolari qaytmasin.

- taklifni yuborgan odam unga qarshi taklif berib, keyin o'zi qabul qila olmaydi;
- 1 ta kredit bilan parallel so'rovlar faqat 1 ta e'lon joylaydi;
- arxivlangan e'longa boost uchun Payme to'lov olmaydi (-31051);
- hisob o'chirilsa: to'lanmagan buyurtma yopiladi, qabul qilingan savdodagi
  qarshi tomonning e'loni yana sotuvga chiqadi.

Talab: server PAYME_MERCHANT_ID va PAYME_KEY bilan ishga tushgan bo'lsin.
"""

import asyncio
import base64
import random
import sys
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import select, update  # noqa: E402

from app.core.config import settings  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402
from app.models.user import User  # noqa: E402

BASE = "http://127.0.0.1:8010"

_loop = asyncio.new_event_loop()
asyncio.set_event_loop(_loop)
run = _loop.run_until_complete


def check(label: str, ok: bool, extra: str = "") -> None:
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f"  → {extra}" if extra else ""))
    if not ok:
        raise SystemExit(1)


def phone() -> str:
    return "+99897" + "".join(random.choice("0123456789") for _ in range(7))


def login(c: httpx.Client, p: str) -> dict:
    code = c.post("/auth/otp/request", json={"phone": p}).json()["debug_code"]
    token = c.post("/auth/otp/verify", json={"phone": p, "code": code}).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def tri(t: str) -> dict:
    return {"uz": t}


def listing_body(title: str) -> dict:
    return {
        "tag": "electronics", "title": tri(title), "description": tri(title),
        "image_alt": tri(title), "category": tri("x"), "condition": tri("x"),
        "quantity": tri("1"), "wants_summary": tri("x"), "wants": [tri("x")],
        "desires": [{"category": None, "will_add_cash": False, "wants_cash": False}],
        "photos": [], "value": {"minor": 100_000_00, "currency": "UZS"}, "cash_ok": True,
    }


def rpc(c: httpx.Client, method: str, params: dict) -> dict:
    token = base64.b64encode(f"Paycom:{settings.payme_key}".encode()).decode()
    return c.post(
        "/payments/payme",
        json={"jsonrpc": "2.0", "id": 1, "method": method, "params": params},
        headers={"Authorization": f"Basic {token}"},
    ).json()


async def set_user(p: str, **values) -> None:
    async with SessionLocal() as db:
        await db.execute(update(User).where(User.phone == p).values(**values))
        await db.commit()


async def credits(p: str) -> int:
    async with SessionLocal() as db:
        return (await db.scalar(select(User).where(User.phone == p))).free_listings_left


def main() -> None:
    mod_phone = phone()
    with httpx.Client(base_url=BASE, timeout=30) as c:
        mod = login(c, mod_phone)
        run(set_user(mod_phone, is_moderator=True))

        # --- 1. Qarshi taklif faqat qabul qiluvchidan -------------------------
        a, b = login(c, phone()), login(c, phone())
        la = c.post("/listings", headers=a, json=listing_body("A")).json()["id"]
        lb = c.post("/listings", headers=b, json=listing_body("B")).json()["id"]
        oid = c.post("/offers", headers=a, json={
            "listing_id": lb, "offered_listing_ids": [la], "cash_delta_minor": 0,
        }).json()["id"]
        r = c.patch(f"/offers/{oid}", headers=a, json={"action": "counter", "cash_delta_minor": -5})
        check("yuboruvchi o'z taklifiga qarshi taklif bera olmaydi", r.status_code == 409, str(r.status_code))
        r = c.patch(f"/offers/{oid}", headers=a, json={"action": "accept"})
        check("yuboruvchi o'z taklifini qabul qila olmaydi", r.status_code == 409, str(r.status_code))
        stranger = login(c, phone())
        r = c.patch(f"/offers/{oid}", headers=stranger, json={"action": "decline"})
        check("begona odam taklifga tega olmaydi", r.status_code == 404, str(r.status_code))

        # --- 2. Kredit: parallel e'lonlar --------------------------------------
        c.put("/admin/billing/products/zz_pack", headers=mod, json={
            "kind": "listing_pack", "title": {"uz": "Paket"}, "price_minor": 1_000_000,
            "quantity": 5, "is_active": True,
        })
        r = c.put("/admin/billing/settings", headers=mod, json={"listing_fee_enabled": True})
        check("pullik e'lon yoqildi", r.status_code == 200, r.text[:120])
        try:
            p = phone()
            h = login(c, p)
            run(set_user(p, free_listings_left=1))

            async def burst() -> list[int]:
                async with httpx.AsyncClient(base_url=BASE, timeout=30) as ac:
                    rs = await asyncio.gather(*[
                        ac.post("/listings", headers=h, json=listing_body(f"P{i}")) for i in range(8)
                    ])
                    return [x.status_code for x in rs]

            codes = run(burst())
            check("1 kredit → faqat 1 e'lon", codes.count(201) == 1, str(sorted(codes)))
            check("kredit manfiy bo'lmaydi", run(credits(p)) == 0)
        finally:
            c.put("/admin/billing/settings", headers=mod, json={"listing_fee_enabled": False})

        # --- 3. Arxivdagi e'longa boost to'lanmaydi ----------------------------
        c.put("/admin/billing/products/zz_boost", headers=mod, json={
            "kind": "boost", "title": {"uz": "Boost"}, "price_minor": 500_000,
            "duration_days": 3, "is_active": True,
        })
        owner = login(c, phone())
        lid = c.post("/listings", headers=owner, json=listing_body("Boost")).json()["id"]
        order = c.post("/payments/orders", headers=owner,
                       json={"product_code": "zz_boost", "listing_id": lid}).json()
        c.delete(f"/listings/{lid}", headers=owner)
        resp = rpc(c, "CheckPerformTransaction", {
            "amount": order["amount_minor"], "account": {"order_id": order["id"]},
        })
        check("arxivdagi e'lon boost'i to'lanmaydi", (resp.get("error") or {}).get("code") == -31051, str(resp)[:160])

        # --- 4. Hisob o'chirilsa ------------------------------------------------
        x_phone = phone()
        x, y = login(c, x_phone), login(c, phone())
        lx = c.post("/listings", headers=x, json=listing_body("X")).json()["id"]
        ly = c.post("/listings", headers=y, json=listing_body("Y")).json()["id"]
        oid = c.post("/offers", headers=x, json={
            "listing_id": ly, "offered_listing_ids": [lx], "cash_delta_minor": 0,
        }).json()["id"]
        r = c.patch(f"/offers/{oid}", headers=y, json={"action": "accept"})
        check("savdo qabul qilindi", r.status_code == 200, r.text[:120])
        check("e'lon band", c.get(f"/listings/{ly}", headers=y).json()["status"] == "in_negotiation")
        pending = c.post("/payments/orders", headers=x, json={"product_code": "zz_pack"}).json()
        check("hisob o'chirildi", c.request("DELETE", "/me", headers=x, json={"confirm": True}).status_code in (200, 204))
        check("qarshi tomonning e'loni yana sotuvda",
              c.get(f"/listings/{ly}", headers=y).json()["status"] == "active")
        resp = rpc(c, "CheckPerformTransaction", {
            "amount": pending["amount_minor"], "account": {"order_id": pending["id"]},
        })
        check("o'chirilgan hisob buyurtmasi to'lanmaydi", "error" in resp, str(resp)[:160])

        # Boshqa testlar (test_payme) faol tarif yo'q deb boshlaydi.
        for code, kind in (("zz_pack", "listing_pack"), ("zz_boost", "boost")):
            c.put(f"/admin/billing/products/{code}", headers=mod, json={
                "kind": kind, "title": {"uz": code}, "price_minor": 100, "is_active": False,
            })

    print("\nHammasi o'tdi.")


if __name__ == "__main__":
    main()
