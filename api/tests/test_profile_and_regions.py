"""B3: ism saqlanadimi, hudud koordinata beradimi, moslikka ta'sir qiladimi."""
import json, sys, urllib.request, urllib.error
BASE = "http://127.0.0.1:8010"

def call(method, path, body=None, token=None):
    req = urllib.request.Request(BASE + path, method=method)
    req.add_header("Accept-Language", "uz")
    if token: req.add_header("Authorization", f"Bearer {token}")
    data = None
    if body is not None:
        data = json.dumps(body).encode(); req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, data) as r:
            return r.status, json.loads(r.read() or b"null")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"null")

def ok(label, cond, extra=""):
    print(("PASS  " if cond else "FAIL  ") + label + (f"  — {extra}" if extra else ""))
    if not cond: sys.exit(1)

st, regions = call("GET", "/regions")
ok("hududlar ro'yxati", st == 200 and len(regions) == 14, f"{len(regions)} ta")

# yangi hisob
phone = "+998907654321"
_, r = call("POST", "/auth/otp/request", {"phone": phone})
_, t = call("POST", "/auth/otp/verify", {"phone": phone, "code": r["debug_code"]})
tok = t["access_token"]
ok("yangi hisob yaratildi", t.get("is_new_user") is True)

st, me = call("GET", "/me", token=tok)
ok("yangi hisob ismsiz", me["first_name"] == "" and me["name"].strip() == "")

# eski mijoz yuborgan shakl — jimgina tashlab yuborilishini ko'rsatamiz
st, after_bad = call("PATCH", "/me", {"name": "Aziz Karimov"}, token=tok)
ok("eski 'name' maydoni HALI HAM jimgina tashlanadi",
   st == 200 and after_bad["first_name"] == "",
   "shuning uchun mijoz first_name/last_name yuborishi shart")

# to'g'ri shakl
st, after = call("PATCH", "/me",
                 {"first_name": "Aziz", "last_name": "Karimov", "region": "Samarqand"},
                 token=tok)
ok("ism saqlandi", after["name"] == "Aziz Karimov", after["name"])
ok("hudud saqlandi", after["region"] == "Samarqand")

# koordinata hosil bo'ldimi — /me qaytarmaydi, mosliklar orqali tekshiramiz
st, regions2 = call("GET", "/regions")
st, alias = call("PATCH", "/me", {"region": "Ташкент"}, token=tok)
ok("ruscha hudud nomi tanildi", alias["region"] == "Ташкент")

print("\nHammasi o'tdi.")
