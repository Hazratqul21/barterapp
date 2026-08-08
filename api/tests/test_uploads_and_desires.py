"""A6+A7 sinovi: rasm yuklash → desires bilan e'lon → moslik chiqadimi."""
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

# 1. kirish
_, r = call("POST", "/auth/otp/request", {"phone": "+998901110003"})
_, t = call("POST", "/auth/otp/verify", {"phone": "+998901110003", "code": r["debug_code"]})
tok = t["access_token"]
ok("kirish", bool(tok))

# 2. rasm yuklash — haqiqiy PNG, katta o'lchamda, alfa kanali bilan
img = Image.new("RGBA", (2400, 1800), (30, 160, 110, 255))
buf = io.BytesIO(); img.save(buf, format="PNG")
png = buf.getvalue()

boundary = "----barter"
body = (
    f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"x.png\"\r\n"
    f"Content-Type: image/png\r\n\r\n"
).encode() + png + f"\r\n--{boundary}--\r\n".encode()
st, up = call("POST", "/uploads", raw=body, ctype=f"multipart/form-data; boundary={boundary}", token=tok)
ok("rasm yuklandi", st == 201, f"{up.get('width')}x{up.get('height')}, {up.get('bytes',0)//1024} KB")
ok("uzun tomoni 1600 ga tushdi", up["width"] == 1600)
ok("URL ochiladi", urllib.request.urlopen(up["url"]).status == 200, up["url"])

# 3. rasm bo'lmagan fayl rad etiladi
body2 = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"a.jpg\"\r\n"
         f"Content-Type: image/jpeg\r\n\r\nnot-an-image\r\n--{boundary}--\r\n").encode()
st, err = call("POST", "/uploads", raw=body2, ctype=f"multipart/form-data; boundary={boundary}", token=tok)
ok("soxta rasm rad etildi", st == 400, err.get("detail"))

# 4. desires bilan e'lon — traktor qidiryapman
def tri(u, ru, en): return {"uz": u, "ru": ru, "en": en}
listing = {
    "tag": "agri",
    "title": tri("20 t bug'doy", "20 т пшеницы", "20 t wheat"),
    "description": tri("Yangi hosil", "Новый урожай", "New harvest"),
    "image_alt": tri("Bug'doy", "Пшеница", "Wheat"),
    "category": tri("Don", "Зерно", "Grain"),
    "condition": tri("Yangi", "Новое", "New"),
    "quantity": tri("20 tonna", "20 тонн", "20 tons"),
    "wants_summary": tri("Traktor", "Трактор", "Tractor"),
    "wants": [tri("Traktor 80+ ot kuchi", "Трактор 80+ л.с.", "Tractor 80+ hp")],
    "desires": [{"category": "machinery", "min_value_minor": 300000000,
                 "max_value_minor": 900000000, "will_add_cash": True}],
    "photos": [up["url"]],
    "value": {"minor": 400000000, "currency": "UZS"},
    "cash_ok": True,
}
st, created = call("POST", "/listings", listing, token=tok)
ok("e'lon yaratildi", st == 201, created.get("title") if st == 201 else created)
ok("rasm biriktirildi", created["image_url"] == up["url"])

# 5. moslik hosil bo'ldimi
st, matches = call("GET", "/matches", token=tok)
mine = [m for m in matches if m["mine"]["id"] == created["id"]]
ok("yangi e'lon moslik berdi", len(mine) > 0,
   f"{len(matches)} moslik, eng yaxshisi {mine[0]['score']}% — {mine[0]['theirs']['title']}" if mine else "0")

# 6. desires yubormasak ham moslik chiqadimi (avtomatik oraliq)
bare = dict(listing)
bare["title"] = tri("Eski velosiped", "Старый велосипед", "Old bicycle")
bare["tag"] = "transport"
bare.pop("desires")
bare["value"] = {"minor": 148000000, "currency": "UZS"}
st, plain = call("POST", "/listings", bare, token=tok)
ok("desires'siz e'lon yaratildi", st == 201)
st, matches2 = call("GET", "/matches", token=tok)
auto = [m for m in matches2 if m["mine"]["id"] == plain["id"]]
ok("avtomatik oraliq moslik berdi", len(auto) > 0,
   f"{auto[0]['score']}% — {auto[0]['theirs']['title']}" if auto else "0 (rebuild 5 daq keshlangan bo'lishi mumkin)")

print("\nHammasi o'tdi.")
