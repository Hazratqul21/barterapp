"""Moderator navbati.

Shikoyat yozilardi-yu, uni hech kim ko'ra olmasdi — ya'ni tugma bor, orqasida
hech narsa yo'q edi.

Talablar:

- Moderator bo'lmagan odam uchun bu endpointlar umuman mavjud bo'lmasin.
  403 emas, 404: 403 "shu manzilda API bor, sizda faqat bayroq yo'q" deb
  aytadi, bu esa keyingi hujum uchun xarita.
- Navbat eskisidan boshlansin. Uch kundan beri turgan shikoyat — mahsulotga
  eng qimmatga tushayotgani; yangisidan boshlanadigan navbat aynan shularni
  ko'mib yuboradi.
- Moderator qarori shikoyatchining izohini o'chirmasin.
- "Actioned" ortida haqiqiy amal bo'lsin — e'lonni yechish imkoni.
"""

import asyncio
import sys
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.db.session import SessionLocal  # noqa: E402
from app.models.user import User  # noqa: E402

BASE = "http://127.0.0.1:8010"
MODERATOR_PHONE = "+998901234122"


async def make_moderator() -> None:
    """
    Bayroqni sinov o'zi qo'yadi.

    `run_all.sh` har sinovdan oldin bazani qaytadan urug'lantiradi, ya'ni
    qo'lda berilgan huquq yo'qoladi. Bayroqni beradigan endpoint esa ataylab
    yo'q — shuning uchun to'g'ridan-to'g'ri bazaga yoziladi, xuddi
    `python -m app.grant_moderator` kabi.
    """
    from sqlalchemy import select

    async with SessionLocal() as db:
        user = await db.scalar(select(User).where(User.phone == MODERATOR_PHONE))
        user.is_moderator = True
        await db.commit()


asyncio.run(make_moderator())


def check(label: str, ok: bool, extra: str = "") -> None:
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f"  → {extra}" if extra else ""))
    if not ok:
        raise SystemExit(1)


def login(c: httpx.Client, phone: str) -> tuple[str, str]:
    code = c.post("/auth/otp/request", json={"phone": phone}).json()["debug_code"]
    token = c.post(
        "/auth/otp/verify", json={"phone": phone, "code": code}
    ).json()["access_token"]
    me = c.get("/me", headers={"Authorization": f"Bearer {token}"}).json()
    return token, me["id"]


def auth(t: str) -> dict:
    return {"Authorization": f"Bearer {t}"}


with httpx.Client(base_url=BASE, timeout=30) as c:
    mod, mod_id = login(c, MODERATOR_PHONE)
    plain, plain_id = login(c, "+998901234961")
    other, other_id = login(c, "+998901234962")

    # --- kirish huquqi -------------------------------------------------------

    r = c.get("/admin/reports")
    check("moderator navbati anonim uchun yopiq", r.status_code == 401)

    r = c.get("/admin/reports", headers=auth(plain))
    check(
        "oddiy foydalanuvchi uchun 404",
        r.status_code == 404,
        f"{r.status_code} — 403 API borligini oshkor qilardi",
    )

    r = c.post(f"/admin/listings/{plain_id}/archive", headers=auth(plain))
    check("oddiy foydalanuvchi e'lon yecha olmaydi", r.status_code == 404)

    r = c.get("/admin/reports", headers=auth(mod))
    check("moderator navbatni ko'radi", r.status_code == 200, str(r.status_code))

    # --- shikoyat yozamiz ----------------------------------------------------

    feed = c.get("/listings", headers=auth(plain), params={"limit": 50}).json()
    target = feed["items"][0]

    r = c.post(
        "/reports",
        headers=auth(plain),
        json={
            "target_type": "listing",
            "target_id": target["id"],
            "reason": "scam",
            "note": "Narxi haqiqiy emas.",
        },
    )
    check("shikoyat yozildi", r.status_code == 201, str(r.status_code))
    report_id = r.json()["id"]

    # Ikkinchi odam ham shikoyat qiladi — takrorlanish emas, naqsh.
    c.post(
        "/reports",
        headers=auth(other),
        json={"target_type": "listing", "target_id": target["id"], "reason": "fake"},
    )

    queue = c.get("/admin/reports", headers=auth(mod)).json()
    mine = [row for row in queue if row["id"] == report_id]
    check("shikoyat navbatda ko'rinadi", len(mine) == 1, str(len(queue)))

    row = mine[0]
    check("holati open", row["review_status"] == "open", row["review_status"])
    check("shikoyatchi ismi bilan keladi", bool(row["reporter_name"]), str(row))
    check(
        "obyekt nomi bilan keladi",
        row["target_label"] == target["title"],
        f"{row['target_label']} — qo'shimcha so'rovsiz o'qiladi",
    )
    check(
        "obyekt bo'yicha shikoyatlar soni",
        row["report_count"] == 2,
        f"{row['report_count']} — bitta nizo, ikkitasi naqsh",
    )
    check("shikoyatchi izohi joyida", row["note"] == "Narxi haqiqiy emas.")

    # --- tartib --------------------------------------------------------------

    stamps = [r["created_at"] for r in queue]
    check(
        "navbat eskisidan boshlanadi",
        stamps == sorted(stamps),
        "uzoq turgan shikoyat ko'milib qolmasin",
    )

    # --- filtr ---------------------------------------------------------------

    # Foydalanuvchi haqida ham shikoyat kerak — aks holda filtr bo'sh to'plamda
    # sinaladi va hamma narsani kesib tashlasa ham o'tib ketardi.
    c.post(
        "/reports",
        headers=auth(plain),
        json={"target_type": "user", "target_id": other_id, "reason": "offensive"},
    )

    only_users = c.get(
        "/admin/reports", headers=auth(mod), params={"target_type": "user"}
    ).json()
    check(
        "target_type filtri faqat kerakligini qoldiradi",
        only_users and all(r["target_type"] == "user" for r in only_users),
        str(len(only_users)),
    )
    check(
        "filtr foydalanuvchi ismini ham keltiradi",
        only_users[0]["target_label"] is not None,
        only_users[0]["target_label"],
    )

    everything = c.get("/admin/reports", headers=auth(mod)).json()
    check(
        "filtrsiz ikkala tur ham keladi",
        {r["target_type"] for r in everything} == {"user", "listing"},
        str({r["target_type"] for r in everything}),
    )

    # --- qaror ---------------------------------------------------------------

    r = c.patch(
        f"/admin/reports/{report_id}",
        headers=auth(mod),
        json={"review_status": "actioned", "resolution": "E'lon yechildi."},
    )
    check("qaror qabul qilindi", r.status_code == 200, str(r.status_code))

    decided = r.json()
    check("holat o'zgardi", decided["review_status"] == "actioned")
    check(
        "shikoyatchining izohi o'chmadi",
        "Narxi haqiqiy emas." in decided["note"],
        decided["note"],
    )
    check(
        "moderator izohi qo'shildi",
        "E'lon yechildi." in decided["note"],
        "ikkalasi ham keyin kerak bo'ladi",
    )

    still_open = c.get("/admin/reports", headers=auth(mod)).json()
    check(
        "hal qilingani ochiq navbatdan chiqdi",
        report_id not in [x["id"] for x in still_open],
    )

    handled = c.get(
        "/admin/reports", headers=auth(mod), params={"review_status": "actioned"}
    ).json()
    check(
        "hal qilinganlar alohida ko'rinadi",
        report_id in [x["id"] for x in handled],
    )

    r = c.patch(
        "/admin/reports/00000000-0000-0000-0000-000000000000",
        headers=auth(mod),
        json={"review_status": "dismissed"},
    )
    check("yo'q shikoyat 404 beradi", r.status_code == 404)

    r = c.patch(
        f"/admin/reports/{report_id}",
        headers=auth(plain),
        json={"review_status": "dismissed"},
    )
    check("oddiy foydalanuvchi qaror qila olmaydi", r.status_code == 404)

    # --- haqiqiy amal --------------------------------------------------------

    r = c.post(f"/admin/listings/{target['id']}/archive", headers=auth(mod))
    check("moderator e'lonni yechdi", r.status_code == 204, str(r.status_code))

    after = c.get("/listings", headers=auth(plain), params={"limit": 50}).json()
    check(
        "yechilgan e'lon lentadan yo'qoldi",
        target["id"] not in [i["id"] for i in after["items"]],
        "aks holda 'actioned' ortida hech narsa turmasdi",
    )

    r = c.post(f"/admin/listings/{target['id']}/archive", headers=auth(mod))
    check("qayta yechish xato emas", r.status_code == 204)

    r = c.post(
        "/admin/listings/00000000-0000-0000-0000-000000000000/archive",
        headers=auth(mod),
    )
    check("yo'q e'lonni yechish 404 beradi", r.status_code == 404)

    # --- bayroqni API orqali olib bo'lmaydi ----------------------------------

    r = c.patch("/me", headers=auth(plain), json={"is_moderator": True})
    check("PATCH /me bayroqni bermaydi", r.status_code == 200, str(r.status_code))

    r = c.get("/admin/reports", headers=auth(plain))
    check(
        "urinishdan keyin ham yopiq",
        r.status_code == 404,
        "bayroq faqat serverdan beriladi",
    )
