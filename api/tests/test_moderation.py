"""Bloklash va shikoyat.

Asosiy talab: blok bezak bo'lmasin. Uchala joyda ham amal qilishi shart —
lentada ko'rinmasin, taklif yubora olmasin, chatga yoza olmasin. Faqat
lentadan yashirish yetarli emas: e'lon havolasi qo'lda ochilsa yoki eski
bildirishnomadan kirilsa, taklif baribir yetib borardi.

Ikkinchi talab: blok ikki tomonlama ta'sir qilsin, lekin faqat qo'ygan odam
yecha olsin.
"""

import httpx

BASE = "http://127.0.0.1:8010"


def check(label: str, ok: bool, extra: str = "") -> None:
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f"  — {extra}" if extra else ""))
    if not ok:
        raise SystemExit(1)


def login(c: httpx.Client, phone: str) -> tuple[str, str]:
    code = c.post("/auth/otp/request", json={"phone": phone}).json()["debug_code"]
    body = c.post("/auth/otp/verify", json={"phone": phone, "code": code}).json()
    token = body["access_token"]
    me = c.get("/me", headers={"Authorization": f"Bearer {token}"}).json()
    return token, me["id"]


def auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


with httpx.Client(base_url=BASE, timeout=30) as c:
    ann, ann_id = login(c, "+998901234701")
    bob, bob_id = login(c, "+998901234702")

    # Bob e'lon egasi bo'lishi kerak, shuning uchun lentadan uniki topiladi.
    feed = c.get("/listings", headers=auth(ann), params={"limit": 50}).json()
    check("boshlanishda lenta bo'sh emas", len(feed["items"]) > 0)

    victim = feed["items"][0]
    owner_id = c.get(f"/listings/{victim['id']}").json()["owner"]["id"]

    # --- blok qo'yish -------------------------------------------------------

    r = c.post(f"/blocks/{ann_id}", headers=auth(ann))
    check("o'zini bloklash 400 beradi", r.status_code == 400, str(r.status_code))

    r = c.post(f"/blocks/{'0' * 8}-0000-0000-0000-{'0' * 12}", headers=auth(ann))
    check("yo'q odamni bloklash 404 beradi", r.status_code == 404, str(r.status_code))

    r = c.post(f"/blocks/{owner_id}", headers=auth(ann))
    check("blok qo'yiladi", r.status_code == 204, str(r.status_code))

    r = c.post(f"/blocks/{owner_id}", headers=auth(ann))
    check(
        "ikkinchi marta bosish xato emas",
        r.status_code == 204,
        "hech narsa ko'rinmaganda odam qayta bosadi",
    )

    blocks = c.get("/blocks", headers=auth(ann)).json()
    check("blok ro'yxatda ko'rinadi", owner_id in [b["id"] for b in blocks])

    # --- lentadan yo'qoladi -------------------------------------------------

    after = c.get("/listings", headers=auth(ann), params={"limit": 50}).json()
    check(
        "bloklangan odamning e'loni lentadan chiqib ketdi",
        victim["id"] not in [i["id"] for i in after["items"]],
    )
    check(
        "bloklangan egasining birorta e'loni qolmadi",
        all(
            c.get(f"/listings/{i['id']}").json()["owner"]["id"] != owner_id
            for i in after["items"]
        ),
    )
    check("lenta butunlay bo'shab qolmadi", len(after["items"]) > 0)

    # Filtr va qidiruv ham blokni hurmat qilishi kerak — aks holda qidirib
    # topish blokni chetlab o'tishning eng oson yo'li bo'lardi.
    searched = c.get(
        "/listings",
        headers=auth(ann),
        params={"q": victim["title"].split()[0], "limit": 50},
    ).json()
    check(
        "qidiruv blokni chetlab o'tmaydi",
        victim["id"] not in [i["id"] for i in searched["items"]],
    )

    sorted_feed = c.get(
        "/listings", headers=auth(ann), params={"sort": "cheap", "limit": 50}
    ).json()
    check(
        "saralangan lenta ham blokni hurmat qiladi",
        victim["id"] not in [i["id"] for i in sorted_feed["items"]],
    )

    # --- taklif yuborib bo'lmaydi -------------------------------------------

    # Ann'ning almashishga qo'yadigan narsasi bo'lishi shart, aks holda taklif
    # blok sababli emas, "beradigan e'loningiz yo'q" sababli rad etiladi va
    # tekshiruv hech nimani isbotlamaydi.
    def tri(u, ru, en):
        return {"uz": u, "ru": ru, "en": en}

    made = c.post(
        "/listings",
        headers=auth(ann),
        json={
            "tag": "electronics",
            "title": tri("Sinov buyumi", "Тестовый предмет", "Test item"),
            "description": tri("Sinov", "Тест", "Test"),
            "image_alt": tri("Sinov", "Тест", "Test"),
            "category": tri("Sinov", "Тест", "Test"),
            "condition": tri("Yangi", "Новый", "New"),
            "quantity": tri("1 dona", "1 шт", "1 piece"),
            "wants_summary": tri("Nima bo'lsa ham", "Что угодно", "Anything"),
            "wants": [tri("Nima bo'lsa ham", "Что угодно", "Anything")],
            "desires": [
                {"category": None, "will_add_cash": True, "wants_cash": False}
            ],
            "photos": [],
            "value": {"minor": 500000000, "currency": "UZS"},
            "cash_ok": True,
        },
    )
    check("sinov uchun e'lon yaratildi", made.status_code == 201, made.text[:120])
    my_listing = made.json()["id"]

    r = c.post(
        "/offers",
        headers=auth(ann),
        json={
            "listing_id": victim["id"],
            "offered_listing_ids": [my_listing],
            "cash_delta_minor": 0,
            "currency": "UZS",
        },
    )
    check(
        "bloklangan odamga taklif 403 beradi",
        r.status_code == 403,
        f"{r.status_code} — havolani qo'lda ochish blokni buzmaydi",
    )

    # --- chat: eski suhbat o'qiladi, lekin yozilmaydi ------------------------

    # Blok qo'yilishidan oldin ochilgan suhbat kerak, chunki muhim holat aynan
    # shu: taklif yuborilgan, gaplashilgan, keyin odam blok bosgan.
    c.delete(f"/blocks/{owner_id}", headers=auth(ann))
    opened = c.post(
        "/offers",
        headers=auth(ann),
        json={
            "listing_id": victim["id"],
            "offered_listing_ids": [my_listing],
            "cash_delta_minor": 0,
            "currency": "UZS",
            "message": "Salom, qiziqdim.",
        },
    )
    check("blokdan oldin taklif ketadi", opened.status_code == 201, opened.text[:120])

    threads = c.get("/conversations", headers=auth(ann)).json()
    thread_id = threads[0]["id"]

    r = c.post(
        f"/conversations/{thread_id}/messages",
        headers=auth(ann),
        json={"body": "Blokdan oldingi xabar"},
    )
    check("blokdan oldin xabar yoziladi", r.status_code in (200, 201), str(r.status_code))

    c.post(f"/blocks/{owner_id}", headers=auth(ann))

    r = c.post(
        f"/conversations/{thread_id}/messages",
        headers=auth(ann),
        json={"body": "Blokdan keyingi xabar"},
    )
    check(
        "blokdan keyin xabar yozilmaydi",
        r.status_code == 403,
        f"{r.status_code} — lentadan yashirish yolg'iz yetarli emas",
    )

    r = c.get(f"/conversations/{thread_id}", headers=auth(ann))
    check(
        "eski suhbat baribir o'qiladi",
        r.status_code == 200,
        "blok aytilgan gapni o'chirmaydi",
    )

    # --- blokni yechish -----------------------------------------------------

    r = c.delete(f"/blocks/{owner_id}", headers=auth(ann))
    check("blok yechiladi", r.status_code == 204, str(r.status_code))

    r = c.delete(f"/blocks/{owner_id}", headers=auth(ann))
    check("yo'q blokni yechish xato emas", r.status_code == 204)

    back = c.get("/listings", headers=auth(ann), params={"limit": 50}).json()
    check(
        "blok yechilgach e'lon qaytadi",
        victim["id"] in [i["id"] for i in back["items"]],
    )

    # --- ikki tomonlama ta'sir ----------------------------------------------

    c.post(f"/blocks/{bob_id}", headers=auth(ann))

    ann_feed = c.get("/listings", headers=auth(ann), params={"limit": 50}).json()
    bob_feed = c.get("/listings", headers=auth(bob), params={"limit": 50}).json()
    check(
        "bloklangan tomon ham qarshi tomonni ko'rmaydi",
        all(
            c.get(f"/listings/{i['id']}").json()["owner"]["id"] != ann_id
            for i in bob_feed["items"]
        ),
        "bir tomonlama yashirish blokning ma'nosini yo'qotadi",
    )

    bob_blocks = c.get("/blocks", headers=auth(bob)).json()
    check(
        "bloklangan odam buni o'z ro'yxatida ko'rmaydi",
        ann_id not in [b["id"] for b in bob_blocks],
        "ro'yxat faqat o'zi qo'ygan bloklarni ko'rsatadi",
    )

    r = c.delete(f"/blocks/{ann_id}", headers=auth(bob))
    still = c.get("/listings", headers=auth(bob), params={"limit": 50}).json()
    check(
        "boshqaning blokini yecha olmaydi",
        all(
            c.get(f"/listings/{i['id']}").json()["owner"]["id"] != ann_id
            for i in still["items"]
        ),
        "aks holda blok tugmasi hech nimani kafolatlamasdi",
    )

    c.delete(f"/blocks/{bob_id}", headers=auth(ann))

    # --- shikoyat -----------------------------------------------------------

    r = c.post(
        "/reports",
        headers=auth(ann),
        json={"target_type": "user", "target_id": ann_id, "reason": "spam"},
    )
    check("o'zi haqida shikoyat 400 beradi", r.status_code == 400, str(r.status_code))

    r = c.post(
        "/reports",
        headers=auth(ann),
        json={
            "target_type": "listing",
            "target_id": "00000000-0000-0000-0000-000000000000",
            "reason": "spam",
        },
    )
    check("yo'q obyekt haqida shikoyat 404 beradi", r.status_code == 404)

    r = c.post(
        "/reports",
        headers=auth(ann),
        json={
            "target_type": "listing",
            "target_id": victim["id"],
            "reason": "scam",
            "note": "Narxi haqiqiy emas.",
        },
    )
    check("shikoyat qabul qilinadi", r.status_code == 201, str(r.status_code))
    first_id = r.json()["id"]

    r = c.post(
        "/reports",
        headers=auth(ann),
        json={"target_type": "listing", "target_id": victim["id"], "reason": "fake"},
    )
    check(
        "takroriy shikoyat navbatni to'ldirmaydi",
        r.status_code == 201 and r.json()["id"] == first_id,
        "birinchisi o'zgarishsiz qaytadi",
    )

    r = c.post(
        "/reports",
        json={"target_type": "user", "target_id": bob_id, "reason": "spam"},
    )
    check("shikoyat autentifikatsiya talab qiladi", r.status_code == 401)

    r = c.post(
        "/reports",
        headers=auth(ann),
        json={"target_type": "user", "target_id": bob_id, "reason": "bunday-sabab-yoq"},
    )
    check("noma'lum sabab 422 beradi", r.status_code == 422, str(r.status_code))
