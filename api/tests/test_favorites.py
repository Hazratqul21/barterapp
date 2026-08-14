"""Saqlangan e'lonlar.

Talablar:

- `is_favorite` lentaning o'zida kelsin. Aks holda mijoz har karta uchun
  alohida so'rov yuborishga yoki yurakni noto'g'ri holatda chizishga majbur.
- Ikki marta bosish xato bo'lmasin.
- Bozordan chiqqan e'lon (arxivlangan) saqlanmasin va ro'yxatda ko'rinmasin —
  keyin umidsizlantiradigan ro'yxat yig'ilmasin.
- Blok bu yerda ham amal qilsin: bloklangan savdogarning e'loni saqlanmasin,
  saqlangani esa ro'yxatdan yo'qolsin.
"""

import httpx

BASE = "http://127.0.0.1:8010"


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


def ids(page: dict) -> list[str]:
    return [i["id"] for i in page["items"]]


with httpx.Client(base_url=BASE, timeout=30) as c:
    tok, me_id = login(c, "+998901234951")

    feed = c.get("/listings", headers=auth(tok), params={"limit": 50}).json()
    check("lentada e'lonlar bor", len(feed["items"]) >= 2, str(len(feed["items"])))

    first, second = feed["items"][0], feed["items"][1]

    check(
        "lenta kartasi is_favorite tashiydi",
        "is_favorite" in first,
        "mijoz yurakni birinchi javobdanoq to'g'ri chizadi",
    )
    check("boshida hech narsa saqlanmagan", first["is_favorite"] is False)

    guest = c.get("/listings", params={"limit": 1}).json()
    check(
        "mehmon uchun is_favorite doim False",
        guest["items"][0]["is_favorite"] is False,
    )

    # --- saqlash -------------------------------------------------------------

    r = c.post(f"/listings/{first['id']}/favorite")
    check("saqlash autentifikatsiya talab qiladi", r.status_code == 401)

    r = c.post(f"/listings/{first['id']}/favorite", headers=auth(tok))
    check("e'lon saqlandi", r.status_code == 204, str(r.status_code))

    r = c.post(f"/listings/{first['id']}/favorite", headers=auth(tok))
    check("ikki marta bosish xato emas", r.status_code == 204)

    r = c.post(
        "/listings/00000000-0000-0000-0000-000000000000/favorite", headers=auth(tok)
    )
    check("yo'q e'lonni saqlash 404 beradi", r.status_code == 404)

    saved = c.get("/favorites", headers=auth(tok)).json()
    check("ro'yxatda bitta e'lon", ids(saved) == [first["id"]], str(ids(saved)))
    check("ro'yxatdagi karta is_favorite=True", saved["items"][0]["is_favorite"] is True)

    again = c.get("/listings", headers=auth(tok), params={"limit": 50}).json()
    by_id = {i["id"]: i for i in again["items"]}
    check(
        "lentada saqlangani belgilangan",
        by_id[first["id"]]["is_favorite"] is True,
        "alohida so'rovsiz",
    )
    check(
        "saqlanmagani belgilanmagan",
        by_id[second["id"]]["is_favorite"] is False,
    )

    # --- tartib --------------------------------------------------------------

    c.post(f"/listings/{second['id']}/favorite", headers=auth(tok))
    saved = c.get("/favorites", headers=auth(tok)).json()
    check(
        "oxirgi saqlangani birinchi turadi",
        ids(saved)[0] == second["id"],
        str(ids(saved)),
    )
    check("ikkalasi ham ro'yxatda", len(saved["items"]) == 2)

    # --- o'chirish -----------------------------------------------------------

    r = c.delete(f"/listings/{second['id']}/favorite", headers=auth(tok))
    check("saqlanganini olib tashlash", r.status_code == 204)

    r = c.delete(f"/listings/{second['id']}/favorite", headers=auth(tok))
    check("qayta olib tashlash xato emas", r.status_code == 204)

    r = c.delete(
        "/listings/00000000-0000-0000-0000-000000000000/favorite", headers=auth(tok)
    )
    check(
        "yo'q e'londan olib tashlash xato emas",
        r.status_code == 204,
        "e'lon o'chirilgan bo'lsa ham mijoz tugmani bosa oladi",
    )

    saved = c.get("/favorites", headers=auth(tok)).json()
    check("ro'yxatda yana bitta qoldi", ids(saved) == [first["id"]], str(ids(saved)))

    # --- boshqa hisob ---------------------------------------------------------

    other, _ = login(c, "+998901234952")
    theirs = c.get("/favorites", headers=auth(other)).json()
    check(
        "saqlanganlar hisoblar orasida aralashmaydi",
        first["id"] not in ids(theirs),
        str(ids(theirs)),
    )

    their_feed = c.get("/listings", headers=auth(other), params={"limit": 50}).json()
    mine_in_theirs = [i for i in their_feed["items"] if i["id"] == first["id"]]
    if mine_in_theirs:
        check(
            "boshqa odamda is_favorite False",
            mine_in_theirs[0]["is_favorite"] is False,
        )

    # --- arxivlangan e'lon ----------------------------------------------------

    def tri(u, ru, en):
        return {"uz": u, "ru": ru, "en": en}

    made = c.post(
        "/listings",
        headers=auth(other),
        json={
            "tag": "agri",
            "title": tri("Arxiv sinovi", "Тест архива", "Archive test"),
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
    check("sinov e'loni yaratildi", made.status_code == 201, made.text[:100])
    doomed = made.json()["id"]

    r = c.post(f"/listings/{doomed}/favorite", headers=auth(tok))
    check("boshqaning e'loni saqlandi", r.status_code == 204, str(r.status_code))
    check("ro'yxatda ko'rinadi", doomed in ids(c.get("/favorites", headers=auth(tok)).json()))

    c.delete(f"/listings/{doomed}", headers=auth(other))

    saved = c.get("/favorites", headers=auth(tok)).json()
    check(
        "arxivlangan e'lon ro'yxatdan chiqadi",
        doomed not in ids(saved),
        "o'lik karta ko'rsatilmaydi",
    )

    r = c.post(f"/listings/{doomed}/favorite", headers=auth(tok))
    check(
        "arxivlangan e'lonni saqlab bo'lmaydi",
        r.status_code == 404,
        f"{r.status_code} — keyin umidsizlantiradigan ro'yxat yig'ilmasin",
    )

    # --- blok -----------------------------------------------------------------

    owner_id = c.get(f"/listings/{first['id']}").json()["owner"]["id"]
    c.post(f"/blocks/{owner_id}", headers=auth(tok))

    saved = c.get("/favorites", headers=auth(tok)).json()
    check(
        "bloklangan savdogarning e'loni ro'yxatdan yo'qoladi",
        first["id"] not in ids(saved),
    )

    r = c.post(f"/listings/{first['id']}/favorite", headers=auth(tok))
    check(
        "bloklangan savdogarning e'loni saqlanmaydi",
        r.status_code == 403,
        str(r.status_code),
    )

    c.delete(f"/blocks/{owner_id}", headers=auth(tok))

    saved = c.get("/favorites", headers=auth(tok)).json()
    check(
        "blok yechilgach saqlangani qaytadi",
        first["id"] in ids(saved),
        "qator o'chirilmagan, faqat yashirilgan edi",
    )

    c.delete(f"/listings/{first['id']}/favorite", headers=auth(tok))
