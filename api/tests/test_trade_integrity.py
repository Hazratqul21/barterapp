"""B3: savdo yaxlitligi — nofaol e'lonni taklif qilib bo'lmasligi, savdo
yakunlanganda o'sha e'lonlar uchun boshqa ochiq takliflar bekor bo'lishi va
ikki marta yakunlab bo'lmasligi."""

import httpx

BASE = "http://127.0.0.1:8010"


def sign_in(c: httpx.Client, phone: str) -> dict:
    code = c.post("/auth/otp/request", json={"phone": phone}).json()["debug_code"]
    t = c.post("/auth/otp/verify", json={"phone": phone, "code": code}).json()
    return {"Authorization": f"Bearer {t['access_token']}", "Accept-Language": "uz"}


def check(label: str, ok: bool, extra: str = "") -> None:
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f"  — {extra}" if extra else ""))
    if not ok:
        raise SystemExit(1)


with httpx.Client(base_url=BASE, timeout=20) as c:
    H_J = sign_in(c, "+998901234122")  # Jasur
    H_B = sign_in(c, "+998901110002")  # Bekzod
    H_N = sign_in(c, "+998901110003")  # Nodir

    feed = c.get("/listings", headers=H_J).json()["items"]
    wanted = next(i for i in feed if i["owner"]["name"] == "Bekzod Karimov")

    mac = c.get("/me/listings", headers=H_J).json()[0]
    nod = c.get("/me/listings", headers=H_N).json()[0]

    # Ikki foydalanuvchi bir e'longa (wanted) taklif yuboradi.
    o1 = c.post("/offers", headers=H_J, json={
        "listing_id": wanted["id"], "offered_listing_ids": [mac["id"]],
        "cash_delta_minor": 0,
    }).json()
    o2 = c.post("/offers", headers=H_N, json={
        "listing_id": wanted["id"], "offered_listing_ids": [nod["id"]],
        "cash_delta_minor": 0,
    }).json()
    check("ikkala taklif ham pending", o1["status"] == "pending" and o2["status"] == "pending")

    # Bekzod O1 ni qabul qiladi, keyin yakunlanadi.
    acc = c.patch(f"/offers/{o1['id']}", headers=H_B, json={"action": "accept"})
    check("qabul qilindi (accepted)", acc.json()["status"] == "accepted")
    done = c.patch(f"/offers/{o1['id']}", headers=H_J, json={"action": "complete"})
    check("savdo yakunlandi (completed)", done.json()["status"] == "completed")

    # O2 endi bekor bo'lishi kerak — e'lon savdoga ketdi.
    o2_after = c.get(f"/offers/{o2['id']}", headers=H_N).json()
    check("boshqa ochiq taklif bekor qilindi (expired)",
          o2_after["status"] == "expired", o2_after["status"])

    # Ikki marta yakunlab bo'lmaydi.
    again = c.patch(f"/offers/{o1['id']}", headers=H_J, json={"action": "complete"})
    check("ikkinchi yakunlash rad etiladi (409)", again.status_code == 409)

    # Yakunlangan e'lonni yangi taklifga qo'shib bo'lmaydi.
    other = next(
        i for i in c.get("/listings", headers=H_J).json()["items"]
        if i["owner"]["name"] != "Jasur Toshmatov"
    )
    bad = c.post("/offers", headers=H_J, json={
        "listing_id": other["id"], "offered_listing_ids": [mac["id"]],
        "cash_delta_minor": 0,
    })
    check("nofaol e'lonni taklif qilib bo'lmaydi (400)", bad.status_code == 400,
          bad.json().get("detail", ""))
