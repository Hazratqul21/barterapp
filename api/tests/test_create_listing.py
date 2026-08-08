"""B6: mijoz yuboradigan aynan shu payload server tomonidan qabul qilinadimi."""
import io, json, sys, urllib.request, urllib.error
from PIL import Image
BASE = "http://127.0.0.1:8010"

def call(method, path, body=None, token=None, raw=None, ctype=None):
    req = urllib.request.Request(BASE + path, method=method)
    req.add_header("Accept-Language", "uz")
    if token: req.add_header("Authorization", f"Bearer {token}")
    data = None
    if body is not None:
        data = json.dumps(body).encode(); req.add_header("Content-Type", "application/json")
    elif raw is not None:
        data = raw; req.add_header("Content-Type", ctype)
    try:
        with urllib.request.urlopen(req, data) as r:
            return r.status, json.loads(r.read() or b"null")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"null")

def ok(label, cond, extra=""):
    print(("PASS  " if cond else "FAIL  ") + label + (f"  — {extra}" if extra else ""))
    if not cond: sys.exit(1)

_, r = call("POST", "/auth/otp/request", {"phone": "+998901110004"})
_, t = call("POST", "/auth/otp/verify", {"phone": "+998901110004", "code": r["debug_code"]})
tok = t["access_token"]

# 1. surat
img = Image.new("RGB", (1800, 1200), (120, 90, 60))
buf = io.BytesIO(); img.save(buf, format="JPEG")
b = "----x"
body = (f"--{b}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"a.jpg\"\r\n"
        f"Content-Type: image/jpeg\r\n\r\n").encode() + buf.getvalue() + f"\r\n--{b}--\r\n".encode()
st, up = call("POST", "/uploads", raw=body, ctype=f"multipart/form-data; boundary={b}", token=tok)
ok("surat yuklandi", st == 201, up.get("url", up))

def tri(u, ru, en): return {"uz": u, "ru": ru, "en": en}

# 2. ESKI payload — nima uchun hech kim e'lon joylay olmasligini ko'rsatamiz
old = {
    "tag": "electronics",
    "photos": [up["url"]],
    "title": tri("Noutbuk", "Ноутбук", "Laptop"),
    "description": tri("a", "b", "c"),
    "category": tri("a", "b", "c"),
    "condition": tri("a", "b", "c"),
    "quantity": tri("a", "b", "c"),
    "wants_summary": tri("a", "b", "c"),
    "value_minor": 500000000,
    "cash_ok": True,
}
st, err = call("POST", "/listings", old, token=tok)
ok("eski payload hali ham 422 beradi", st == 422,
   ", ".join(sorted({".".join(str(x) for x in d["loc"][1:]) for d in err["detail"]})))

# 3. YANGI payload — ekran aynan shuni yuboradi
new = {
    "tag": "electronics",
    "title": tri("MacBook Air M2", "MacBook Air M2", "MacBook Air M2"),
    "description": tri("Toza holatda", "В отличном состоянии", "Mint condition"),
    "image_alt": tri("MacBook Air M2", "MacBook Air M2", "MacBook Air M2"),
    "category": tri("Noutbuk", "Ноутбук", "Laptop"),
    "condition": tri("Ishlatilgan", "Б/у", "Used"),
    "quantity": tri("1 dona", "1 шт", "1 piece"),
    "wants_summary": tri("Uy remonti", "Ремонт квартиры", "Flat renovation"),
    "wants": [tri("Uy remonti", "Ремонт квартиры", "Flat renovation")],
    "desires": [{"category": None, "will_add_cash": True, "wants_cash": False}],
    "photos": [up["url"]],
    "value": {"minor": 1200000000, "currency": "UZS"},
    "cash_ok": True,
}
st, created = call("POST", "/listings", new, token=tok)
ok("yangi payload qabul qilindi", st == 201, created.get("title") if st == 201 else created)
ok("surat biriktirildi", created["image_url"] == up["url"])
ok("uch til saqlandi", created["title"] == "MacBook Air M2")

st, mine = call("GET", "/me/listings", token=tok)
ok("e'lonlarim ro'yxatida", any(x["id"] == created["id"] for x in mine))

st, matches = call("GET", "/matches", token=tok)
found = [m for m in matches if m["mine"]["id"] == created["id"]]
ok("moslik darrov hisoblandi", len(found) > 0,
   f"{found[0]['score']}% — {found[0]['theirs']['title']}" if found else "0")

print("\nHammasi o'tdi — e'lon joylash zanjiri butun.")
