"""E'lonni tahrirlash va arxivlash.

Ilgari e'lon bir marta yozilardi — narxdagi xatoni ham, qorong'ida olingan
rasmni ham tuzatib bo'lmasdi. Endi egasi tahrirlashi va lentadan olib
tashlashi mumkin, biroq savdo tarixi va ochiq muzokaralar himoyalangan.
"""

import httpx

BASE = "http://127.0.0.1:8010"


def check(label: str, ok: bool, extra: str = "") -> None:
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f"  — {extra}" if extra else ""))
    if not ok:
        raise SystemExit(1)


def sign_in(c: httpx.Client, phone: str) -> dict:
    code = c.post("/auth/otp/request", json={"phone": phone}).json()["debug_code"]
    t = c.post("/auth/otp/verify", json={"phone": phone, "code": code}).json()
    return {"Authorization": f"Bearer {t['access_token']}", "Accept-Language": "uz"}


def tri(v: str) -> dict:
    return {"uz": v, "ru": v, "en": v}


def new_listing(c: httpx.Client, headers: dict, title: str) -> dict:
    r = c.post("/listings", headers=headers, json={
        "tag": "electronics",
        "title": tri(title),
        "description": tri("Sinov tavsifi bu yerda."),
        "image_alt": tri("sinov"),
        "category": tri("Elektronika"),
        "condition": tri("Yaxshi"),
        "quantity": tri("1 dona"),
        "wants_summary": tri("biror narsa"),
        "wants": [tri("biror narsa")],
        "desires": [{"category": None, "will_add_cash": True, "wants_cash": False}],
        "photos": [],
        "value": {"minor": 500000000, "currency": "UZS"},
        "cash_ok": True,
    })
    assert r.status_code == 201, r.text[:200]
    return r.json()


with httpx.Client(base_url=BASE, timeout=30) as c:
    H_J = sign_in(c, "+998901234122")   # Jasur
    H_B = sign_in(c, "+998901110002")   # Bekzod

    mine = new_listing(c, H_J, "Tahrir uchun e'lon")

    # ── Tahrirlash ───────────────────────────────────────────────────────────
    r = c.patch(f"/listings/{mine['id']}", headers=H_J, json={
        "title": tri("Yangilangan sarlavha"),
        "value": {"minor": 777000000, "currency": "UZS"},
        "cash_ok": False,
    })
    check("egasi tahrirlay oladi (200)", r.status_code == 200, r.text[:160])
    body = r.json()
    check("sarlavha yangilandi", body["title"] == "Yangilangan sarlavha", body["title"])
    check("qiymat yangilandi", body["value"]["minor"] == 777000000, str(body["value"]))

    # Yuborilmagan maydonlar o'zgarmaydi.
    check("tegilmagan maydon saqlanadi",
          body["image_alt"] == "sinov", body["image_alt"])

    # Uch tilda ham yangilanganini tekshiramiz.
    ru = c.get(f"/listings/{mine['id']}",
               headers={**H_J, "Accept-Language": "ru"}).json()
    check("boshqa til ham yangilandi", ru["title"] == "Yangilangan sarlavha", ru["title"])

    # ── Ruxsat ───────────────────────────────────────────────────────────────
    r = c.patch(f"/listings/{mine['id']}", headers=H_B, json={"cash_ok": True})
    check("begona tahrirlay olmaydi (404)", r.status_code == 404, str(r.status_code))
    r = c.delete(f"/listings/{mine['id']}", headers=H_B)
    check("begona o'chira olmaydi (404)", r.status_code == 404, str(r.status_code))
    r = c.patch(f"/listings/{mine['id']}", json={"cash_ok": True})
    check("autentifikatsiyasiz tahrir yo'q (401)", r.status_code == 401, str(r.status_code))

    # ── Ochiq taklif himoyasi ────────────────────────────────────────────────
    wanted = new_listing(c, H_J, "Taklif ostidagi e'lon")
    theirs = c.get("/me/listings", headers=H_B).json()[0]
    offer = c.post("/offers", headers=H_B, json={
        "listing_id": wanted["id"],
        "offered_listing_ids": [theirs["id"]],
        "cash_delta_minor": 0,
    })
    check("taklif yuborildi", offer.status_code == 201, offer.text[:160])

    r = c.patch(f"/listings/{wanted['id']}", headers=H_J, json={"cash_ok": False})
    check("ochiq taklifdagi e'lon tahrirlanmaydi (409)", r.status_code == 409,
          str(r.status_code))
    r = c.delete(f"/listings/{wanted['id']}", headers=H_J)
    check("ochiq taklifdagi e'lon arxivlanmaydi (409)", r.status_code == 409,
          str(r.status_code))

    # ── Arxivlash ────────────────────────────────────────────────────────────
    r = c.delete(f"/listings/{mine['id']}", headers=H_J)
    check("egasi arxivlay oladi (204)", r.status_code == 204, str(r.status_code))

    feed = c.get("/listings", headers=H_B).json()["items"]
    check("arxivlangan e'lon lentadan chiqdi",
          all(i["id"] != mine["id"] for i in feed))

    # Takroriy o'chirish xato bermaydi (idempotent).
    r = c.delete(f"/listings/{mine['id']}", headers=H_J)
    check("takroriy arxivlash idempotent (204)", r.status_code == 204, str(r.status_code))

    # Arxivlangan e'lonni tahrirlab bo'lmaydi.
    r = c.patch(f"/listings/{mine['id']}", headers=H_J, json={"cash_ok": True})
    check("arxivlangan e'lon tahrirlanmaydi (409)", r.status_code == 409,
          str(r.status_code))

    # Arxivlangan e'lonni taklifga qo'shib bo'lmaydi.
    other = next(i for i in c.get("/listings", headers=H_J).json()["items"]
                 if i["owner"]["name"] != "Jasur Toshmatov")
    r = c.post("/offers", headers=H_J, json={
        "listing_id": other["id"],
        "offered_listing_ids": [mine["id"]],
        "cash_delta_minor": 0,
    })
    check("arxivlangan e'lonni taklif qilib bo'lmaydi (400)", r.status_code == 400,
          str(r.status_code))
