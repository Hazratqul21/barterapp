"""B8: xabar tartibi va qarshi taklif — mijoz endi qaysi yo'ldan borsa o'sha."""
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

def login(phone):
    _, r = call("POST", "/auth/otp/request", {"phone": phone})
    _, t = call("POST", "/auth/otp/verify", {"phone": phone, "code": r["debug_code"]})
    return t["access_token"]

a = login("+998901234122")   # Jasur
b = login("+998901110002")   # Bekzod

# Jasur Bekzodning e'loniga taklif yuboradi
_, bekzod = call("GET", "/me", token=b)
_, feed = call("GET", "/listings?limit=20", token=a)
_, mine = call("GET", "/me/listings", token=a)
# Aynan Bekzodning e'loni — qarshi taklifni u yuborishi kerak.
target = next(x for x in feed["items"] if x["owner"]["id"] == bekzod["id"])
st, offer = call("POST", "/offers", {
    "listing_id": target["id"], "offered_listing_ids": [mine[0]["id"]],
    "cash_delta_minor": 0, "message": "Birinchi xabar"}, token=a)
ok("taklif yuborildi", st == 201)
thread = offer["conversation_id"]

for i, text in enumerate(["Ikkinchi xabar", "Uchinchi xabar"], start=2):
    call("POST", f"/conversations/{thread}/messages", {"body": text}, token=a)

st, detail = call("GET", f"/conversations/{thread}", token=a)
bodies = [m["body"] for m in detail["messages"]]
ok("server eskidan yangiga qaytaradi", bodies == ["Birinchi xabar", "Ikkinchi xabar", "Uchinchi xabar"],
   " → ".join(bodies))
print("      ekran reverse:true bilan teskari o'qiydi, ya'ni oxirgisi pastda")

# QARSHI TAKLIF — eski yo'l: Bekzod o'z e'loniga taklif yuborishga urinadi
owner_listing = offer["wanted"]["id"]
st, err = call("POST", "/offers", {
    "listing_id": owner_listing, "offered_listing_ids": [mine[0]["id"]]}, token=b)
ok("eski 'counter' yo'li hali ham rad etiladi", st == 400, err.get("detail"))

# yangi yo'l: PATCH counter
st, countered = call("PATCH", f"/offers/{offer['id']}",
                     {"action": "counter", "cash_delta_minor": 150000000}, token=b)
ok("PATCH counter qabul qilindi", st == 200, json.dumps(countered)[:200])
ok("tomonlar almashdi", countered["is_mine"] is True, "Bekzod endi jo'natuvchi")
ok("pul yangilandi", countered["cash_delta_minor"] == 150000000)

st, from_a = call("GET", f"/offers/{offer['id']}", token=a)
ok("Jasur uchun endi javob navbati", from_a["is_mine"] is False)

st, accepted = call("PATCH", f"/offers/{offer['id']}", {"action": "accept"}, token=a)
ok("qarshi taklifdan keyin qabul qilindi", accepted["status"] == "accepted")

print("\nHammasi o'tdi.")
