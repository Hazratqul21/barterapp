"""E'lon bitta tilda yoziladi: qolgan tillar muallifning o'z matnini oladi."""
import io, json, sys, urllib.parse, urllib.request, urllib.error
from PIL import Image
BASE = "http://127.0.0.1:8010"

def call(method, path, body=None, token=None, raw=None, ctype=None, lang="uz"):
    req = urllib.request.Request(BASE + path, method=method)
    req.add_header("Accept-Language", lang)
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

img = Image.new("RGB", (800, 600), (40, 120, 60))
buf = io.BytesIO(); img.save(buf, format="JPEG")
b = "----x"
body = (f"--{b}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"a.jpg\"\r\n"
        f"Content-Type: image/jpeg\r\n\r\n").encode() + buf.getvalue() + f"\r\n--{b}--\r\n".encode()
st, up = call("POST", "/uploads", raw=body, ctype=f"multipart/form-data; boundary={b}", token=tok)
ok("surat yuklandi", st == 201, up)

def ru(text): return {"ru": text}

listing = {
    "tag": "agri",
    "title": ru("Рис 2 тонны"),
    "description": ru("Сорт Лазер, урожай этого года"),
    "image_alt": ru("Рис 2 тонны"),
    "category": {"uz": "Qishloq xo‘jaligi", "ru": "Сельское хозяйство", "en": "Agriculture"},
    "condition": ru("Новый"),
    "quantity": ru("2 т"),
    "wants_summary": ru("Насос"),
    "wants": [ru("Насос")],
    "photos": [up["url"]],
    "value": {"minor": 1400000000, "currency": "UZS"},
}
st, created = call("POST", "/listings", listing, token=tok, lang="ru")
ok("bitta tilda yozilgan e'lon qabul qilindi", st == 201, created)

for lang in ("uz", "ru", "en"):
    st, d = call("GET", f"/listings/{created['id']}", lang=lang)
    ok(f"{lang}: muallif matni ko'rinadi", d["title"] == "Рис 2 тонны" and d["wants"] == ["Насос"], d["title"])
st, d = call("GET", f"/listings/{created['id']}", lang="en")
ok("berilgan tarjima saqlanadi", d["category"] == "Agriculture", d["category"])

st, err = call("POST", "/listings", {**listing, "title": {"uz": "  ", "ru": ""}}, token=tok)
ok("hech bir tilda matn bo'lmasa 422", st == 422, err)

st, _ = call("PATCH", f"/listings/{created['id']}", {"title": {"uz": "Guruch 2 tonna"}}, token=tok)
ok("tahrir bitta tilda", st == 200)
for lang in ("uz", "ru", "en"):
    st, d = call("GET", f"/listings/{created['id']}", lang=lang)
    ok(f"{lang}: yangi nom hamma tilda", d["title"] == "Guruch 2 tonna", d["title"])

st, found = call("GET", "/listings?q=" + urllib.parse.quote("Guruch 2"))
ok("har qanday tildagi o'quvchi topadi", any(x["id"] == created["id"] for x in found["items"]), found)

print("\nHammasi o'tdi — e'lon bitta tilda joylanadi.")
