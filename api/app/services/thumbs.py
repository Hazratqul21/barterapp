"""Lenta uchun kichik nusxalar.

Lenta kartochkasi ~180 px kenglikda turadi, lekin unga 1600 px'li, ~200 KB'lik
asl surat yuklanardi: yigirma e'lonli sahifa mobil internetda to'rt megabayt
edi. Har surat yonida `<nom>-t.jpg` (640 px) saqlanadi va kartochka shuni
oladi; e'lon sahifasi asl suratni ko'rsatishda davom etadi.

Nusxa yo'q bo'lsa (eski yuklash, tashqi URL) asl URL qaytadi — hech narsa
buzilmaydi, faqat tejalmaydi. Eskilari uchun: `python -m app.make_thumbs`.
"""

from __future__ import annotations

import logging
from pathlib import Path

from PIL import Image

from app.core.config import settings

log = logging.getLogger("barter.thumbs")

EDGE = 640
QUALITY = 78
SUFFIX = "-t"
SOURCE_EXTS = {".jpg", ".jpeg", ".png", ".webp"}

#: Mavjudligi tekshirilgan nusxalar. Fayl bir marta paydo bo'lgach
#: o'chmaydi (asl surat bilan birga o'chadi), shuning uchun faqat ijobiy
#: javob eslab qolinadi — yangisi keyingi so'rovda topiladi.
_known: set[str] = set()


def thumb_name(name: str) -> str:
    """`ab12.jpg` → `ab12-t.jpg`; `demo/x.png` → `demo/x-t.jpg`."""
    path = Path(name)
    return str(path.with_name(path.stem + SUFFIX + ".jpg"))


def is_thumb(path: Path) -> bool:
    return path.stem.endswith(SUFFIX)


def make(source: Path) -> Path | None:
    """`source` yonida nusxa yaratadi. Allaqachon bo'lsa — tegmaydi."""
    target = source.with_name(source.stem + SUFFIX + ".jpg")
    if target.exists():
        return target
    try:
        with Image.open(source) as image:
            image = image.convert("RGB")
            image.thumbnail((EDGE, EDGE), Image.LANCZOS)
            image.save(target, format="JPEG", quality=QUALITY, optimize=True)
    except Exception as exc:  # noqa: BLE001 — buzuq fayl kartochkani to'xtatmasin
        log.warning("Kichik nusxa bo'lmadi (%s): %s", source.name, type(exc).__name__)
        return None
    return target


def card_url(url: str | None) -> str | None:
    """Kartochka uchun URL: o'zimizning surat bo'lsa va nusxasi bor bo'lsa — nusxa."""
    if not url:
        return url
    marker = settings.media_url_prefix.rstrip("/") + "/"
    idx = url.find(marker)
    if idx == -1 or "?" in url:
        return url
    relative = url[idx + len(marker):]
    small = thumb_name(relative)
    if small not in _known:
        if not (settings.media_root / small).is_file():
            return url
        _known.add(small)
    return url[: idx + len(marker)] + small
