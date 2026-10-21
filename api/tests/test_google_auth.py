"""Google orqali kirish (`POST /auth/google`).

Haqiqiy Google o'rniga test o'z RSA kalitini yasaydi va uni JWKS sifatida
127.0.0.1:8799 da beradi. Server shu manzilni `GOOGLE_JWKS_URL` dan oladi —
productionda bu sozlama o'zgartirilsa, server ishga tushmaydi
(`test_config_guard.py`).

- to'g'ri token → hisob ochiladi (`is_new_user`), ism va email Google'dan;
- shu `sub` bilan qayta kirish → o'sha hisob;
- boshqa `aud`, boshqa kalit, muddati o'tgan, boshqa `iss` → 401;
- telefon bilan ochilgan hisob bir xil email bilan egallab olinmaydi;
- hisob o'chirilsa, Google bilan qayta kirish yangi hisob ochadi.

Talab: server GOOGLE_CLIENT_IDS='["ci-google-client"]' va
GOOGLE_JWKS_URL=http://127.0.0.1:8799/certs bilan ishga tushgan bo'lsin.
"""

import asyncio
import json
import sys
import threading
import time
import uuid
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

import httpx
import jwt
from cryptography.hazmat.primitives.asymmetric import rsa
from jwt.algorithms import RSAAlgorithm

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import update  # noqa: E402

from app.db.session import SessionLocal  # noqa: E402
from app.models.user import User  # noqa: E402

BASE = "http://127.0.0.1:8010"
CLIENT_ID = "ci-google-client"
ISS = "https://accounts.google.com"

# Har ishga tushishda yangi kid: server keshidagi eski kalit bilan
# adashmaslik uchun (noma'lum kid kelsa, server JWKS'ni qayta oladi).
KID = uuid.uuid4().hex[:12]
KEY = rsa.generate_private_key(public_exponent=65537, key_size=2048)
OTHER_KEY = rsa.generate_private_key(public_exponent=65537, key_size=2048)


class _Jwks(BaseHTTPRequestHandler):
    def do_GET(self):  # noqa: N802
        jwk = json.loads(RSAAlgorithm.to_jwk(KEY.public_key()))
        jwk.update({"kid": KID, "alg": "RS256", "use": "sig"})
        body = json.dumps({"keys": [jwk]}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


def check(label: str, ok: bool, extra: str = "") -> None:
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f"  → {extra}" if extra else ""))
    if not ok:
        raise SystemExit(1)


def token(sub: str, *, key=KEY, aud=CLIENT_ID, iss=ISS, exp_in=600, **claims) -> str:
    now = int(time.time())
    payload = {
        "iss": iss,
        "aud": aud,
        "sub": sub,
        "iat": now,
        "exp": now + exp_in,
        "email": f"{sub}@gmail.com",
        "email_verified": True,
        "given_name": "Ali",
        "family_name": "Valiyev",
        **claims,
    }
    return jwt.encode(payload, key, algorithm="RS256", headers={"kid": KID})


async def set_email(user_id: str, email: str) -> None:
    async with SessionLocal() as db:
        await db.execute(update(User).where(User.id == uuid.UUID(user_id)).values(email=email))
        await db.commit()


def google(c: httpx.Client, id_token: str) -> httpx.Response:
    return c.post("/auth/google", json={"id_token": id_token})


def main() -> None:
    server = HTTPServer(("127.0.0.1", 8799), _Jwks)
    threading.Thread(target=server.serve_forever, daemon=True).start()

    sub = "g" + uuid.uuid4().hex[:20]
    with httpx.Client(base_url=BASE, timeout=20) as c:
        r = google(c, token(sub))
        check("to'g'ri token → kirildi", r.status_code == 200, r.text[:200])
        check("yangi hisob", r.json()["is_new_user"] is True)
        access = r.json()["access_token"]

        me = c.get("/me", headers={"Authorization": f"Bearer {access}"}).json()
        check("ism Google'dan", me["first_name"] == "Ali" and me["last_name"] == "Valiyev", str(me)[:200])
        check("email saqlandi", me["email"] == f"{sub}@gmail.com")
        check("telefon bo'sh", me["phone"] is None)

        again = google(c, token(sub))
        check("qayta kirish → o'sha hisob", again.status_code == 200
              and again.json()["is_new_user"] is False)

        check("boshqa aud → 401", google(c, token(sub, aud="other-app")).status_code == 401)
        check("boshqa kalit → 401", google(c, token(sub, key=OTHER_KEY)).status_code == 401)
        check("muddati o'tgan → 401", google(c, token(sub, exp_in=-3600)).status_code == 401)
        check("boshqa iss → 401", google(c, token(sub, iss="https://evil.example")).status_code == 401)
        check("buzilgan token → 401", google(c, token(sub)[:-6] + "AAAAAA").status_code == 401)
        check("bo'sh token → 422", google(c, "").status_code == 422)

        # Telefon bilan ochilgan hisob: Google email'i bir xil bo'lsa ham
        # unga ulanmaydi — alohida hisob ochiladi.
        phone = "+99890" + str(int(time.time()))[-7:]
        code = c.post("/auth/otp/request", json={"phone": phone}).json()["debug_code"]
        phone_access = c.post(
            "/auth/otp/verify", json={"phone": phone, "code": code}
        ).json()["access_token"]
        phone_me = c.get("/me", headers={"Authorization": f"Bearer {phone_access}"}).json()
        shared = f"shared{uuid.uuid4().hex[:8]}@gmail.com"
        asyncio.run(set_email(phone_me["id"], shared))
        other = "g" + uuid.uuid4().hex[:20]
        r = google(c, token(other, email=shared))
        other_me = c.get(
            "/me", headers={"Authorization": f"Bearer {r.json()['access_token']}"}
        ).json()
        check("email bo'yicha boshqa hisobga ulanmaydi",
              r.json()["is_new_user"] is True and other_me["id"] != phone_me["id"])

        deleted = c.request(
            "DELETE", "/me", json={"confirm": True},
            headers={"Authorization": f"Bearer {access}"},
        )
        check("hisob o'chirildi", deleted.status_code in (200, 204), str(deleted.status_code))
        fresh = google(c, token(sub))
        check("o'chirilgandan keyin → yangi hisob", fresh.status_code == 200
              and fresh.json()["is_new_user"] is True)

    server.shutdown()
    print("\nHammasi o'tdi.")


if __name__ == "__main__":
    main()
