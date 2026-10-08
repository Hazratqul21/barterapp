"""Suhbat arxivi: har kim o'zi uchun; yangi xabar arxivdan chiqaradi."""
import httpx

BASE = "http://127.0.0.1:8010"


def sign_in(c, phone):
    code = c.post("/auth/otp/request", json={"phone": phone}).json()["debug_code"]
    return c.post("/auth/otp/verify", json={"phone": phone, "code": code}).json()[
        "access_token"
    ]


def check(label, ok, extra=""):
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f"  — {extra}" if extra else ""))
    if not ok:
        raise SystemExit(1)


def ids(rows):
    return {r["id"] for r in rows}


with httpx.Client(base_url=BASE, timeout=20) as c:
    HJ = {"Authorization": f"Bearer {sign_in(c, '+998901234122')}"}
    HB = {"Authorization": f"Bearer {sign_in(c, '+998901110002')}"}

    mine = c.get("/me/listings", headers=HJ).json()
    feed = c.get("/listings", headers=HJ).json()["items"]
    theirs = next(x for x in feed if x["owner"]["name"].startswith("Bek"))
    offer = c.post("/offers", headers=HJ, json={
        "listing_id": theirs["id"],
        "offered_listing_ids": [mine[0]["id"]],
        "cash_delta_minor": 0,
        "message": "Arxiv sinovi",
    }).json()
    tid = offer["conversation_id"]
    check("suhbat ochildi", tid is not None)

    r = c.post(f"/conversations/{tid}/archive", headers=HJ)
    check("arxivlash 204", r.status_code == 204, str(r.status_code))
    check("ikki marta arxivlash xato emas",
          c.post(f"/conversations/{tid}/archive", headers=HJ).status_code == 204)

    check("menga — kirish qutisidan yo'qoldi",
          tid not in ids(c.get("/conversations", headers=HJ).json()))
    arch = c.get("/conversations", params={"archived": "true"}, headers=HJ).json()
    check("arxivda ko'rinadi", tid in ids(arch)
          and next(r for r in arch if r["id"] == tid)["archived"] is True)
    check("sherigimga — o'zgarishsiz",
          tid in ids(c.get("/conversations", headers=HB).json()))

    c.post(f"/conversations/{tid}/messages", headers=HB, json={"body": "Hali qiziqasizmi?"})
    check("yangi xabar arxivdan chiqardi",
          tid in ids(c.get("/conversations", headers=HJ).json()))

    c.post(f"/conversations/{tid}/archive", headers=HJ)
    r = c.delete(f"/conversations/{tid}/archive", headers=HJ)
    check("qo'lda arxivdan chiqarish", r.status_code == 204
          and tid in ids(c.get("/conversations", headers=HJ).json()))

    HX = {"Authorization": f"Bearer {sign_in(c, '+998901140001')}"}
    check("begona suhbatni arxivlay olmaydi",
          c.post(f"/conversations/{tid}/archive", headers=HX).status_code == 404)
