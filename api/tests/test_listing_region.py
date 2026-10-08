"""E'lonning o'z hududi: egasidan meros, alohida tanlash, filtr, tahrir."""
import json, sys, urllib.error, urllib.parse, urllib.request

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
            return r.status, json.loads(r.read() or b"null")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"null")


def ok(label, cond, extra=""):
    print(("PASS  " if cond else "FAIL  ") + label + (f"  — {extra}" if extra else ""))
    if not cond:
        sys.exit(1)


def tri(v):
    return {"uz": v, "ru": v, "en": v}


def body(title, **extra):
    return {
        "tag": "electronics", "title": tri(title), "description": tri(title),
        "image_alt": tri(title), "category": tri("x"), "condition": tri("x"),
        "quantity": tri("1"), "wants_summary": tri("x"), "wants": [tri("x")],
        "desires": [{"category": None, "will_add_cash": False, "wants_cash": False}],
        "photos": [], "value": {"minor": 500_000_00, "currency": "UZS"},
        "cash_ok": True, **extra,
    }


phone = "+998901130001"
_, r = call("POST", "/auth/otp/request", {"phone": phone})
_, t = call("POST", "/auth/otp/verify", {"phone": phone, "code": r["debug_code"]})
tok = t["access_token"]
call("PATCH", "/me", {"first_name": "Hudud", "last_name": "Sinov", "region": "Samarqand"},
     token=tok)

st, a = call("POST", "/listings", body("Hudud A"), token=tok)
ok("hudud ko'rsatilmasa — egasiniki", st == 201 and a["region"] == "Samarqand",
   str(a.get("region")))

st, b = call("POST", "/listings",
             body("Hudud B", region="Buxoro", district="G‘ijduvon"), token=tok)
ok("o'z hududi tanlandi", st == 201 and b["region"] == "Buxoro"
   and b["district"] == "G‘ijduvon", str(b)[:160])

st, bad = call("POST", "/listings", body("Hudud C", region="Atlantida"), token=tok)
ok("noma'lum hudud 422", st == 422, str(st))


def feed_ids(region):
    q = urllib.parse.urlencode({"region": region, "limit": 50})
    return {i["id"] for i in call("GET", f"/listings?{q}")[1]["items"]}


ok("filtr e'lonning hududi bo'yicha (Buxoro)",
   b["id"] in feed_ids("Buxoro") and a["id"] not in feed_ids("Buxoro"))
ok("filtr (Samarqand)", a["id"] in feed_ids("Samarqand"))

# Egasi ko'chsa, eski e'lonlar joyida qoladi.
call("PATCH", "/me", {"first_name": "Hudud", "last_name": "Sinov", "region": "Navoiy"},
     token=tok)
ok("egasi ko'chganda e'lon ko'chmaydi", b["id"] in feed_ids("Buxoro")
   and a["id"] in feed_ids("Samarqand"))

st, edited = call("PATCH", f"/listings/{b['id']}", {"region": "Andijon"}, token=tok)
ok("tahrirda hudud o'zgaradi", st == 200 and edited["region"] == "Andijon",
   str(edited)[:160])
ok("tahrirdan keyin filtr", b["id"] in feed_ids("Andijon")
   and b["id"] not in feed_ids("Buxoro"))
