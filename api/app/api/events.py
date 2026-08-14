from __future__ import annotations

import time
import uuid
from collections import deque
from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import Field, field_validator
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.locale import resolve_locale
from app.core.security import optional_user
from app.db.session import get_db
from app.models.event import EventKind
from app.models.user import User
from app.schemas.common import ApiModel
from app.services import events as service

router = APIRouter(tags=["events"])

#: Kelajakdagi yoki juda eski vaqt tamg'asi qabul qilinmaydi. Mijozdagi soat
#: xato bo'lishi mumkin, tahlil esa vaqtga tayanadi — bir kunlik siljish
#: butun kunlik hisobotni buzadi.
MAX_SKEW = timedelta(hours=24)

#: Bir manbadan daqiqasiga nechta hodisa qabul qilinadi.
#:
#: Bu endpoint ataylab autentifikatsiyasiz — anonim ko'rish tahlilning
#: yarmi. Lekin autentifikatsiyasiz yozish har kimga bazani to'ldirish
#: imkonini beradi, va soxta hodisalar bilan to'lgan jadval bo'sh jadvaldan
#: yomonroq: u yolg'on xulosa chiqaradi. Chegara saxiy — jadal aylantirilgan
#: lenta daqiqasiga 200-300 ko'rsatish berishi mumkin — lekin cheksiz emas.
RATE_MAX_EVENTS = 600
RATE_WINDOW_SECONDS = 60


class _RateLimiter:
    """
    Manba bo'yicha oynali hisoblagich.

    Jarayon ichida, Redis'siz — chat Hub'i bilan bir xil sabab: bitta API
    jarayoni bo'lganda bu to'g'ri va harakatlanuvchi qismi yo'q. Ikkinchi
    jarayon paydo bo'lganda ichi almashtiriladi, tashqarisi o'zgarmaydi.
    """

    def __init__(self) -> None:
        self._seen: dict[str, deque[float]] = {}

    def allow(self, key: str, cost: int) -> bool:
        now = time.monotonic()
        window = self._seen.setdefault(key, deque())

        while window and now - window[0] > RATE_WINDOW_SECONDS:
            window.popleft()

        if len(window) + cost > RATE_MAX_EVENTS:
            return False

        window.extend([now] * cost)

        # Jimgina o'sib ketmasin: bo'shab qolgan kalitlar olib tashlanadi.
        if len(self._seen) > 10_000:
            for stale in [k for k, v in self._seen.items() if not v]:
                del self._seen[stale]
        return True


_limiter = _RateLimiter()


class EventIn(ApiModel):
    kind: EventKind
    target_type: str | None = Field(default=None, max_length=20)
    target_id: uuid.UUID | None = None
    payload: dict = Field(default_factory=dict)
    occurred_at: datetime | None = None
    #: Mijoz yaratadigan noyob kalit. Bo'lmasa takroriy yuborish sonlarni
    #: ikki barobar qilib ko'rsatadi.
    dedupe_key: str | None = Field(default=None, max_length=64)

    @field_validator("payload")
    @classmethod
    def _small(cls, value: dict) -> dict:
        """
        Yuk kichik qolsin.

        Cheklovsiz JSON — bu jadvalning cheksiz o'sishi va so'rov tanasiga
        istalgan narsani tiqib yuborish imkoni. Tahlil uchun bir nechta
        maydon yetarli.
        """
        if len(value) > 20:
            raise ValueError("payload juda katta (20 dan ortiq maydon).")
        return value


class EventBatch(ApiModel):
    events: list[EventIn] = Field(min_length=1, max_length=service.MAX_BATCH)
    #: Kirmagan odamning ko'rish seansi. Mijoz yaratadi va ilova ochiq
    #: turganda saqlaydi.
    session_id: str | None = Field(default=None, max_length=64)
    platform: str | None = Field(default=None, max_length=10)


class BatchResult(ApiModel):
    accepted: int
    #: Takror sifatida tashlanganlar. Mijoz buni xato deb ko'rsatmasin —
    #: bu muvaffaqiyatli qayta yuborish.
    duplicates: int


@router.post("/events", response_model=BatchResult)
async def collect(
    batch: EventBatch,
    request: Request,
    locale: str = Depends(resolve_locale),
    viewer: User | None = Depends(optional_user),
    db: AsyncSession = Depends(get_db),
) -> BatchResult:
    """
    Mijozdagi hodisalarni yozish.

    **Kirish talab qilinmaydi.** Anonim ko'rish tahlilning yarmi: odam aynan
    ro'yxatdan o'tishdan oldin nima izlagani — mahsulot uchun eng qimmatli
    ma'lumot, va uni faqat kirgan odamlardan yig'ish bu savolni butunlay
    yopib qo'yadi.

    Paketli, chunki lentaning bir sahifasi 20 ta ko'rsatish beradi. Har biri
    uchun alohida so'rov ilovani ham, serverni ham keraksiz yuklaydi.
    """
    # Kirgan odam o'z hisobi bo'yicha, mehmon esa manzili bo'yicha
    # hisoblanadi. Hisob bo'yicha aniqroq: bitta uy yoki ofisdagi bir necha
    # odam bitta tashqi manzil ortida turishi mumkin.
    source = (
        f"u:{viewer.id}"
        if viewer is not None
        else f"ip:{request.client.host if request.client else 'unknown'}"
    )
    if not _limiter.allow(source, len(batch.events)):
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            "Juda ko'p hodisa yuborildi.",
            headers={"Retry-After": str(RATE_WINDOW_SECONDS)},
        )

    now = datetime.now(UTC)
    rows = []

    for item in batch.events:
        stamp = item.occurred_at or now
        if stamp.tzinfo is None:
            stamp = stamp.replace(tzinfo=UTC)

        # Mijozdagi soat xato bo'lishi mumkin. Kelajakdagi tamg'a serverning
        # vaqtiga tortiladi; juda eskisi ham — aks holda bitta noto'g'ri
        # sozlangan telefon kunlik hisobotni siljitib yuborardi.
        if abs(stamp - now) > MAX_SKEW:
            stamp = now

        rows.append(
            service.row(
                item.kind,
                user_id=viewer.id if viewer else None,
                session_id=batch.session_id,
                target_type=item.target_type,
                target_id=item.target_id,
                payload=item.payload,
                locale=locale,
                platform=batch.platform,
                dedupe_key=item.dedupe_key,
                occurred_at=stamp,
            )
        )

    try:
        written = await service.write(db, rows)
        await db.commit()
    except Exception as exc:
        await db.rollback()
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE, "Hodisalar yozilmadi."
        ) from exc

    return BatchResult(accepted=written, duplicates=len(rows) - written)
