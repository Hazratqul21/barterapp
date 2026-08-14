"""Lenta: qidiruv, filtrlar va saralash.

Yopilgan kamchiliklar:

- Qidiruv tilga qulflangan edi (`locale == joriy til`). Har bir e'lon uchta
  tilda saqlanadi, shuning uchun rus tilida yurgan odam o'zbekcha so'z yozsa
  bo'sh lenta olardi. Endi barcha tillar bo'ylab qidiriladi, natijada esa
  e'lon bir marta chiqadi.
- `%` va `_` LIKE uchun joker belgi — "50%" deb qidirish hamma narsani
  qaytarardi. Endi ekranlanadi.
- Narx oralig'i, viloyat, "pulga rozi" filtrlari va narx bo'yicha saralash
  umuman yo'q edi.
- Saralash o'zgarganda kursor buzilmasligi kerak: kursor saralanayotgan
  kalitni tashiydi, `id` esa teng qiymatlarni ajratadi.
"""

import httpx

BASE = "http://127.0.0.1:8010"


def check(label: str, ok: bool, extra: str = "") -> None:
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f"  — {extra}" if extra else ""))
    if not ok:
        raise SystemExit(1)


def ids(page: dict) -> list[str]:
    return [item["id"] for item in page["items"]]


with httpx.Client(base_url=BASE, timeout=30) as c:
    everything = c.get("/listings", params={"limit": 50}).json()
    check("lentada e'lonlar bor", len(everything["items"]) >= 3, str(len(everything["items"])))

    # --- narx oralig'i ------------------------------------------------------

    values = sorted(item["value"]["minor"] for item in everything["items"])
    floor = values[len(values) // 2]

    r = c.get("/listings", params={"min_value": floor, "limit": 50}).json()
    check(
        "min_value arzonlarni kesadi",
        all(i["value"]["minor"] >= floor for i in r["items"]),
        f"chegara={floor}",
    )
    check("min_value hammasini yo'q qilmaydi", len(r["items"]) >= 1)

    r = c.get("/listings", params={"max_value": floor, "limit": 50}).json()
    check(
        "max_value qimmatlarni kesadi",
        all(i["value"]["minor"] <= floor for i in r["items"]),
    )

    r = c.get("/listings", params={"min_value": 100, "max_value": 50})
    check("teskari oraliq 400 beradi", r.status_code == 400, str(r.status_code))

    # --- saralash -----------------------------------------------------------

    cheap = c.get("/listings", params={"sort": "cheap", "limit": 50}).json()
    got = [i["value"]["minor"] for i in cheap["items"]]
    check("sort=cheap o'sish tartibida", got == sorted(got), str(got[:4]))

    pricey = c.get("/listings", params={"sort": "expensive", "limit": 50}).json()
    got = [i["value"]["minor"] for i in pricey["items"]]
    check("sort=expensive kamayish tartibida", got == sorted(got, reverse=True))

    check(
        "ikkala saralash ham bir xil to'plamni qaytaradi",
        set(ids(cheap)) == set(ids(everything)),
        "filtr emas, faqat tartib o'zgaradi",
    )

    # --- saralash bilan sahifalash ------------------------------------------

    first = c.get("/listings", params={"sort": "cheap", "limit": 2}).json()
    check("kichik sahifa kursor beradi", first["next_cursor"] is not None)

    second = c.get(
        "/listings",
        params={"sort": "cheap", "limit": 50, "cursor": first["next_cursor"]},
    ).json()
    check(
        "keyingi sahifa takrorlanmaydi",
        not (set(ids(first)) & set(ids(second))),
        "kursor saralash kalitini tashiydi",
    )
    check(
        "ikki sahifa birgalikda hammasini qamraydi",
        set(ids(first)) | set(ids(second)) == set(ids(cheap)),
        "hech bir e'lon tushib qolmaydi",
    )

    last_of_first = [i["value"]["minor"] for i in first["items"]][-1]
    check(
        "ikkinchi sahifa birinchisidan arzon emas",
        all(i["value"]["minor"] >= last_of_first for i in second["items"]),
    )

    r = c.get("/listings", params={"cursor": "bu-kursor-emas"})
    check("buzuq kursor 400 beradi", r.status_code == 400, str(r.status_code))

    # --- qidiruv barcha tillarda --------------------------------------------

    sample = c.get(f"/listings/{everything['items'][0]['id']}", headers={"Accept-Language": "uz"}).json()
    word = sample["title"].split()[0]

    for lang in ("uz", "ru", "en"):
        r = c.get(
            "/listings",
            params={"q": word, "limit": 50},
            headers={"Accept-Language": lang},
        ).json()
        check(
            f"'{word}' {lang} tilida ham topiladi",
            sample["id"] in ids(r),
            "qidiruv tarjimaga qulflanmagan",
        )

    r = c.get("/listings", params={"q": word, "limit": 50}).json()
    check(
        "qidiruvda e'lon takrorlanmaydi",
        len(ids(r)) == len(set(ids(r))),
        "uch tilli join dublikat bermaydi",
    )

    r = c.get("/listings", params={"q": "%", "limit": 50}).json()
    check(
        "'%' joker sifatida ishlamaydi",
        len(r["items"]) < len(everything["items"]),
        f"{len(r['items'])} / {len(everything['items'])}",
    )

    r = c.get("/listings", params={"q": "zzqwxyz-yoq", "limit": 50}).json()
    check("topilmaydigan so'z bo'sh qaytaradi", r["items"] == [])

    # --- boshqa filtrlar ----------------------------------------------------

    r = c.get("/listings", params={"cash_ok": "true", "limit": 50}).json()
    check("cash_ok filtri ishlaydi", all(i["cash_ok"] for i in r["items"]))

    r = c.get("/listings", params={"region": "Bunday-viloyat-yoq", "limit": 50}).json()
    check("noma'lum viloyat bo'sh qaytaradi", r["items"] == [])

    # Manfiy holatning o'zi yetarli emas: filtr hamma narsani kesib tashlasa
    # ham u sinovdan o'tib ketardi. Shuning uchun haqiqiy viloyat ham kerak.
    regions = c.get("/regions").json()
    hit = next(
        (
            name
            for name in regions
            if c.get("/listings", params={"region": name, "limit": 50}).json()["items"]
        ),
        None,
    )
    check("haqiqiy viloyat bo'yicha e'lon topiladi", hit is not None, str(hit))

    inside = c.get("/listings", params={"region": hit, "limit": 50}).json()
    check(
        "viloyat filtri lentani toraytiradi",
        0 < len(inside["items"]) <= len(everything["items"]),
        f"{hit}: {len(inside['items'])} / {len(everything['items'])}",
    )

    r = c.get(
        "/listings", params={"tag": "electronics", "sort": "cheap", "limit": 50}
    ).json()
    check(
        "filtr va saralash birga ishlaydi",
        all(i["tag"] == "electronics" for i in r["items"])
        and [i["value"]["minor"] for i in r["items"]]
        == sorted(i["value"]["minor"] for i in r["items"]),
    )
