"""Ishga yaroqlilik va xatolik javoblari.

Ikkita nuqson ustidan qorovul:

1. `/health` faqat jarayon ko'tarilganini emas, bazaga yeta olishini bildirsin.
   Ilgari baza konteyneri o'chganda ham `ok` qaytarardi — balanslovchi shu
   sababli birorta so'rovga javob bera olmaydigan nusxaga trafik yuboraverardi.

2. Qayta ishlanmagan istisno CORS sarlavhalarini yo'qotmasin. Starlette'ning o'z
   500'i CORS middleware'dan tashqarida tug'iladi, shuning uchun brauzer uni
   "CORS xatosi" deb ko'rsatadi va haqiqiy sabab yashirinadi.


Bazani o'chirib sinash suiteni buzadi, shuning uchun 500 yo'li ASGI ichida
ataylab yiqiladigan vaqtinchalik yo'l orqali tekshiriladi.
"""

import asyncio
import sys
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.main import app  # noqa: E402

BASE = "http://127.0.0.1:8010"
ORIGIN = "http://localhost:5599"


def check(label: str, ok: bool, extra: str = "") -> None:
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f"  — {extra}" if extra else ""))
    if not ok:
        raise SystemExit(1)


# --- 1. /health bazaga tegadi ------------------------------------------------

with httpx.Client(base_url=BASE, timeout=20) as c:
    r = c.get("/health")
    check("/health 200 qaytardi", r.status_code == 200, str(r.status_code))

    body = r.json()
    check("javobda status bor", body.get("status") == "ok", str(body))
    check(
        "javob bazaning holatini ham aytadi",
        body.get("database") == "up",
        "tekshiruv haqiqatan so'rov yuborgani shundan bilinadi",
    )


# --- 2. qayta ishlanmagan istisno --------------------------------------------


@app.get("/__boom__")
async def _boom() -> dict[str, str]:
    raise RuntimeError("ataylab")


async def crash() -> httpx.Response:
    transport = httpx.ASGITransport(app=app, raise_app_exceptions=False)
    async with httpx.AsyncClient(
        transport=transport, base_url="http://test", timeout=20
    ) as ac:
        return await ac.get("/__boom__", headers={"Origin": ORIGIN})


r = asyncio.run(crash())

check("yiqilish 500 beradi, uzilish emas", r.status_code == 500, str(r.status_code))

payload = r.json()
check("javob JSON va detail bor", "detail" in payload, str(payload))
check(
    "javob request_id tashiydi",
    isinstance(payload.get("request_id"), str) and len(payload["request_id"]) == 12,
    "logdagi traceback shu id orqali topiladi",
)
check(
    "xato matni ichki tafsilotni oshkor qilmaydi",
    "RuntimeError" not in r.text and "ataylab" not in r.text,
    r.text[:80],
)
check(
    "500 javobida ham CORS sarlavhasi bor",
    r.headers.get("access-control-allow-origin") == ORIGIN,
    "aks holda brauzer haqiqiy sababni yashiradi",
)
