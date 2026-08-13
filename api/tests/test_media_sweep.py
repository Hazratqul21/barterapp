"""B5: yuklangan fayllarni tozalash — hech bir yozuv ko'rsatmaydigan "yetim"
rasm fayllari diskdan o'chiriladi, biroq (a) e'lon/avatar tomonidan
ko'rsatilgan fayllar va (b) grace oynasidan yosh (endigina yuklangan, hali
yozuvga bog'lanmagan) fayllar saqlanadi."""

import asyncio
import io
import sys
from pathlib import Path

import httpx
from PIL import Image

# Boshqa sinovlar sof HTTP; bu esa grace oynasini nolga tushirib determinik
# tekshirish uchun app kodini to'g'ridan-to'g'ri chaqiradi, shuning uchun `api/`
# ni import yo'liga qo'shamiz.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.core.config import settings  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402
from app.services.media import _local_name, sweep_orphans  # noqa: E402

BASE = "http://127.0.0.1:8010"


def check(label: str, ok: bool, extra: str = "") -> None:
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f"  — {extra}" if extra else ""))
    if not ok:
        raise SystemExit(1)


def access_token(c: httpx.Client, phone: str) -> str:
    code = c.post("/auth/otp/request", json={"phone": phone}).json()["debug_code"]
    return c.post("/auth/otp/verify", json={"phone": phone, "code": code}).json()[
        "access_token"
    ]


def a_photo() -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (64, 64), (120, 180, 90)).save(buf, format="JPEG")
    return buf.getvalue()


async def sweep(grace: int = 0, dry_run: bool = False):
    async with SessionLocal() as db:
        return await sweep_orphans(db, grace_seconds=grace, dry_run=dry_run)


with httpx.Client(base_url=BASE, timeout=30) as c:
    H = {"Authorization": f"Bearer {access_token(c, '+998901234122')}"}

    # Ikkita rasm yuklaymiz: bittasi e'longa biriktiriladi, ikkinchisi yetim.
    kept = c.post(
        "/uploads", headers=H,
        files={"file": ("keep.jpg", a_photo(), "image/jpeg")},
    ).json()["url"]
    orphan = c.post(
        "/uploads", headers=H,
        files={"file": ("orphan.jpg", a_photo(), "image/jpeg")},
    ).json()["url"]

    kept_name = _local_name(kept)
    orphan_name = _local_name(orphan)
    check("yuklangan URL lokal faylga ishora qiladi", bool(kept_name and orphan_name))

    def tri(v):
        return {"uz": v, "ru": v, "en": v}

    # `kept` rasmini ishlatgan e'lon yaratamiz.
    created = c.post("/listings", headers=H, json={
        "tag": "electronics",
        "title": tri("Sinov buyum"),
        "description": tri("Sinov tavsifi bu yerda."),
        "image_alt": tri("sinov"),
        "category": tri("Elektronika"),
        "condition": tri("Yaxshi"),
        "quantity": tri("1 dona"),
        "wants_summary": tri("biror narsa"),
        "wants": [tri("biror narsa")],
        "desires": [{"category": None, "will_add_cash": True, "wants_cash": False}],
        "photos": [kept],
        "value": {"minor": 500000000, "currency": "UZS"},
        "cash_ok": True,
    })
    check("e'lon yaratildi", created.status_code == 201, created.text[:200])

media = settings.media_root
check("ikkala fayl ham diskda", (media / kept_name).exists() and (media / orphan_name).exists())


async def checks():
    # grace=6soat: hozir yuklangan ikkala faylim ham yosh — o'chmaydi. (Media
    # jildidagi eski yetimlar o'chishi mumkin; bu ayni sweep ishi, xato emas.)
    young = await sweep(grace=6 * 3600)
    check("yosh biriktirilgan fayl saqlandi", kept_name not in young.removed)
    check("yosh yetim fayl ham saqlandi", orphan_name not in young.removed)
    check("ikkala yangi fayl ham diskda qoldi",
          (media / kept_name).exists() and (media / orphan_name).exists())

    # dry-run grace=0: yetim ro'yxatga tushadi, lekin o'chmaydi.
    dry = await sweep(grace=0, dry_run=True)
    check("dry-run yetimni topadi", orphan_name in dry.removed)
    check("dry-run hech nima o'chirmaydi", (media / orphan_name).exists())

    # grace=0: yetim o'chadi, biriktirilgan fayl qoladi.
    real = await sweep(grace=0)
    check("yetim fayl o'chirildi",
          orphan_name in real.removed and not (media / orphan_name).exists())
    check("biriktirilgan fayl saqlandi",
          kept_name not in real.removed and (media / kept_name).exists())


asyncio.run(checks())
