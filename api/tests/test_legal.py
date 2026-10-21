"""Huquqiy hujjatlar: ochiq sahifa va admin tahriri.

- migratsiya to'rtta asosiy hujjatni (privacy, terms, offer, delete-account)
  boshlang'ich matn bilan yaratadi;
- `/legal/<slug>` — tayyor HTML, tilni `?lang=` yoki Accept-Language'dan oladi,
  tarjimasi yo'q til o'zbekchaga qaytadi;
- Markdown'dagi xom HTML va `javascript:` havola sahifaga tushmaydi;
- admin tahrirlaydi, yangi hujjat qo'shadi, PDF yuklaydi; asosiy hujjatni
  o'chirib/yashirib bo'lmaydi; moderator bo'lmagan odam endpointni ko'rmaydi.
"""

import asyncio
import sys
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import select  # noqa: E402

from app.db.session import SessionLocal  # noqa: E402
from app.models.legal import LegalDocument  # noqa: E402
from app.models.user import User  # noqa: E402

BASE = "http://127.0.0.1:8010"
MODERATOR_PHONE = "+998901234133"
USER_PHONE = "+998901110033"

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


async def set_moderator() -> None:
    async with SessionLocal() as db:
        user = await db.scalar(select(User).where(User.phone == MODERATOR_PHONE))
        user.is_moderator = True
        await db.commit()


async def drop_extra() -> None:
    async with SessionLocal() as db:
        doc = await db.get(LegalDocument, "cookies")
        if doc is not None:
            await db.delete(doc)
            await db.commit()


def main() -> None:
    run(drop_extra())
    with httpx.Client(base_url=BASE, timeout=20) as c:
        listed = c.get("/legal").json()
        slugs = [d["slug"] for d in listed]
        check("4 ta asosiy hujjat bor", slugs[:4] == ["privacy", "terms", "offer", "delete-account"], str(slugs))
        check("havola mab.uz da", listed[0]["url"] == "https://mab.uz/privacy", listed[0]["url"])

        page = c.get("/legal/privacy", params={"lang": "uz"})
        check("sahifa HTML", page.status_code == 200 and "text/html" in page.headers["content-type"])
        check("CSP bor", "default-src 'none'" in page.headers.get("content-security-policy", ""))
        check("sarlavha ikki marta chiqmaydi", page.text.count("Maxfiylik siyosati</h1>") == 1
              and "MAB — Maxfiylik siyosati</h1>" not in page.text)
        ru = c.get("/legal/terms", headers={"Accept-Language": "ru-RU,ru;q=0.9"})
        check("Accept-Language → ru", 'lang="ru"' in ru.text and "Условия использования" in ru.text)
        check("tarjima yo'q → ogohlantirish", "Перевод пока не готов" in ru.text)
        check("yo'q hujjat 404", c.get("/legal/yoq-hujjat").status_code == 404)

        mod = login(c, MODERATOR_PHONE)
        run(set_moderator())
        user = login(c, USER_PHONE)

        check("oddiy foydalanuvchiga admin yo'q",
              c.get("/admin/legal", headers=auth(user)).status_code == 404)
        docs = c.get("/admin/legal", headers=auth(mod)).json()
        privacy = next(d for d in docs if d["slug"] == "privacy")
        check("shablon belgilari aniqlanadi", privacy["has_placeholders"] is True)
        check("asosiy hujjat belgisi", privacy["is_core"] is True)
        terms_before = next(d for d in docs if d["slug"] == "terms")

        r = c.put("/admin/legal/terms", headers=auth(mod), json={
            "title": {"uz": "Foydalanish shartlari", "ru": "Условия использования"},
            "body": {
                "uz": "## Yangi band\n\nMatn <script>alert(1)</script> "
                      "[havola](javascript:alert(1)) va [sayt](https://mab.uz).",
                "ru": "## Новый пункт\n\nТекст.",
            },
            "is_published": True,
            "position": 20,
        })
        check("tahrir saqlandi", r.status_code == 200, r.text[:200])
        page = c.get("/legal/terms", params={"lang": "uz"}).text
        check("yangi matn saytda", "Yangi band" in page)
        check("xom HTML qochirildi", "<script>" not in page and "&lt;script&gt;" in page)
        check("javascript: havola yo'q", 'href="javascript:' not in page)
        check("oddiy havola bor", 'href="https://mab.uz"' in page)
        check("ru tarjima ko'rinadi", "Новый пункт" in c.get("/legal/terms", params={"lang": "ru"}).text)

        bad = c.put("/admin/legal/terms", headers=auth(mod), json={
            "title": {"uz": "Shartlar"}, "body": {"uz": "x"}, "is_published": False,
        })
        check("asosiy hujjat yashirilmaydi", bad.status_code == 409, str(bad.status_code))
        check("asosiy hujjat o'chirilmaydi",
              c.delete("/admin/legal/privacy", headers=auth(mod)).status_code == 409)
        check("o'zbekcha matnsiz saqlanmaydi", c.put("/admin/legal/terms", headers=auth(mod), json={
            "title": {"uz": "Shartlar"}, "body": {"ru": "x"},
        }).status_code == 422)
        check("noto'g'ri slug rad etiladi", c.put("/admin/legal/Yomon_Nom", headers=auth(mod), json={
            "title": {"uz": "X"}, "body": {"uz": "x"},
        }).status_code == 422)

        new = c.put("/admin/legal/cookies", headers=auth(mod), json={
            "title": {"uz": "Cookie siyosati"}, "body": {"uz": "Matn"}, "position": 50,
        })
        check("yangi hujjat yaratildi", new.status_code == 200, new.text[:200])
        check("yangi hujjat manzili /legal/", new.json()["url"] == "https://mab.uz/legal/cookies")
        check("yangi hujjat ochiq", c.get("/legal/cookies").status_code == 200)

        not_pdf = c.post("/admin/legal/cookies/file", headers=auth(mod),
                         files={"file": ("x.pdf", b"hello", "application/pdf")})
        check("PDF bo'lmagan fayl rad etiladi", not_pdf.status_code == 415, str(not_pdf.status_code))
        pdf = c.post("/admin/legal/cookies/file", headers=auth(mod),
                     files={"file": ("x.pdf", b"%PDF-1.4\n%test\n", "application/pdf")})
        check("PDF yuklandi", pdf.status_code == 200 and pdf.json()["file_url"], pdf.text[:200])
        file_url = pdf.json()["file_url"]
        path = "/" + file_url.split("/", 3)[3]
        check("PDF ochiladi", c.get(path).content.startswith(b"%PDF-"), path)
        check("sahifada PDF havolasi", file_url in c.get("/legal/cookies").text)

        hidden = c.put("/admin/legal/cookies", headers=auth(mod), json={
            "title": {"uz": "Cookie siyosati"}, "body": {"uz": "Matn"}, "is_published": False,
        })
        check("yashirilgan hujjat 404", hidden.status_code == 200
              and c.get("/legal/cookies").status_code == 404)
        check("o'chirildi", c.delete("/admin/legal/cookies", headers=auth(mod)).status_code == 204)
        check("PDF fayli ham o'chdi", c.get(path).status_code == 404)

        restored = c.put("/admin/legal/terms", headers=auth(mod), json={
            k: terms_before[k] for k in ("title", "body", "is_published", "position")
        })
        check("shartlar asl holiga qaytdi", restored.status_code == 200)

    print("\nHammasi o'tdi.")


if __name__ == "__main__":
    main()
