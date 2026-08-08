"""Sharh yozish — savdo aylanishini yopadi."""
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

a, b = login("+998901234122"), login("+998901110002")
_, bek = call("GET", "/me", token=b)
_, feed = call("GET", "/listings?limit=20", token=a)
_, mine = call("GET", "/me/listings", token=a)
target = next(x for x in feed["items"] if x["owner"]["id"] == bek["id"])

st, offer = call("POST", "/offers", {"listing_id": target["id"],
    "offered_listing_ids": [mine[0]["id"]], "cash_delta_minor": 0}, token=a)
oid = offer["id"]

# hali yakunlanmagan
st, err = call("POST", "/reviews", {"offer_id": oid, "rating": 5, "body": "Zo'r"}, token=a)
ok("yakunlanmagan savdoga sharh rad etiladi", st == 409, err.get("detail"))

call("PATCH", f"/offers/{oid}", {"action": "accept"}, token=b)
call("PATCH", f"/offers/{oid}", {"action": "complete"}, token=a)

st, review = call("POST", "/reviews", {"offer_id": oid, "rating": 5,
    "body": "Vaqtida keldi, hammasi aytilganidek."}, token=a)
ok("yakunlangan savdoga sharh yozildi", st == 201, f"{review['rating']}★")

st, dup = call("POST", "/reviews", {"offer_id": oid, "rating": 1, "body": "yana"}, token=a)
ok("takroriy sharh rad etiladi", st == 409, dup.get("detail"))

st, about_b = call("GET", f"/users/{bek['id']}/reviews")
ok("sharh Bekzod haqida", any(r["id"] == review["id"] for r in about_b), f"{len(about_b)} ta")

_, about_a = call("GET", f"/users/{json.loads(json.dumps(call('GET','/me',token=a)[1]))['id']}/reviews")
ok("muallif o'ziga sharh olmadi", not any(r["id"] == review["id"] for r in about_a))

st, existing = call("GET", f"/offers/{oid}/review", token=a)
ok("ekran o'z sharhini topa oladi", st == 200 and existing and existing["id"] == review["id"])

st, none_yet = call("GET", f"/offers/{oid}/review", token=b)
ok("narigi tomon hali yozmagan", st == 200 and none_yet is None)

_, profile = call("GET", f"/users/{bek['id']}")
ok("reyting yangilandi", profile["rating"] is not None, f"★{profile['rating']} · {profile['review_count']} sharh")

print("\nSavdo aylanishi yopildi.")
