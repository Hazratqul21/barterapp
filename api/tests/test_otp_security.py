"""B1: OTP xavfsizligi — rate-limit va kodni hash sifatida saqlash."""
import json, sys, urllib.request, urllib.error
BASE = "http://127.0.0.1:8010"


def call(method, path, body=None):
    req = urllib.request.Request(BASE + path, method=method)
    req.add_header("Accept-Language", "uz")
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, data) as r:
            return r.status, json.loads(r.read() or b"null")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"null")


def ok(label, cond, extra=""):
    print(("PASS  " if cond else "FAIL  ") + label + (f"  — {extra}" if extra else ""))
    if not cond:
        sys.exit(1)


# ── rate-limit: standart 5 ta so'rov, 6-si 429 ────────────────────────────────
phone = "+998911100011"
statuses = []
for _ in range(6):
    st, _ = call("POST", "/auth/otp/request", {"phone": phone})
    statuses.append(st)

ok("dastlabki 5 so'rov qabul qilinadi", statuses[:5] == [200] * 5, str(statuses))
ok("6-so'rov rate-limit bilan rad etiladi (429)", statuses[5] == 429)

# ── hashlash: to'g'ri kod hali ham ishlaydi (hash orqali solishtiriladi) ───────
phone2 = "+998911100012"
_, r = call("POST", "/auth/otp/request", {"phone": phone2})
code = r["debug_code"]
ok("debug rejimda kod javobda qaytadi", isinstance(code, str) and len(code) == 6)

st, t = call("POST", "/auth/otp/verify", {"phone": phone2, "code": code})
ok("to'g'ri kod bilan kirish (hash solishtiruvi ishlaydi)",
   st == 200 and "access_token" in t)

# ── noto'g'ri kod rad etiladi ─────────────────────────────────────────────────
phone3 = "+998911100013"
call("POST", "/auth/otp/request", {"phone": phone3})
st, _ = call("POST", "/auth/otp/verify", {"phone": phone3, "code": "000000"})
ok("noto'g'ri kod rad etiladi (400)", st == 400)
