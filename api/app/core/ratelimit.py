"""So'rov chastotasini cheklash.

Nega kerak: autentifikatsiya o'z-o'zidan chegara emas. Kirgan foydalanuvchi
ham diskni to'ldirishi, navbatni bo'g'ishi yoki boshqalarga xalaqit berishi
mumkin — va bitta o'g'irlangan hisob buni ataylab qiladi.

Jarayon ichida, Redis'siz. Chat Hub'i bilan bir xil sabab: bitta API
jarayoni bo'lganda bu to'g'ri va harakatlanuvchi qismi yo'q. Ikkinchi
jarayon paydo bo'lganda `Limiter` ning ichi almashtiriladi, chaqiruvchi
kod o'zgarmaydi.
"""

from __future__ import annotations

import time
from collections import deque

from fastapi import HTTPException, Request, status

from app.models.user import User


class Limiter:
    """Oynali hisoblagich — manba bo'yicha."""

    def __init__(self, *, limit: int, window_seconds: int, name: str) -> None:
        self.limit = limit
        self.window = window_seconds
        self.name = name
        self._seen: dict[str, deque[float]] = {}

    def allow(self, key: str, cost: int = 1) -> bool:
        now = time.monotonic()
        window = self._seen.setdefault(key, deque())

        while window and now - window[0] > self.window:
            window.popleft()

        if len(window) + cost > self.limit:
            return False

        window.extend([now] * cost)

        # Bo'shab qolgan kalitlar olib tashlanadi, aks holda lug'at
        # jimgina o'sib boradi.
        if len(self._seen) > 10_000:
            for stale in [k for k, v in self._seen.items() if not v]:
                del self._seen[stale]
        return True

    def check(self, key: str, cost: int = 1) -> None:
        if not self.allow(key, cost):
            raise HTTPException(
                status.HTTP_429_TOO_MANY_REQUESTS,
                "Juda ko'p so'rov yuborildi. Birozdan so'ng urinib ko'ring.",
                headers={"Retry-After": str(self.window)},
            )


def source(request: Request, user: User | None) -> str:
    """
    Kim so'rayapti.

    Kirgan odam hisobi bo'yicha, mehmon manzili bo'yicha. Hisob aniqroq:
    bitta uy yoki ofisdagi bir necha odam bitta tashqi manzil ortida
    turishi mumkin va ular bir-birini cheklab qo'ymasligi kerak.
    """
    if user is not None:
        return f"u:{user.id}"
    client = request.client
    return f"ip:{client.host if client else 'unknown'}"


#: Surat yuklash. Har biri diskka fayl yozadi, ya'ni cheklanmagan yuklash
#: — bu diskni to'ldirish imkoni. Soatiga 60 ta: bir e'longa 8 tagacha
#: surat qo'yiladi, ya'ni bu oddiy foydalanishdan ancha yuqori.
uploads = Limiter(limit=60, window_seconds=3600, name="uploads")

#: E'lon joylash. Bepul kvota bor, lekin u biznes hisoblarga tegishli
#: emas — chegara esa hammaga.
listings = Limiter(limit=30, window_seconds=3600, name="listings")

#: Xabar yuborish. Suhbat tez ketishi mumkin, shuning uchun saxiy;
#: maqsad — avtomatlashtirilgan spam.
messages = Limiter(limit=120, window_seconds=60, name="messages")

#: Taklif yuborish. Bittasi ham qarshi tomonga bildirishnoma yuboradi.
offers = Limiter(limit=30, window_seconds=3600, name="offers")

#: Shikoyat. Moderator navbatini ko'mib tashlashning oldini oladi.
reports = Limiter(limit=20, window_seconds=3600, name="reports")
