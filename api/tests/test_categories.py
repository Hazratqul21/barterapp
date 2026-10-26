"""Kategoriya ro'yxati — uch tilda — va admin almashtiradigan rasmlar.

- `/categories` ochiq, oltita kategoriya, nomlari so'ralgan tilda;
- rasm yuklanmagan bo'lsa `image_url` null (ilova o'z rasmini ko'rsatadi);
- moderator rasm yuklaydi → kvadrat JPEG, `/categories` da darhol chiqadi;
- «standartga qaytarish» rasmni o'chiradi va faylni ham olib tashlaydi;
- moderator bo'lmagan odam endpointni ko'rmaydi (404), rasm bo'lmagan fayl 400.
"""

import asyncio
import io
import sys
from pathlib import Path

import httpx
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import select  # noqa: E402

from app.core.config import settings  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402
from app.models.user import User  # noqa: E402

BASE = "http://127.0.0.1:8010"
TAGS = {"agri", "livestock", "machinery", "transport", "electronics", "construction"}
MODERATOR_PHONE = "+998901234134"
USER_PHONE = "+998901110034"

_loop = asyncio.new_event_loop()
asyncio.set_event_loop(_loop)
run = _loop.run_until_complete


def check(label: str, ok: bool, extra: str = "") -> None:
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f"  — {extra}" if extra else ""))
    if not ok:
        raise SystemExit(1)


def login(c: httpx.Client, phone: str) -> dict:
    code = c.post("/auth/otp/request", json={"phone": phone}).json()["debug_code"]
    token = c.post("/auth/otp/verify", json={"phone": phone, "code": code}).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


async def set_moderator() -> None:
    async with SessionLocal() as db:
        user = await db.scalar(select(User).where(User.phone == MODERATOR_PHONE))
        user.is_moderator = True
        await db.commit()


def png(width: int, height: int) -> bytes:
    buffer = io.BytesIO()
    Image.new("RGB", (width, height), (90, 110, 60)).save(buffer, format="PNG")
    return buffer.getvalue()


def by_id(rows: list[dict]) -> dict[str, dict]:
    return {row["id"]: row for row in rows}


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
    check("tartib tillar bo'ylab bir xil",
          [x["id"] for x in uz] == [x["id"] for x in ru] == [x["id"] for x in en])

    plain = c.get("/categories")
    check("Accept-Language'siz ham ishlaydi", plain.status_code == 200)

    for tag in sorted(TAGS):
        fr = c.get("/listings", params={"tag": tag}, headers={"Accept-Language": "uz"})
        if fr.status_code != 200:
            check(f"'{tag}' filtri ishlaydi", False, fr.text[:120])
    check("har bir id lenta filtri sifatida qabul qilinadi", True)

    # --- Admin: rasm almashtirish -------------------------------------------
    user = login(c, USER_PHONE)
    mod = login(c, MODERATOR_PHONE)
    run(set_moderator())

    check("oddiy foydalanuvchi ko'rmaydi (404)",
          c.get("/admin/categories", headers=user).status_code == 404)
    check("oddiy foydalanuvchi yuklay olmaydi (404)",
          c.post("/admin/categories/agri/image", headers=user,
                 files={"file": ("a.png", png(10, 10), "image/png")}).status_code == 404)

    c.delete("/admin/categories/agri/image", headers=mod)  # oldingi ishga tushirishdan qolgan bo'lsa
    check("yuklanmagan bo'lsa image_url null",
          by_id(c.get("/categories").json())["agri"]["image_url"] is None)

    listed = c.get("/admin/categories", headers=mod)
    check("admin ro'yxati: oltita, uch tilda nom",
          listed.status_code == 200 and len(listed.json()) == 6
          and set(listed.json()[0]["name"]) == {"uz", "ru", "en"}, listed.text[:200])

    check("noma'lum kategoriya → 404",
          c.post("/admin/categories/cars/image", headers=mod,
                 files={"file": ("a.png", png(10, 10), "image/png")}).status_code == 404)
    check("rasm bo'lmagan fayl → 400",
          c.post("/admin/categories/agri/image", headers=mod,
                 files={"file": ("a.png", b"not an image", "image/png")}).status_code == 400)

    up = c.post("/admin/categories/agri/image", headers=mod,
                files={"file": ("wide.png", png(1600, 900), "image/png")})
    check("moderator yuklaydi", up.status_code == 200, up.text[:200])
    url = by_id(up.json())["agri"]["image_url"]
    check("javobda yangi rasm manzili", bool(url) and "/categories/agri-" in url, str(url))

    public = by_id(c.get("/categories").json())["agri"]["image_url"]
    check("ochiq /categories da darhol chiqadi", public == url, str(public))

    served = httpx.get(url, timeout=15)
    image = Image.open(io.BytesIO(served.content))
    check("rasm ochiladi va kvadrat JPEG, 600 px",
          served.status_code == 200 and image.format == "JPEG" and image.size == (600, 600),
          f"{served.status_code} {image.format} {image.size}")

    first_file = settings.media_root / url.split(settings.media_url_prefix + "/", 1)[1]
    again = c.post("/admin/categories/agri/image", headers=mod,
                   files={"file": ("sq.png", png(300, 300), "image/png")})
    second = by_id(again.json())["agri"]["image_url"]
    check("qayta yuklash yangi manzil beradi", second != url)
    check("eski fayl o'chirildi", not first_file.exists())

    reset = c.delete("/admin/categories/agri/image", headers=mod)
    check("standartga qaytarish", reset.status_code == 200
          and by_id(reset.json())["agri"]["image_url"] is None)
    check("ochiq ro'yxatda yana null",
          by_id(c.get("/categories").json())["agri"]["image_url"] is None)
    second_file = settings.media_root / second.split(settings.media_url_prefix + "/", 1)[1]
    check("fayl ham o'chirildi", not second_file.exists())

print("\nHammasi o'tdi.")
