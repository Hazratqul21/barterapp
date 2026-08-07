"""
End-to-end walk through the whole trade loop against a running API.

Needs a freshly seeded database — the test completes a deal, which closes the
listings it used, so a second run has nothing left to trade:

    .venv/bin/python -m app.seed && .venv/bin/python tests/test_trade_loop.py
"""

import httpx

BASE = "http://127.0.0.1:8010"


def sign_in(client: httpx.Client, phone: str) -> str:
    code = client.post("/auth/otp/request", json={"phone": phone}).json()["debug_code"]
    tokens = client.post("/auth/otp/verify", json={"phone": phone, "code": code}).json()
    return tokens["access_token"]


def check(label: str, ok: bool, extra: str = "") -> None:
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f"  — {extra}" if extra else ""))
    if not ok:
        raise SystemExit(1)


with httpx.Client(base_url=BASE, timeout=20) as c:
    jasur = sign_in(c, "+998901234122")   # me
    bek = sign_in(c, "+998901110002")     # Bekzod

    H_J = {"Authorization": f"Bearer {jasur}", "Accept-Language": "uz"}
    H_B = {"Authorization": f"Bearer {bek}", "Accept-Language": "uz"}

    mine = c.get("/me/listings", headers=H_J).json()
    my_laptop = next(x for x in mine if "MacBook" in x["title"])

    feed = c.get("/listings", headers=H_J).json()["items"]
    their_phone = next(x for x in feed if "iPhone" in x["title"])
    check("feed hides my own listings", all(i["owner"]["name"] != "Jasur Toshmatov" for i in feed))

    # --- send an offer -------------------------------------------------------
    offer = c.post(
        "/offers",
        headers=H_J,
        json={
            "listing_id": their_phone["id"],
            "offered_listing_ids": [my_laptop["id"]],
            "cash_delta_minor": 10000,
            "message": "MacBook + $100 ga almashamizmi?",
        },
    ).json()
    check("offer created", offer["status"] == "pending", offer["id"][:8])
    check("offer opens a thread", offer["conversation_id"] is not None)

    # --- the recipient cannot be talked into an illegal transition -----------
    bad = c.patch(f"/offers/{offer['id']}", headers=H_J, json={"action": "accept"})
    check("sender cannot accept their own offer", bad.status_code == 409, bad.json()["detail"])

    # --- Bekzod sees it and counters ----------------------------------------
    inbox = c.get("/conversations", headers=H_B).json()
    thread = next(t for t in inbox if t["offer_id"] == offer["id"])
    check("offer reaches the recipient inbox", thread["unread"] >= 1, thread["deal_summary"])

    countered = c.patch(
        f"/offers/{offer['id']}",
        headers=H_B,
        json={"action": "counter", "cash_delta_minor": 15000, "message": "$150 bo‘lsa roziman."},
    ).json()
    check("counter flips direction", countered["status"] == "talking")

    # Now Jasur is the recipient and may accept.
    accepted = c.patch(f"/offers/{offer['id']}", headers=H_J, json={"action": "accept"}).json()
    check("accept after counter", accepted["status"] == "accepted")

    # --- chat ---------------------------------------------------------------
    tid = offer["conversation_id"]
    c.post(f"/conversations/{tid}/messages", headers=H_J, json={"body": "Kelishdik!"})
    detail = c.get(f"/conversations/{tid}", headers=H_B).json()
    check("messages land in the thread", len(detail["messages"]) >= 3, f"{len(detail['messages'])} msgs")

    reread = c.get("/conversations", headers=H_B).json()
    row = next(t for t in reread if t["offer_id"] == offer["id"])
    check("opening a thread clears its unread badge", row["unread"] == 0)

    # --- complete, which closes both listings -------------------------------
    done = c.patch(f"/offers/{offer['id']}", headers=H_J, json={"action": "complete"}).json()
    check("deal completed", done["status"] == "completed")

    after = c.get("/listings", headers=H_J).json()["items"]
    check("completed listings leave the feed", all(i["id"] != their_phone["id"] for i in after))

    # --- notifications carry their own destination --------------------------
    notes = c.get("/notifications", headers=H_B).json()
    chat_note = next(n for n in notes if n["target_type"] == "chat")
    check("notification names its destination", chat_note["target_id"] == tid)

    # --- matches, verification, payments ------------------------------------
    matches = c.get("/matches", headers=H_J).json()
    check("matches computed", isinstance(matches, list), f"{len(matches)} matches")
    if matches:
        m = matches[0]
        check(
            "match owner is the owner of their listing",
            m["owner"]["id"] == m["theirs"]["owner"]["id"],
            f"{m['score']}% · {m['owner']['name']}",
        )

    ver = c.get("/me/verification", headers=H_J).json()
    check("verification steps listed", len(ver["steps"]) == 5, f"trust {ver['trust_score']}")

    cards = c.get("/me/payment-methods", headers=H_J).json()
    check("cards listed", len(cards) == 2)
    second = cards[1]["id"]
    cards = c.post(f"/me/payment-methods/{second}/primary", headers=H_J).json()
    check("primary card switches", next(x for x in cards if x["id"] == second)["is_primary"])
    cards = c.delete(f"/me/payment-methods/{second}", headers=H_J).json()
    check("removing the primary promotes another", len(cards) == 1 and cards[0]["is_primary"])

    settle = c.get("/me/settlements", headers=H_J).json()
    check("settlement recorded for the completed deal", len(settle) >= 1,
          f"{settle[0]['amount']['minor']/100:.0f} {settle[0]['amount']['currency']}")

    # --- reviews are still about the right person ---------------------------
    bek_id = offer["counterparty"]["id"]
    revs = c.get(f"/users/{bek_id}/reviews").json()
    check("reviews are about that trader only", all(r["author_id"] != bek_id for r in revs),
          f"{len(revs)} reviews")

print("\nAll checks passed.")
