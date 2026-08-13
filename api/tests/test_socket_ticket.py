"""B4: WebSocket socket-ticket — jonli kanal endi qisqa muddatli bir martalik
chiptani so'raydi, hisobning access tokenini query stringda tashimaydi.

`/ws-ticket` autentifikatsiya talab qiladi; qaytargan chipta access tokendan
farq qiladi; soket faqat `typ=socket` chiptani qabul qiladi — access token yoki
axlat rad etiladi."""

import asyncio

import httpx
import websockets

BASE = "http://127.0.0.1:8010"
WS = "ws://127.0.0.1:8010/ws"


def check(label: str, ok: bool, extra: str = "") -> None:
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f"  — {extra}" if extra else ""))
    if not ok:
        raise SystemExit(1)


def access_token(c: httpx.Client, phone: str) -> str:
    code = c.post("/auth/otp/request", json={"phone": phone}).json()["debug_code"]
    return c.post("/auth/otp/verify", json={"phone": phone, "code": code}).json()[
        "access_token"
    ]


async def dials(token: str) -> bool:
    """True if the socket opens with this token, False if it is refused."""
    try:
        async with websockets.connect(f"{WS}?token={token}"):
            return True
    except Exception:
        return False


with httpx.Client(base_url=BASE, timeout=20) as c:
    at = access_token(c, "+998901234122")

    # Chipta faqat kirgan foydalanuvchiga beriladi.
    check("chiptani autentifikatsiyasiz olib bo'lmaydi (401)",
          c.get("/ws-ticket").status_code == 401)

    r = c.get("/ws-ticket", headers={"Authorization": f"Bearer {at}"})
    check("kirgan foydalanuvchi chipta oladi (200)", r.status_code == 200)
    ticket = r.json().get("ticket")
    check("javobda chipta bor", isinstance(ticket, str) and len(ticket) > 20)
    check("chipta access tokendan farq qiladi", ticket != at)

check("soket chipta bilan ochiladi", asyncio.run(dials(ticket)))
check("soket access tokenni rad etadi", not asyncio.run(dials(at)))
check("soket axlat tokenni rad etadi", not asyncio.run(dials("not-a-token")))
