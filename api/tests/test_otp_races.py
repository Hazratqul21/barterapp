"""OTP: parallel so'rovlar chegaralarni aylanib o'tolmaydi.

Ilgari 60 ta bir vaqtdagi noto'g'ri kod 5 urinishli kodga 37 marta
tekshirilardi, 40 ta bir vaqtdagi kod so'rovi esa 5 ta o'rniga 8 ta SMS
yuborardi. Endi bitta telefon bo'yicha so'rovlar navbat bilan o'tadi.

- bitta kodga ko'pi bilan 5 ta noto'g'ri urinish tekshiriladi;
- bitta telefonga 15 daqiqada ko'pi bilan 5 ta kod;
- bir kunda 15 ta noto'g'ri urinishdan keyin to'g'ri kod ham qabul qilinmaydi.
"""

import asyncio
import random
import sys
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

BASE = "http://127.0.0.1:8010"


def check(label: str, ok: bool, extra: str = "") -> None:
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f"  → {extra}" if extra else ""))
    if not ok:
        raise SystemExit(1)


def phone() -> str:
    return "+99894" + "".join(random.choice("0123456789") for _ in range(7))


async def main() -> None:
    async with httpx.AsyncClient(base_url=BASE, timeout=30) as c:
        p = phone()
        code = (await c.post("/auth/otp/request", json={"phone": p})).json()["debug_code"]
        wrong = "000000" if code != "000000" else "111111"
        results = await asyncio.gather(*[
            c.post("/auth/otp/verify", json={"phone": p, "code": wrong}) for _ in range(40)
        ])
        checked = sum(r.status_code == 400 for r in results)
        check("parallel urinishlar: ko'pi bilan 5 tasi tekshiriladi", checked <= 5, f"{checked} ta 400")
        ok = await c.post("/auth/otp/verify", json={"phone": p, "code": code})
        check("5 urinishdan keyin to'g'ri kod ham rad etiladi", ok.status_code == 429, str(ok.status_code))

        p2 = phone()
        sent = await asyncio.gather(*[
            c.post("/auth/otp/request", json={"phone": p2}) for _ in range(30)
        ])
        n = sum(r.status_code == 200 for r in sent)
        check("parallel kod so'rovlari: ko'pi bilan 5 ta SMS", n <= 5, f"{n} ta")

        # Kunlik chegara: 3 ta kod × 5 noto'g'ri = 15, keyin to'g'risi ham yo'q.
        p3 = phone()
        for _ in range(3):
            code = (await c.post("/auth/otp/request", json={"phone": p3})).json()["debug_code"]
            bad = "000000" if code != "000000" else "111111"
            for _ in range(5):
                await c.post("/auth/otp/verify", json={"phone": p3, "code": bad})
        code = (await c.post("/auth/otp/request", json={"phone": p3})).json()["debug_code"]
        r = await c.post("/auth/otp/verify", json={"phone": p3, "code": code})
        check("kuniga 15 noto'g'ri urinishdan keyin bloklanadi", r.status_code == 429, str(r.status_code))

    print("\nHammasi o'tdi.")


if __name__ == "__main__":
    asyncio.run(main())
