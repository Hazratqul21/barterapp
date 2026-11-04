"""Google OAuth client ID'lari: admin panel, keyin `.env`.

Ikki xil ID bor va ular almashtirilsa Google orqali kirish jimgina buziladi:

- **Web** — ilova uni `serverClientId` sifatida, sayt `client_id` sifatida
  ishlatadi, shuning uchun ID tokenning `aud`i shu bo'ladi. Tugma faqat
  shu ID bor bo'lganda ko'rinadi.
- **Android** — ilova uni hech qayerda ishlatmaydi: Google uni package nomi
  va SHA-1 bo'yicha o'zi taniydi. Server uni faqat qabul qilinadigan
  auditoriyaga qo'shadi. U `serverClientId` bo'lib ketsa, Android'da kirish
  «Developer console is not set up correctly» bilan yiqiladi — shuning uchun
  ular alohida maydonda saqlanadi va tugmani yoqmaydi.
"""

from __future__ import annotations

import json
import logging
import re
from dataclasses import dataclass

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.services import settings_store

log = logging.getLogger("barter.google")

CLIENT_ID = re.compile(r"^[0-9]+-[a-z0-9]+\.apps\.googleusercontent\.com$")


@dataclass(frozen=True)
class GoogleClients:
    #: Birinchisi mijozlarga beriladi.
    web: tuple[str, ...]
    android: tuple[str, ...]
    #: "panel" yoki "env" — web ID qayerdan olingan.
    source: str | None

    @property
    def enabled(self) -> bool:
        return bool(self.web)

    @property
    def client_id(self) -> str | None:
        return self.web[0] if self.web else None

    @property
    def audience(self) -> list[str]:
        return list(dict.fromkeys(self.web + self.android))


async def panel_value(db: AsyncSession) -> dict:
    raw = await settings_store.get(db, settings_store.GOOGLE_CLIENT)
    if not raw:
        return {}
    try:
        value = json.loads(raw)
        return value if isinstance(value, dict) else {}
    except ValueError:
        log.error("Bazadagi Google sozlamasi o'qilmadi — e'tiborsiz qoldirildi.")
        return {}


async def resolve(db: AsyncSession) -> GoogleClients:
    stored = await panel_value(db)
    panel_web = stored.get("web_client_id") or None
    panel_android = tuple(stored.get("android_client_ids") or ())

    if panel_web:
        web = (panel_web, *(i for i in settings.google_client_ids if i != panel_web))
        source = "panel"
    else:
        web = tuple(settings.google_client_ids)
        source = "env" if web else None

    android = tuple(
        dict.fromkeys(
            i for i in (*panel_android, *settings.google_android_client_ids)
            if i not in web
        )
    )
    return GoogleClients(web=web, android=android, source=source)
