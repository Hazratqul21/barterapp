"""B2: refresh token rotation, reuse aniqlash, logout, logout-all."""
import json, sys, urllib.request, urllib.error
BASE = "http://127.0.0.1:8010"


def call(method, path, body=None, token=None):
    req = urllib.request.Request(BASE + path, method=method)
    req.add_header("Accept-Language", "uz")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, data) as r:
            raw = r.read()
            return r.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        raw = e.read()
        return e.code, (json.loads(raw) if raw else None)


def ok(label, cond, extra=""):
    print(("PASS  " if cond else "FAIL  ") + label + (f"  — {extra}" if extra else ""))
    if not cond:
        sys.exit(1)


def login(phone):
    _, r = call("POST", "/auth/otp/request", {"phone": phone})
    _, t = call("POST", "/auth/otp/verify", {"phone": phone, "code": r["debug_code"]})
    return t


# ── rotation ──────────────────────────────────────────────────────────────────
t = login("+998922200031")
rt1 = t["refresh_token"]
st, t2 = call("POST", "/auth/refresh", {"refresh_token": rt1})
ok("refresh yangi juft beradi (rotation)",
   st == 200 and t2["refresh_token"] != rt1)
rt2 = t2["refresh_token"]

# ── reuse aniqlash: eski token qayta ishlatilsa hamma sessiya bekor ───────────
st_reuse, _ = call("POST", "/auth/refresh", {"refresh_token": rt1})
ok("bekor qilingan tokenni qayta ishlatish rad etiladi (401)", st_reuse == 401)
st_after, _ = call("POST", "/auth/refresh", {"refresh_token": rt2})
ok("reuse'dan keyin amaldagi token ham bekor (barcha sessiya)", st_after == 401)

# ── logout: shu sessiyani tugatadi ───────────────────────────────────────────
t = login("+998922200032")
rt = t["refresh_token"]
st_lo, _ = call("POST", "/auth/logout", {"refresh_token": rt})
ok("logout 204 qaytaradi", st_lo == 204)
st_dead, _ = call("POST", "/auth/refresh", {"refresh_token": rt})
ok("logout'dan keyin refresh ishlamaydi (401)", st_dead == 401)

# ── logout-all: barcha sessiyalarni tugatadi ─────────────────────────────────
t = login("+998922200033")
access = t["access_token"]
# ikkinchi sessiya (rotation orqali yangi refresh)
_, t_b = call("POST", "/auth/refresh", {"refresh_token": t["refresh_token"]})
rt_b = t_b["refresh_token"]
st_all, _ = call("POST", "/auth/logout-all", token=access)
ok("logout-all 204 qaytaradi", st_all == 204)
st_b, _ = call("POST", "/auth/refresh", {"refresh_token": rt_b})
ok("logout-all'dan keyin barcha refresh bekor (401)", st_b == 401)
