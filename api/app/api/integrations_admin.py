"""SMS (Eskiz) va Google orqali kirishni admin paneldan sozlash.

Firebase bilan bir xil qoida: kalit egasi serverga kira olmaydi, shuning
uchun kalit `.env` da emas, panelda qo'yiladi va serverni qayta ishga
tushirmasdan keyingi so'rovdan boshlab ishlaydi.

- Noto'g'ri kalit **saqlashdan oldin** rad etiladi: Eskiz'ga login qilib
  ko'riladi. Aks holda kalit qo'yilgandek ko'rinadi va nima uchun hech kimga
  kod bormayotgani keyin izlanadi.
- Eskiz paroli **hech qachon qaytarilmaydi** — faqat holati va izi.
"""

from __future__ import annotations

import json
import logging
import secrets

import httpx
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import current_moderator
from app.db.session import get_db
from app.models.user import User
from app.schemas.common import ApiModel
from app.services import google_clients, settings_store, sms

router = APIRouter(prefix="/admin", tags=["admin"])

log = logging.getLogger("barter.admin")


# ─────────────────────────────────────────────────────────────────────────────
# SMS — Eskiz
# ─────────────────────────────────────────────────────────────────────────────


class SmsStatus(ApiModel):
    #: Haqiqiy SMS ketadimi (panel yoki `.env` da hisob bor).
    ready: bool
    #: "panel", "env" yoki None.
    source: str | None
    #: `ab***@mail.uz` — qaysi hisob turganini ajratish uchun.
    email_hint: str | None = None
    sender: str | None = None
    otp_template: str | None = None
    #: Hisob izi. Parolning o'zi hech qachon qaytarilmaydi.
    fingerprint: str | None = None
    #: Ilovada telefon orqali kirish hozir ochiqmi.
    phone_login_open: bool
    #: `.env` dagi vaqtinchalik rejim — panel kaliti bilan ham ishlayveradi.
    sms_optional: bool


def _mask(email: str) -> str:
    name, _, domain = email.partition("@")
    return f"{name[:2]}***@{domain}" if domain else f"{email[:2]}***"


async def _sms_status(db: AsyncSession) -> SmsStatus:
    panel = await sms.panel_credentials(db)
    creds = panel or sms.env_credentials()
    return SmsStatus(
        ready=creds is not None,
        source=("panel" if panel else "env") if creds else None,
        email_hint=_mask(creds.email) if creds else None,
        sender=creds.sender if creds else None,
        otp_template=creds.otp_template if creds else settings.eskiz_otp_template,
        fingerprint=settings_store.fingerprint(creds.to_json()) if creds else None,
        phone_login_open=settings.phone_login_open(panel is not None),
        sms_optional=settings.sms_optional,
    )


class SmsIn(ApiModel):
    email: str = Field(min_length=3, max_length=200)
    password: str = Field(min_length=1, max_length=200)
    #: Eskiz'da tasdiqlangan jo'natuvchi nomi. "4546" — Eskizning sinov nomi.
    sender: str = Field(default="4546", min_length=1, max_length=20)
    #: Eskiz'da tasdiqlangan matn, `{code}` bilan.
    otp_template: str = Field(default_factory=lambda: settings.eskiz_otp_template, max_length=300)


@router.get("/sms", response_model=SmsStatus)
async def sms_status(
    _: User = Depends(current_moderator), db: AsyncSession = Depends(get_db)
) -> SmsStatus:
    return await _sms_status(db)


@router.put("/sms", response_model=SmsStatus)
async def set_sms(
    payload: SmsIn,
    _: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> SmsStatus:
    """
    Eskiz hisobini qo'yish.

    Saqlashdan **oldin** Eskiz'ga login qilinadi: noto'g'ri email yoki parol
    shu yerda aytiladi, birinchi foydalanuvchi kod kutib qolganda emas.
    """
    template = payload.otp_template.strip()
    problem = sms.template_problem(template)
    if problem:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, problem)

    creds = sms.EskizCredentials(
        email=payload.email.strip(),
        password=payload.password,
        sender=payload.sender.strip(),
        otp_template=template,
    )
    client = sms.EskizClient(creds)
    try:
        await client.check_login()
    except sms.SmsError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc)) from exc
    except httpx.HTTPError as exc:
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY,
            "Eskiz bilan aloqa bo'lmadi — kalit saqlanmadi. Birozdan so'ng qayta urining.",
        ) from exc

    await settings_store.put(db, settings_store.ESKIZ, creds.to_json())
    await db.commit()
    # Olingan token keyingi SMS'da ishlatiladi — ortiqcha login yo'q.
    sms.remember(client)
    log.info("Eskiz hisobi panelda almashtirildi (%s)", _mask(creds.email))
    return await _sms_status(db)


@router.delete("/sms", response_model=SmsStatus)
async def clear_sms(
    _: User = Depends(current_moderator), db: AsyncSession = Depends(get_db)
) -> SmsStatus:
    """Panel kalitini olib tashlash — `.env` dagiga yoki quruq rejimga qaytadi."""
    await settings_store.drop(db, settings_store.ESKIZ)
    await db.commit()
    return await _sms_status(db)


class SmsTestIn(ApiModel):
    phone: str = Field(pattern=r"^\+998\d{9}$")


@router.post("/sms/test")
async def test_sms(
    payload: SmsTestIn,
    _: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """
    Haqiqiy SMS yuborib ko'rish — OTP shabloni bilan, tasodifiy kod.

    Eskiz faqat tasdiqlangan matnni yetkazadi; shu tugma shablon
    tasdiqlanganini ham tekshiradi.
    """
    if not await sms.eskiz_ready(db):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Eskiz hisobi qo'yilmagan.")
    code = f"{secrets.randbelow(1_000_000):06d}"
    try:
        client = await sms.sms_for(db)
        await client.send(payload.phone, await sms.otp_text_for(db, code))
    except sms.SmsError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc)) from exc
    except httpx.HTTPError as exc:
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY, "Eskiz bilan aloqa bo'lmadi."
        ) from exc
    return {"ok": True}


# ─────────────────────────────────────────────────────────────────────────────
# Google orqali kirish
# ─────────────────────────────────────────────────────────────────────────────


class GoogleStatus(ApiModel):
    #: Tugma ilovada va saytda ko'rinadimi (web ID bor).
    enabled: bool
    source: str | None
    #: Mijozlarga beriladigan ID — ilovada `serverClientId`.
    web_client_id: str | None
    #: Qabul qilinadigan Android ID'lar (`.env` dagilari bilan birga).
    android_client_ids: list[str]
    #: Panelda saqlangan qiymat — formani to'ldirish uchun.
    panel_web_client_id: str | None = None
    panel_android_client_ids: list[str] = []


async def _google_status(db: AsyncSession) -> GoogleStatus:
    clients = await google_clients.resolve(db)
    stored = await google_clients.panel_value(db)
    return GoogleStatus(
        enabled=clients.enabled,
        source=clients.source,
        web_client_id=clients.client_id,
        android_client_ids=list(clients.android),
        panel_web_client_id=stored.get("web_client_id") or None,
        panel_android_client_ids=list(stored.get("android_client_ids") or []),
    )


class GoogleIn(ApiModel):
    #: Google Cloud → Credentials → turi **Web application**.
    web_client_id: str | None = Field(default=None, max_length=200)
    #: Turi **Android** (upload va Play App Signing SHA-1 uchun alohida).
    android_client_ids: list[str] = Field(default_factory=list, max_length=10)


@router.get("/google", response_model=GoogleStatus)
async def google_status(
    _: User = Depends(current_moderator), db: AsyncSession = Depends(get_db)
) -> GoogleStatus:
    return await _google_status(db)


@router.put("/google", response_model=GoogleStatus)
async def set_google(
    payload: GoogleIn,
    _: User = Depends(current_moderator),
    db: AsyncSession = Depends(get_db),
) -> GoogleStatus:
    web = (payload.web_client_id or "").strip() or None
    android = list(dict.fromkeys(i.strip() for i in payload.android_client_ids if i.strip()))
    for value in ([web] if web else []) + android:
        if not google_clients.CLIENT_ID.match(value):
            raise HTTPException(
                status.HTTP_422_UNPROCESSABLE_ENTITY,
                f"Bu Google client ID emas: {value}. Shakli: 1234…-abc….apps.googleusercontent.com",
            )
    if web and web in android:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            "Bitta ID ham web, ham Android bo'la olmaydi. Web ID — Google Cloud'da "
            "turi «Web application» bo'lgan client.",
        )

    await settings_store.put(
        db,
        settings_store.GOOGLE_CLIENT,
        json.dumps({"web_client_id": web, "android_client_ids": android}),
    )
    await db.commit()
    return await _google_status(db)
