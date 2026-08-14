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

Kalitlar `.env` dan o'qiladi va hech qayerda chop etilmaydi. Kalitsiz holatda
xizmat quruq rejimda ishlaydi: matnni logga yozadi va muvaffaqiyat qaytaradi,
shuning uchun ishlab chiqish SMS provayderisiz ham to'liq yuradi.
"""

from __future__ import annotations

import logging

import httpx

from app.core.config import settings

log = logging.getLogger("barter.sms")

BASE_URL = "https://notify.eskiz.uz/api"
TIMEOUT = 15.0


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


class EskizClient:
    """
    Tokenni o'zida saqlaydigan mijoz.

    Bir nusxa butun jarayon uchun ishlatiladi (`get_sms()`), aks holda har
    SMS uchun qaytadan login qilinardi — bu Eskiz tomonidan cheklanadi.
    """

    def __init__(self) -> None:
        self._token: str | None = None

    async def _login(self, client: httpx.AsyncClient) -> str:
        response = await client.post(
            "/auth/login",
            data={
                "email": settings.eskiz_email,
                "password": settings.eskiz_password,
            },
        )
        if response.status_code != 200:
            # Javob tanasi chop etilmaydi: unda xizmat qaytargan tafsilot
            # bo'lishi mumkin va u logga tushmasligi kerak.
            raise SmsError(f"Eskiz login rad etdi ({response.status_code}).")

        token = response.json().get("data", {}).get("token")
        if not token:
            raise SmsError("Eskiz login javobida token yo'q.")
        return token

    async def send(self, phone: str, text: str) -> None:
        async with httpx.AsyncClient(base_url=BASE_URL, timeout=TIMEOUT) as client:
            if self._token is None:
                self._token = await self._login(client)

            payload = {
                "mobile_phone": to_eskiz_number(phone),
                "message": text,
                "from": settings.eskiz_sender,
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
        log.info("sms (quruq rejim) → %s: %s", phone, text)


_client: EskizClient | LogSms | None = None


def get_sms() -> EskizClient | LogSms:
    """Bitta nusxa: token jarayon davomida saqlanadi."""
    global _client
    if _client is None:
        _client = (
            EskizClient()
            if settings.eskiz_email and settings.eskiz_password
            else LogSms()
        )
    return _client


def otp_text(code: str) -> str:
    """
    Tasdiqlangan shablonga tushadigan matn.

    Shakl sozlamada, chunki Eskiz har bir matnni oldindan tasdiqlaydi va
    tasdiqlanmagan matn jimgina yetkazilmaydi. Tasdiq boshqa so'z bilan
    kelsa, kodni emas, `.env` ni o'zgartirish kerak bo'ladi.
    """
    return settings.eskiz_otp_template.format(code=code)
