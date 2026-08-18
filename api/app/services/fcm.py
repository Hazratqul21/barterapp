"""FCM HTTP v1 transporti.

Kalit `.env` da emas, bazada: uni mahsulot egasi admin paneldan qo'yadi.
Sabab oddiy — kalit uning qo'lida bo'ladi, serverga esa u kira olmaydi.
`.env` yo'li "kalit bor-u, uni qo'yadigan odam yo'q" holatini yaratadi.

`google-auth` kutubxonasisiz: oqim uch qadamdan iborat va uchalasi ham
`httpx` bilan bajariladi. Qo'shimcha bog'liqlik olib kelish o'rniga —
ayniqsa u o'z navbatida yana beshtasini tortadi — shu uch qadam shu
yerda yozilgan.
"""

from __future__ import annotations

import json
import logging
import time
from dataclasses import dataclass

import httpx
import jwt

from app.services.push import PushMessage, Transport

log = logging.getLogger("barter.fcm")

TOKEN_URL = "https://oauth2.googleapis.com/token"
SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
TIMEOUT = 20.0

#: Google tokeni bir soat yashaydi. Bir daqiqa zaxira qoldiriladi, chunki
#: so'rov yo'lda ketayotganda muddati tugab qolishi mumkin.
TOKEN_LIFETIME = 3600
TOKEN_MARGIN = 60


class FcmError(RuntimeError):
    """Yuborib bo'lmadi. Navbat qatorni belgilamaydi va keyin qayta uriniladi."""


@dataclass
class ServiceAccount:
    project_id: str
    client_email: str
    private_key: str

    @classmethod
    def parse(cls, raw: str) -> ServiceAccount:
        """
        Firebase konsolidan yuklab olingan JSON.

        Xatolar aniq aytiladi: panelga noto'g'ri fayl qo'yilishi eng
        ehtimolli xato, va "kalit ishlamadi" degan xabar odamga hech
        narsa bermaydi.
        """
        try:
            data = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise FcmError("Fayl JSON emas.") from exc

        if data.get("type") != "service_account":
            raise FcmError(
                "Bu service account fayli emas. Firebase konsolida: "
                "Project settings → Service accounts → Generate new private key."
            )

        missing = [
            field
            for field in ("project_id", "client_email", "private_key")
            if not data.get(field)
        ]
        if missing:
            raise FcmError(f"Faylda yetishmayapti: {', '.join(missing)}")

        return cls(
            project_id=data["project_id"],
            client_email=data["client_email"],
            private_key=data["private_key"],
        )


class FcmTransport(Transport):
    """
    Xabarni Google'ga uzatadi.

    Token nusxada saqlanadi va muddati tugaguncha qayta ishlatiladi. Har
    xabar uchun token olish — har xabar uchun ikkita tashqi so'rov degani,
    va Google buni cheklaydi.
    """

    def __init__(self, account: ServiceAccount) -> None:
        self._account = account
        self._token: str | None = None
        self._expires: float = 0.0

    async def _access_token(self, client: httpx.AsyncClient) -> str:
        now = time.time()
        if self._token and now < self._expires - TOKEN_MARGIN:
            return self._token

        assertion = jwt.encode(
            {
                "iss": self._account.client_email,
                "scope": SCOPE,
                "aud": TOKEN_URL,
                "iat": int(now),
                "exp": int(now) + TOKEN_LIFETIME,
            },
            self._account.private_key,
            algorithm="RS256",
        )

        response = await client.post(
            TOKEN_URL,
            data={
                "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
                "assertion": assertion,
            },
        )
        if response.status_code != 200:
            # Javob tanasi chop etilmaydi — unda kalit haqidagi tafsilot
            # bo'lishi mumkin.
            raise FcmError(f"Google tokenni bermadi ({response.status_code}).")

        payload = response.json()
        self._token = payload.get("access_token")
        if not self._token:
            raise FcmError("Google javobida access_token yo'q.")
        self._expires = now + int(payload.get("expires_in", TOKEN_LIFETIME))
        return self._token

    async def send(self, message: PushMessage) -> bool:
        url = (
            "https://fcm.googleapis.com/v1/projects/"
            f"{self._account.project_id}/messages:send"
        )

        body = {
            "message": {
                "token": message.token,
                "notification": {
                    "title": message.title,
                    "body": message.body,
                },
                # Mijoz qaysi ekranni ochishni shu ikkitasidan biladi.
                # FCM `data` faqat satr qabul qiladi.
                "data": {
                    "target_type": message.target_type,
                    "target_id": message.target_id or "",
                    "notification_id": message.notification_id,
                },
            }
        }

        async with httpx.AsyncClient(timeout=TIMEOUT) as client:
            token = await self._access_token(client)
            response = await client.post(
                url,
                json=body,
                headers={"Authorization": f"Bearer {token}"},
            )

        if response.status_code == 200:
            return True

        # 404 va 403 — token endi yaroqsiz (ilova o'chirilgan, ruxsat
        # olingan). Qayta urinish foyda bermaydi, shuning uchun bu
        # "yetkazildi" deb belgilanadi va navbat tiqilib qolmaydi.
        if response.status_code in (403, 404):
            log.info(
                "push: qurilma tokeni yaroqsiz (%s), o'tkazib yuborildi",
                response.status_code,
            )
            return True

        raise FcmError(f"FCM rad etdi ({response.status_code}).")
