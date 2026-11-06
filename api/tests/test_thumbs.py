"""Lenta uchun kichik suratlar.

- Yuklashda nusxa yaratiladi; kartochka nusxani, e'lon sahifasi asl suratni oladi.
- Nusxa yo'q yoki tashqi URL bo'lsa — asl URL (hech narsa buzilmaydi).
- Tozalash nusxani asl surat bilan birga saqlaydi.
- Media javobi uzoq keshlanadi.
"""

import sys
from pathlib import Path

import httpx
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.core.config import settings  # noqa: E402
from app.services import thumbs  # noqa: E402

BASE = "http://127.0.0.1:8010"
failures = 0


def check(name: str, ok: bool, detail: str = "") -> None:
    global failures
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else f" — {detail}"))
    if not ok:
        failures += 1


check("nom", thumbs.thumb_name("ab.jpg") == "ab-t.jpg")
check("ichki papka", thumbs.thumb_name("demo/x.png") == "demo/x-t.jpg")
check("tashqi URL tegilmaydi", thumbs.card_url("https://images.example/a.jpg") == "https://images.example/a.jpg")
check("bo'sh URL", thumbs.card_url(None) is None)
missing = f"https://api.mab.uz{settings.media_url_prefix}/yoq-fayl.jpg"
check("nusxasiz — asl URL", thumbs.card_url(missing) == missing)

src = settings.media_root / "thumbtest.jpg"
src.parent.mkdir(parents=True, exist_ok=True)
Image.new("RGB", (1600, 1200), (120, 140, 90)).save(src, quality=90)
made = thumbs.make(src)
check("nusxa yaratildi", made is not None and made.exists())
with Image.open(made) as im:
    check("nusxa 640 px", max(im.size) == 640, str(im.size))
url = f"https://api.mab.uz{settings.media_url_prefix}/thumbtest.jpg"
check("kartochka nusxani oladi", thumbs.card_url(url).endswith("/thumbtest-t.jpg"), thumbs.card_url(url))
check("nusxa kichikroq", made.stat().st_size < src.stat().st_size)

with httpx.Client(base_url=BASE, timeout=30) as c:
    r = c.get(f"{settings.media_url_prefix}/thumbtest-t.jpg")
    check("media 200", r.status_code == 200, str(r.status_code))
    check("media uzoq keshlanadi", "max-age=2592000" in r.headers.get("cache-control", ""), str(r.headers))

src.unlink(missing_ok=True)
made.unlink(missing_ok=True)

print(f"\n{'OK' if not failures else f'{failures} ta xato'}")
sys.exit(1 if failures else 0)
