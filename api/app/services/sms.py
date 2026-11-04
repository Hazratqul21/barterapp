"""SMS yuborish — Eskiz (notify.eskiz.uz).

Eskizning ikkita o'ziga xosligi bor va ikkalasi ham ilk kunda kutilmaganda
chiqadi:

1. **Token 30 kun yashaydi va o'zi yangilanmaydi.** Bir marta olib qo'yish
   yetarli emas — bir oydan keyin butun ro'yxatdan o'tish oqimi jimgina
   ishlamay qoladi. Shuning uchun 401 kelganda token bir marta qayta olinadi
   va so'rov takrorlanadi.

2. **Matn oldindan tasdiqlangan shablon bo'lishi shart.** Ixtiyoriy matn
   moderatsiyaga tushadi va yetkazilmaydi. Shuning uchun matn shakli
   sozlamada turadi — tasdiqlangan variantni kod o'zgartirmasdan qo'yish
   uchun.

Kalitlar admin paneldan (bazada) yoki `.env` dan o'qiladi — panel ustun.
Panelda qo'yilgani serverni qayta ishga tushirmasdan keyingi SMS'dan
boshlab ishlaydi. Kalit hech qayerda chop etilmaydi. Kalitsiz holatda
xizmat quruq rejimda ishlaydi: matnni logga yozadi va muvaffaqiyat qaytaradi,
shuning uchun ishlab chiqish SMS provayderisiz ham to'liq yuradi.
"""

from __future__ import annotations

import json
import logging
from dataclasses import asdict, dataclass

import httpx
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.services import settings_store

log = logging.getLogger("barter.sms")

BASE_URL = "https://notify.eskiz.uz/api"
#: OTP so'rovi shu vaqtgacha kutadi. Eskiz osilib qolsa ham kirish sahifasi
#: qotib qolmasin — xato tez va ochiq qaytadi.
TIMEOUT = 10.0

#: Faqat sinovlar uchun: soxta Eskiz serveri (`httpx.MockTransport`).
TRANSPORT: httpx.AsyncBaseTransport | None = None


class SmsError(RuntimeError):
    """Yetkazib bo'lmadi. Chaqiruvchi buni foydalanuvchiga aytadi."""


def to_eskiz_number(phone: str) -> str:
    """
    `+998901234567` → `998901234567`.

    Eskiz raqamni plyussiz kutadi. Plyus bilan yuborilganda xato emas,
    "muvaffaqiyat" qaytadi va SMS hech qayerga bormaydi — shuning uchun bu
    kichik almashtirish alohida funksiya va alohida sinovga ega.
    """
    return phone.lstrip("+").replace(" ", "").replace("-", "")


@dataclass(frozen=True)
class EskizCredentials:
    email: str
    password: str
    sender: str
    otp_template: str

    def to_json(self) -> str:
        return json.dumps(asdict(self))

    @classmethod
    def from_json(cls, raw: str) -> "EskizCredentials":
        return cls(**json.loads(raw))


def env_credentials() -> EskizCredentials | None:
    if not (settings.eskiz_email and settings.eskiz_password):
        return None
    return EskizCredentials(
        email=settings.eskiz_email,
        password=settings.eskiz_password,
        sender=settings.eskiz_sender,
        otp_template=settings.eskiz_otp_template,
    )


async def panel_credentials(db: AsyncSession) -> EskizCredentials | None:
    raw = await settings_store.get(db, settings_store.ESKIZ)
    if not raw:
        return None
    try:
        return EskizCredentials.from_json(raw)
    except (ValueError, TypeError):
        # Buzuq yozuv kirishni to'xtatmasin: `.env` ga qaytamiz.
        log.error("Bazadagi Eskiz sozlamasi o'qilmadi — e'tiborsiz qoldirildi.")
        return None


async def credentials(db: AsyncSession) -> EskizCredentials | None:
    """Panel ustun, keyin `.env`. Ikkalasi ham bo'sh bo'lsa — None."""
    return await panel_credentials(db) or env_credentials()


async def eskiz_ready(db: AsyncSession) -> bool:
    return await credentials(db) is not None


def _http(**kwargs) -> httpx.AsyncClient:
    if TRANSPORT is not None:
        kwargs["transport"] = TRANSPORT
    return httpx.AsyncClient(base_url=BASE_URL, timeout=TIMEOUT, **kwargs)


class EskizClient:
    """
    Tokenni o'zida saqlaydigan mijoz.

    Bir hisob uchun bitta nusxa ishlatiladi (`sms_for()`), aks holda har
    SMS uchun qaytadan login qilinardi — bu Eskiz tomonidan cheklanadi.
    """

    def __init__(self, creds: EskizCredentials | None = None) -> None:
        self._creds = creds
        self._token: str | None = None

    @property
    def _email(self) -> str:
        return self._creds.email if self._creds else settings.eskiz_email

    @property
    def _password(self) -> str:
        return self._creds.password if self._creds else settings.eskiz_password

    @property
    def _sender(self) -> str:
        return self._creds.sender if self._creds else settings.eskiz_sender

    async def _login(self, client: httpx.AsyncClient) -> str:
        response = await client.post(
            "/auth/login",
            data={"email": self._email, "password": self._password},
        )
        if response.status_code in (400, 401, 403, 422):
            raise SmsError("Eskiz email yoki parolni qabul qilmadi.")
        if response.status_code != 200:
            # Javob tanasi chop etilmaydi: unda xizmat qaytargan tafsilot
            # bo'lishi mumkin va u logga tushmasligi kerak.
            raise SmsError(f"Eskiz login rad etdi ({response.status_code}).")

        token = response.json().get("data", {}).get("token")
        if not token:
            raise SmsError("Eskiz login javobida token yo'q.")
        return token

    async def check_login(self) -> None:
        """Hisob haqiqiymi — saqlashdan oldin. SMS yubormaydi."""
        async with _http() as client:
            self._token = await self._login(client)

    async def send(self, phone: str, text: str) -> None:
        async with _http() as client:
            if self._token is None:
                self._token = await self._login(client)

            payload = {
                "mobile_phone": to_eskiz_number(phone),
                "message": text,
                "from": self._sender,
            }
            headers = {"Authorization": f"Bearer {self._token}"}
            response = await client.post(
                "/message/sms/send", data=payload, headers=headers
            )

            # Token 30 kunda eskiradi. Bir marta qayta olib, bir marta
            # takrorlaymiz — takrorlash halqasi emas, aynan bitta urinish,
            # aks holda haqiqiy rad javobi cheksiz aylanishga aylanardi.
            if response.status_code == 401:
                self._token = await self._login(client)
                headers = {"Authorization": f"Bearer {self._token}"}
                response = await client.post(
                    "/message/sms/send", data=payload, headers=headers
                )

            if response.status_code not in (200, 201):
                raise SmsError(f"Eskiz xabarni qabul qilmadi ({response.status_code}).")


class LogSms:
    """
    Provayder sozlanmagandagi holat.

    Ishlab chiqishda SMS hech qayerga ketmaydi — kod javobda `debug_code`
    bo'lib qaytadi. Bu sinf shunchaki nima yuborilishi kerakligini yozib
    qo'yadi, shuning uchun matn shablonini provayderisiz ham ko'rish mumkin.
    """

    async def send(self, phone: str, text: str) -> None:
        # warning, not info: uvicorn shows warnings by default, and in
        # production without a provider (SMS_OPTIONAL) this log line is the
        # only place the team can read a sign-in code.
        # Productionda provayder yo'q bo'lsa, kod faqat SMS_OPTIONAL_PHONES
        # (jamoa) raqamlari uchun logga yoziladi — `journalctl -u mab-api`.
        # Boshqa hech kimning kodi logga tushmaydi.
        if settings.is_production and not (
            settings.sms_optional and phone in settings.sms_optional_phones
        ):
            raise SmsError("SMS provayderi sozlanmagan.")
        log.warning("sms (quruq rejim) → %s: %s", phone, text)


_client: EskizClient | LogSms | None = None

#: Hisob izi bo'yicha: panelda kalit almashsa yangi mijoz (yangi token)
#: olinadi, almashmasa token saqlanib qoladi.
_panel_clients: dict[str, EskizClient] = {}


async def sms_for(db: AsyncSession) -> EskizClient | LogSms:
    """OTP yuboradigan transport: panel, keyin `.env`, keyin quruq rejim."""
    creds = await panel_credentials(db)
    if creds is None:
        return get_sms()
    key = settings_store.fingerprint(creds.to_json())
    client = _panel_clients.get(key)
    if client is None:
        _panel_clients.clear()
        client = _panel_clients[key] = EskizClient(creds)
    return client


def remember(client: EskizClient) -> None:
    """Panelda tekshirilgan mijozni (tokeni bilan) keyingi SMS'lar uchun saqlash."""
    if client._creds is None:
        return
    _panel_clients.clear()
    _panel_clients[settings_store.fingerprint(client._creds.to_json())] = client


def get_sms() -> EskizClient | LogSms:
    """`.env` dagi hisob uchun bitta nusxa: token jarayon davomida saqlanadi."""
    global _client
    if _client is None:
        _client = (
            EskizClient()
            if settings.eskiz_email and settings.eskiz_password
            else LogSms()
        )
    return _client


def otp_text(code: str, template: str | None = None) -> str:
    """
    Tasdiqlangan shablonga tushadigan matn.

    Shakl sozlamada, chunki Eskiz har bir matnni oldindan tasdiqlaydi va
    tasdiqlanmagan matn jimgina yetkazilmaydi. Tasdiq boshqa so'z bilan
    kelsa, kodni emas, `.env` ni o'zgartirish kerak bo'ladi.
    """
    return (template or settings.eskiz_otp_template).format(code=code)


async def otp_text_for(db: AsyncSession, code: str) -> str:
    creds = await credentials(db)
    return otp_text(code, creds.otp_template if creds else None)


def template_problem(template: str) -> str | None:
    """Shablon ishlatib bo'ladimi. Xato bo'lsa — sababi, aks holda None."""
    if "{code}" not in template:
        return "Shablonda {code} bo'lishi shart — kod shu joyga qo'yiladi."
    try:
        sample = template.format(code="000000")
    except (KeyError, IndexError, ValueError):
        return "Shablonda {code} dan boshqa {…} bo'lmasin."
    if len(sample) > 160:
        return f"Matn {len(sample)} belgi — 160 dan oshsa ikki SMS bo'lib, ikki barobar turadi."
    return None
