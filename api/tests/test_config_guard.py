"""APP_ENV=production: xavfli sozlama bilan server ishga tushmaydi.

Serverga murojaat qilmaydi — `Settings` to'g'ridan-to'g'ri quriladi.
"""
import os, sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from pydantic import ValidationError

from app.core.config import (
    InsecureConfiguration, LOOPBACK_ORIGIN_REGEX, Settings, _guard_production,
)


def ok(label, cond, extra=""):
    print(("PASS  " if cond else "FAIL  ") + label + (f"  — {extra}" if extra else ""))
    if not cond:
        sys.exit(1)


GOOD = dict(
    app_env="production",
    otp_debug=False,
    jwt_secret="x" * 48,
    eskiz_email="ops@example.uz",
    eskiz_password="not-a-real-password",
    sms_required=True,
    cors_origins=("https://barter.example.uz",),
)


def make(**over):
    # _env_file=None: CI yoki lokal .env natijaga ta'sir qilmasin.
    return Settings(_env_file=None, **{**GOOD, **over})


def refused(**over):
    try:
        _guard_production(make(**over))
    except InsecureConfiguration as e:
        return str(e)
    return None


# ── to'g'ri sozlama ───────────────────────────────────────────────────────────
try:
    _guard_production(make())
    ok("to'g'ri production sozlamasi qabul qilinadi", True)
except InsecureConfiguration as e:
    ok("to'g'ri production sozlamasi qabul qilinadi", False, str(e))

ok("productionda loopback CORS regex yo'q", make().cors_origin_regex is None)
ok("developmentda loopback CORS regex bor",
   make(app_env="development").cors_origin_regex == LOOPBACK_ORIGIN_REGEX)

# ── har bir xavfli sozlama alohida rad etiladi ───────────────────────────────
cases = [
    ("OTP_DEBUG=true", dict(otp_debug=True), "OTP_DEBUG"),
    ("standart JWT_SECRET", dict(jwt_secret="dev-only-change-me"), "JWT_SECRET"),
    ("qisqa JWT_SECRET", dict(jwt_secret="x" * 31), "JWT_SECRET"),
    ("ESKIZ_EMAIL bo'sh", dict(eskiz_email=""), "ESKIZ"),
    ("ESKIZ_PASSWORD bo'sh", dict(eskiz_password=""), "ESKIZ"),
    ("SMS_REQUIRED=false", dict(sms_required=False), "SMS_REQUIRED"),
    ("CORS bo'sh", dict(cors_origins=()), "CORS_ORIGINS"),
    ("CORS wildcard", dict(cors_origins=("*",)), "wildcard"),
    ("CORS subdomen wildcard", dict(cors_origins=("https://*.example.uz",)), "wildcard"),
    ("CORS localhost", dict(cors_origins=("https://localhost:3000",)), "lokal"),
    ("CORS 127.0.0.1", dict(cors_origins=("https://127.0.0.1",)), "lokal"),
    ("CORS http", dict(cors_origins=("http://barter.example.uz",)), "https"),
]
for label, over, needle in cases:
    msg = refused(**over)
    ok(f"rad etiladi: {label}", msg is not None and needle in msg, msg or "qabul qilindi")

# ── barcha muammo bitta xabarda ───────────────────────────────────────────────
msg = refused(otp_debug=True, jwt_secret="short", sms_required=False)
ok("bir nechta muammo bir xabarda",
   msg is not None and all(k in msg for k in ("OTP_DEBUG", "JWT_SECRET", "SMS_REQUIRED")))

# ── noma'lum APP_ENV jimgina development bo'lib qolmaydi ─────────────────────
try:
    make(app_env="prod")
    ok("noma'lum APP_ENV rad etiladi", False)
except ValidationError:
    ok("noma'lum APP_ENV rad etiladi", True)

# ── development/test rejimlari o'zgarmadi ────────────────────────────────────
for env in ("development", "test"):
    s = make(app_env=env, otp_debug=True, sms_required=False, eskiz_email="",
             cors_origins=("http://localhost:3000",))
    ok(f"{env}: production tekshiruvi ishlamaydi", not s.is_production)
