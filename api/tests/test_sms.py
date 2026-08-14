"""Eskiz SMS integratsiyasi.

Sinov haqiqiy Eskizga chiqmaydi — kalitlar ham, pul ham sarflanmaydi. Uning
o'rniga mijozning tashqi xizmat bilan qanday gaplashishi tekshiriladi, chunki
ilk kunda xato beradigan joylar aynan shular:

- Raqam plyussiz ketishi shart. Plyus bilan yuborilganda Eskiz xato emas,
  "muvaffaqiyat" qaytaradi va SMS hech qayerga bormaydi — bu eng yomon xato
  turi, chunki u ko'rinmaydi.
- Token 30 kun yashaydi. 401 kelganda bir marta qayta olinib, so'rov bir
  marta takrorlanishi kerak; halqa emas, aynan bitta urinish.
- Kalit sozlanmagan bo'lsa xizmat quruq rejimda ishlasin — ishlab chiqish
  provayderisiz to'liq yursin.
- SMS ketmasa ro'yxatdan o'tish jimgina davom etmasin (sms_required).
"""

import asyncio
import sys
from pathlib import Path
from urllib.parse import parse_qs

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.services import sms as sms_module  # noqa: E402
from app.services.sms import (  # noqa: E402
    EskizClient,
    LogSms,
    SmsError,
    otp_text,
    to_eskiz_number,
)

BASE = "http://127.0.0.1:8010"


def check(label: str, ok: bool, extra: str = "") -> None:
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f"  → {extra}" if extra else ""))
    if not ok:
        raise SystemExit(1)


# --- 1. Raqam shakli --------------------------------------------------------

check("plyus olib tashlanadi", to_eskiz_number("+998901234567") == "998901234567")
check("plyussiz raqam tegilmaydi", to_eskiz_number("998901234567") == "998901234567")
check("probel tozalanadi", to_eskiz_number("+998 90 123 45 67") == "998901234567")
check("chiziqcha tozalanadi", to_eskiz_number("+998-90-1234567") == "998901234567")


# --- 2. Matn shabloni -------------------------------------------------------

text = otp_text("482910")
check("matnda kod bor", "482910" in text, text)
check("matnda brend nomi bor", "BarterApp" in text, text)
check(
    "matn SMS uzunligiga sig'adi",
    len(text) <= 160,
    f"{len(text)} belgi — uzuni ikki SMS bo'lib, ikki barobar turadi",
)


# --- 3. Xizmat bilan gaplashish (soxta transport) ---------------------------


class FakeEskiz:
    """
    Eskizning o'zini o'ynaydi.

    `httpx.MockTransport` orqali — ya'ni tekshirilayotgan kod haqiqiy
    `httpx.AsyncClient` ishlatadi va so'rovni o'zi tuzadi. Mijozni
    yamoqlash o'rniga shu yo'l tanlandi: aks holda sinov mijoz nima
    yuborishini emas, o'zi nima yuborishini tekshirgan bo'lardi.
    """

    def __init__(self, *, expire_first_token: bool = False) -> None:
        self.logins = 0
        self.sends: list[dict] = []
        self.expire_first_token = expire_first_token
        self._sent_once = False

    def handler(self, request: httpx.Request) -> httpx.Response:
        # Form-body URL-kodlangan holda keladi ("sinov matni" → "sinov+matni").
        # Qo'lda bo'lish yetarli emas — aks holda sinov mijoz yubormagan
        # o'zgarishni ko'rib, yo'q xatoni "topib" beradi.
        body = {k: v[0] for k, v in parse_qs(request.content.decode()).items()}

        if request.url.path.endswith("/auth/login"):
            self.logins += 1
            return httpx.Response(
                200, json={"data": {"token": f"token-{self.logins}"}}
            )

        if request.url.path.endswith("/message/sms/send"):
            self.sends.append(
                {
                    "auth": request.headers.get("Authorization"),
                    "phone": body.get("mobile_phone"),
                    "message": body.get("message"),
                    "from": body.get("from"),
                }
            )
            if self.expire_first_token and not self._sent_once:
                self._sent_once = True
                return httpx.Response(401, json={"message": "expired"})
            return httpx.Response(200, json={"status": "waiting"})

        return httpx.Response(404)


#: Asl sinf bir marta, modul yuklanganda saqlanadi.
#:
#: Har chaqiruvda `httpx.AsyncClient` dan meros olish xato edi: ikkinchi
#: almashtirish allaqachon yamalgan sinfdan meros olib, `super().__init__`
#: transportni birinchi soxta serverning ustiga qaytarib qo'yardi. Natijada
#: ikkinchi soxta server hech qachon so'rov ko'rmasdi.
REAL_CLIENT = httpx.AsyncClient


def with_fake(fake: FakeEskiz):
    """`httpx.AsyncClient` ni soxta transport bilan almashtiradi."""

    class Patched(REAL_CLIENT):
        def __init__(self, *args, **kwargs):
            kwargs["transport"] = httpx.MockTransport(fake.handler)
            super().__init__(*args, **kwargs)

    return REAL_CLIENT, Patched


async def transport_checks() -> None:
    # --- oddiy yuborish -----------------------------------------------------

    fake = FakeEskiz()
    real, patched = with_fake(fake)
    httpx.AsyncClient = patched
    try:
        client = EskizClient()
        await client.send("+998901234567", "sinov matni")

        check("bir marta login qilindi", fake.logins == 1, str(fake.logins))
        check("bitta SMS yuborildi", len(fake.sends) == 1)

        sent = fake.sends[0]
        check(
            "raqam plyussiz ketdi",
            sent["phone"] == "998901234567",
            f"{sent['phone']} — plyus bilan Eskiz jimgina yutib yuboradi",
        )
        check("matn o'zgarmagan", sent["message"] == "sinov matni")
        check("jo'natuvchi qo'yildi", bool(sent["from"]), str(sent["from"]))
        check("token sarlavhada", sent["auth"] == "Bearer token-1", str(sent["auth"]))

        # Ikkinchi SMS qayta login qilmasligi kerak.
        await client.send("+998901234568", "ikkinchi")
        check(
            "ikkinchi SMS qayta login qilmaydi",
            fake.logins == 1,
            "har SMS uchun login Eskiz tomonidan cheklanadi",
        )

        # --- token eskirgani ------------------------------------------------

        expiring = FakeEskiz(expire_first_token=True)
        _, patched2 = with_fake(expiring)
        httpx.AsyncClient = patched2

        client2 = EskizClient()
        await client2.send("+998901234569", "eskirgan token")

        check(
            "401 dan keyin token qayta olindi",
            expiring.logins == 2,
            f"{expiring.logins} — 30 kundan keyin oqim jim to'xtamasin",
        )
        check("so'rov takrorlandi", len(expiring.sends) == 2)
        check(
            "takrorda yangi token ishlatildi",
            expiring.sends[1]["auth"] == "Bearer token-2",
            str(expiring.sends[1]["auth"]),
        )

        # --- xizmat rad etgani -----------------------------------------------

        class Refusing(FakeEskiz):
            def handler(self, request: httpx.Request) -> httpx.Response:
                if request.url.path.endswith("/auth/login"):
                    return httpx.Response(200, json={"data": {"token": "t"}})
                return httpx.Response(500, json={"message": "server error"})

        refusing = Refusing()
        _, patched3 = with_fake(refusing)
        httpx.AsyncClient = patched3

        failed = False
        try:
            await EskizClient().send("+998901234570", "yiqiladi")
        except SmsError:
            failed = True
        check("xizmat rad etsa SmsError chiqadi", failed)

    finally:
        httpx.AsyncClient = real


asyncio.run(transport_checks())


# --- 4. Quruq rejim ---------------------------------------------------------

check(
    "kalitsiz holatda quruq rejim tanlanadi",
    isinstance(sms_module.get_sms(), LogSms),
    "ishlab chiqish provayderisiz to'liq yuradi",
)

asyncio.run(LogSms().send("+998901234567", "quruq"))
check("quruq rejim yiqilmaydi", True)


# --- 5. Ro'yxatdan o'tish oqimi hali ishlaydi -------------------------------

with httpx.Client(base_url=BASE, timeout=30) as c:
    r = c.post("/auth/otp/request", json={"phone": "+998901234123"})
    check("OTP so'rovi ishlaydi", r.status_code == 200, str(r.status_code))

    body = r.json()
    check("javobda sent bor", body["sent"] is True, str(body))
    check(
        "ishlab chiqishda kod javobda qaytadi",
        body["debug_code"] is not None,
        "provayder yo'q paytda ilova shu bilan yuradi",
    )

    r = c.post(
        "/auth/otp/verify",
        json={"phone": "+998901234123", "code": body["debug_code"]},
    )
    check("kod bilan kirish ishlaydi", r.status_code == 200, str(r.status_code))
