"""Kategoriya ro'yxati — uch tilda, ishlaydigan rasmlar bilan.

Ilgari bu endpoint yo'q edi va mijozlar o'z nusxasini olib yurardi: nomlar
qattiq o'zbekcha (RU/EN buildlarda ham o'zbekcha chiqardi) va rasm id'lari
eskirib, yarmi 404 berardi. Endi ro'yxat serverdan keladi.
"""

import httpx

BASE = "http://127.0.0.1:8010"
TAGS = {"agri", "livestock", "machinery", "transport", "electronics", "construction"}


def check(label: str, ok: bool, extra: str = "") -> None:
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f"  — {extra}" if extra else ""))
    if not ok:
        raise SystemExit(1)


with httpx.Client(base_url=BASE, timeout=30) as c:
    r = c.get("/categories", headers={"Accept-Language": "uz"})
    check("ro'yxat ochiq (autentifikatsiyasiz, 200)", r.status_code == 200)
    uz = r.json()
    check("oltita kategoriya", len(uz) == 6, str(len(uz)))
    check("id'lar ListingTag qiymatlari", {c_["id"] for c_ in uz} == TAGS,
          str({c_["id"] for c_ in uz} ^ TAGS))

    ru = c.get("/categories", headers={"Accept-Language": "ru"}).json()
    en = c.get("/categories", headers={"Accept-Language": "en"}).json()

    check("uz nomlari o'zbekcha", uz[0]["name"].startswith("Qishloq"), uz[0]["name"])
    check("ru nomlari ruscha", ru[0]["name"] == "Сельское хозяйство", ru[0]["name"])
    check("en nomlari inglizcha", en[0]["name"] == "Agriculture", en[0]["name"])
    check("uchala til ham farq qiladi",
          len({uz[0]["name"], ru[0]["name"], en[0]["name"]}) == 3)

    # Tartib tillar bo'ylab bir xil — mijoz id bo'yicha moslashtiradi.
    check("tartib tillar bo'ylab bir xil",
          [x["id"] for x in uz] == [x["id"] for x in ru] == [x["id"] for x in en])

    check("har birida rasm bor",
          all(x["image_url"].startswith("https://") for x in uz))

    # Til berilmasa standart tilga tushadi, xato bermaydi.
    plain = c.get("/categories")
    check("Accept-Language'siz ham ishlaydi", plain.status_code == 200)

    # Har bir kategoriya id'si lenta filtri sifatida ishlashi kerak.
    for tag in sorted(TAGS):
        fr = c.get("/listings", params={"tag": tag}, headers={"Accept-Language": "uz"})
        if fr.status_code != 200:
            check(f"'{tag}' filtri ishlaydi", False, fr.text[:120])
    check("har bir id lenta filtri sifatida qabul qilinadi", True)

    # Rasmlar haqiqatan yuklanadimi — o'lik id qaytmasligi kerak.
    dead = []
    for x in uz:
        head = httpx.head(x["image_url"], timeout=15, follow_redirects=True)
        if head.status_code != 200:
            dead.append((x["id"], head.status_code))
    check("hamma rasm yuklanadi (404 yo'q)", not dead, str(dead))
