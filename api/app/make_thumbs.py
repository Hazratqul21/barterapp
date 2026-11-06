"""Mavjud suratlar uchun lenta nusxalarini yaratish.

    python -m app.make_thumbs

Yangi yuklangan suratlar nusxasini o'zi oladi; bu buyruq eskilari va demo
suratlar uchun. Takroran ishga tushirish xavfsiz — bor nusxaga tegmaydi.
Har deployda avtomatik bajariladi (deploy/remote_install.sh).
"""

from __future__ import annotations

from app.core.config import settings
from app.services import thumbs


def main() -> None:
    root = settings.media_root
    made = skipped = 0
    if root.exists():
        for path in root.rglob("*"):
            if (
                not path.is_file()
                or path.suffix.lower() not in thumbs.SOURCE_EXTS
                or thumbs.is_thumb(path)
            ):
                continue
            target = path.with_name(path.stem + thumbs.SUFFIX + ".jpg")
            if target.exists():
                skipped += 1
            elif thumbs.make(path) is not None:
                made += 1
    print(f"kichik nusxalar: {made} ta yangi, {skipped} ta bor edi")


if __name__ == "__main__":
    main()
