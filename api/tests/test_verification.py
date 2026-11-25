"""Shaxsni tasdiqlash.

Talablar:

- Hujjatsiz yoki roziliksiz topshirib bo'lmaydi (eski ilova aynan shunday qilardi).
- Surat ochiq havolada va bazada ochiq ko'rinishda turmaydi.
- Navbat moderatordan boshqaga yo'q (404), o'z arizasini o'zi tasdiqlamaydi.
- Qarordan keyin surat o'chadi, ball bosqichlar yig'indisiga teng.
- Pasport + selfi "Tasdiqlangan" qiladi; selfi pasportsiz o'tmaydi.
- Hisob o'chirilsa hujjat qolmaydi.
"""

import asyncio
import io
import sys
from datetime import UTC, datetime, timedelta
from pathlib import Path

import httpx
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import select, update  # noqa: E402

from app import auth_prune  # noqa: E402
from app.db.session import SessionLocal, engine  # noqa: E402
from app.models.social import VerificationDocument  # noqa: E402
from app.models.user import User  # noqa: E402

BASE = "http://127.0.0.1:8010"
MODERATOR_PHONE = "+998901234122"


def run(coro):
    async def wrapped():
        try:
            return await coro
        finally:
            await engine.dispose()

    return asyncio.run(wrapped())


async def make_moderator() -> None:
    async with SessionLocal() as db:
        await db.execute(
            update(User).where(User.phone == MODERATOR_PHONE).values(is_moderator=True)
        )
        await db.commit()


async def stored(user_id: str) -> list[bytes]:
    async with SessionLocal() as db:
        return [
            bytes(x)
            for x in (
                await db.scalars(
                    select(VerificationDocument.data).where(
                        VerificationDocument.user_id == user_id
                    )
                )
            ).all()
        ]


async def age_documents(user_id: str) -> None:
    async with SessionLocal() as db:
        await db.execute(
            update(VerificationDocument)
            .where(VerificationDocument.user_id == user_id)
            .values(created_at=datetime.now(UTC) - timedelta(days=10))
        )
        await db.commit()


def check(label: str, ok: bool, extra: str = "") -> None:
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f"  → {extra}" if extra else ""))
    if not ok:
        raise SystemExit(1)


def photo(color: str = "navy") -> dict:
    buffer = io.BytesIO()
    exif = Image.Exif()
    exif[0x010E] = "maxfiy-joylashuv"
    Image.new("RGB", (640, 420), color).save(buffer, "JPEG", exif=exif)
    return {"file": ("id.jpg", buffer.getvalue(), "image/jpeg")}


def login(c: httpx.Client, phone: str) -> tuple[dict, str]:
    code = c.post("/auth/otp/request", json={"phone": phone}).json()["debug_code"]
    token = c.post("/auth/otp/verify", json={"phone": phone, "code": code}).json()["access_token"]
    h = {"Authorization": f"Bearer {token}"}
    return h, c.get("/me", headers=h).json()["id"]


def step(overview: dict, name: str) -> dict:
    return next(s for s in overview["steps"] if s["step"] == name)


run(make_moderator())
OK = {"consent": True}
V = "/me/verification"
A = "/admin/verifications"

with httpx.Client(base_url=BASE, timeout=30) as c:
    mod, mod_id = login(c, MODERATOR_PHONE)
    me, me_id = login(c, "+998901234971")
    other, other_id = login(c, "+998901234972")

    # --- boshlang'ich holat ---------------------------------------------------
    o = c.get(V, headers=me).json()
    check("to'rt bosqich, vaznlar yig'indisi 100",
          len(o["steps"]) == 4 and sum(s["weight"] for s in o["steps"]) == 100)
    check("telefon tasdiqlangan", step(o, "phone")["state"] == "done" and o["trust_score"] == 20)
    check("kerakli suratlar aytiladi", step(o, "passport")["required"] == ["front"]
          and step(o, "passport")["optional"] == ["back"])
    check("mehmonga yopiq", c.get(V).status_code == 401)

    # --- hujjatsiz va roziliksiz ----------------------------------------------
    r = c.post(f"{V}/passport", headers=me)
    check("eski ilova (tanasiz, hujjatsiz) 409 oladi", r.status_code == 409, r.text)
    check("holat o'zgarmadi", step(c.get(V, headers=me).json(), "passport")["state"] == "todo")
    check("telefon bosqichi qo'lda topshirilmaydi",
          c.post(f"{V}/phone", headers=me, json=OK).status_code == 409)
    check("noma'lum bosqich 404", c.post(f"{V}/bank", headers=me, json=OK).status_code == 404)
    check("noma'lum tur 404",
          c.put(f"{V}/passport/documents/selfie", headers=me, files=photo()).status_code == 404)
    check("rasm bo'lmagan fayl rad etiladi",
          c.put(f"{V}/passport/documents/front", headers=me,
                files={"file": ("x.jpg", b"<script>", "image/jpeg")}).status_code == 400)
    check("mehmon yuklay olmaydi",
          c.put(f"{V}/passport/documents/front", files=photo()).status_code == 401)

    r = c.put(f"{V}/passport/documents/front", headers=me, files=photo())
    check("surat yuklandi", r.status_code == 200 and step(r.json(), "passport")["uploaded"] == ["front"], r.text[:200])
    c.put(f"{V}/passport/documents/front", headers=me, files=photo("green"))
    rows = run(stored(me_id))
    check("almashtirish ikkinchi nusxa qoldirmaydi", len(rows) == 1)
    check("bazada shifrlangan (JPEG emas)", b"\xff\xd8\xff" != rows[0][12:15] and b"JFIF" not in rows[0])
    check("roziliksiz topshirilmaydi", c.post(f"{V}/passport", headers=me).status_code == 422
          and c.post(f"{V}/passport", headers=me, json={"consent": False}).status_code == 422)
    c.put(f"{V}/video/documents/selfie", headers=me, files=photo())
    check("selfi pasportdan oldin topshirilmaydi",
          c.post(f"{V}/video", headers=me, json=OK).status_code == 409)

    r = c.post(f"{V}/passport", headers=me, json=OK)
    check("topshirildi", r.status_code == 200 and step(r.json(), "passport")["state"] == "pending", r.text[:200])
    check("ball hali o'zgarmadi", r.json()["trust_score"] == 20)
    check("ko'rib chiqilayotganda almashtirilmaydi",
          c.put(f"{V}/passport/documents/front", headers=me, files=photo()).status_code == 409)
    check("ikkinchi marta topshirilmaydi",
          c.post(f"{V}/passport", headers=me, json=OK).status_code == 409)
    check("selfi endi topshiriladi", c.post(f"{V}/video", headers=me, json=OK).status_code == 200)

    # --- moderator navbati ----------------------------------------------------
    check("navbat mehmonga 401", c.get(A).status_code == 401)
    check("navbat oddiy odamga 404", c.get(A, headers=other).status_code == 404)
    queue = c.get(A, headers=mod).json()
    mine = {q["step"]: q for q in queue if q["user_id"] == me_id}
    check("arizalar navbatda", set(mine) == {"passport", "video"}, str(list(mine)))
    pid, vid = mine["passport"]["id"], mine["video"]["id"]
    check("hujjat turi ko'rinadi", mine["passport"]["documents"] == ["front"])

    doc = f"{A}/{pid}/documents/front"
    check("hujjat oddiy odamga va egasiga ham 404",
          c.get(doc, headers=other).status_code == 404 and c.get(doc, headers=me).status_code == 404)
    r = c.get(doc, headers=mod)
    check("moderator suratni ko'radi", r.status_code == 200 and r.headers["content-type"] == "image/jpeg")
    check("surat keshlanmaydi", "no-store" in r.headers["cache-control"])
    check("EXIF olib tashlangan", b"maxfiy-joylashuv" not in r.content)
    check("yo'q hujjat 404", c.get(f"{A}/{pid}/documents/back", headers=mod).status_code == 404)

    check("oddiy odam tasdiqlay olmaydi", c.post(f"{A}/{pid}/approve", headers=me).status_code == 404)
    check("selfi pasportdan oldin tasdiqlanmaydi",
          c.post(f"{A}/{vid}/approve", headers=mod).status_code == 409)

    # --- rad etish ------------------------------------------------------------
    check("sababsiz rad etilmaydi",
          c.post(f"{A}/{pid}/reject", headers=mod, json={"reason": "   "}).status_code == 422)
    r = c.post(f"{A}/{pid}/reject", headers=mod, json={"reason": "Surat xira"})
    check("rad etildi", r.status_code == 204, r.text)
    s = step(c.get(V, headers=me).json(), "passport")
    check("sabab foydalanuvchiga ko'rinadi, qayta topshirish ochiq",
          s["state"] == "todo" and s["reject_reason"] == "Surat xira" and s["uploaded"] == [])
    check("rad etilgan hujjat ochilmaydi", c.get(doc, headers=mod).status_code == 404)
    check("faqat selfi surati qoldi", len(run(stored(me_id))) == 1)
    n = c.get("/notifications", headers=me).json()
    check("bildirishnoma keldi", any(x["target_type"] == "verification" and "Surat xira" in x["body"] for x in n))

    # --- qayta topshirish va tasdiqlash ---------------------------------------
    c.put(f"{V}/passport/documents/front", headers=me, files=photo())
    c.put(f"{V}/passport/documents/back", headers=me, files=photo())
    r = c.post(f"{V}/passport", headers=me, json=OK)
    check("qayta topshirildi, sabab tozalandi", step(r.json(), "passport")["reject_reason"] is None)
    check("pasport tasdiqlandi", c.post(f"{A}/{pid}/approve", headers=mod).status_code == 204)
    o = c.get(V, headers=me).json()
    check("ball 55, hali Tasdiqlangan emas", o["trust_score"] == 55
          and c.get(f"/users/{me_id}").json()["is_verified"] is False, str(o["trust_score"]))
    check("ikki marta tasdiqlanmaydi", c.post(f"{A}/{pid}/approve", headers=mod).status_code == 409)
    check("selfi tasdiqlandi", c.post(f"{A}/{vid}/approve", headers=mod).status_code == 204)
    o = c.get(V, headers=me).json()
    check("ball 85, Tasdiqlangan", o["trust_score"] == 85
          and c.get(f"/users/{me_id}").json()["is_verified"] is True, str(o["trust_score"]))
    check("suratlar qolmadi", run(stored(me_id)) == [])
    check("tasdiqlangan bosqich ochilmaydi", c.delete(f"{V}/passport", headers=me).status_code == 409
          and c.put(f"{V}/passport/documents/front", headers=me, files=photo()).status_code == 409)

    # --- o'z arizasi, fikridan qaytish, tozalash, hisobni o'chirish -----------
    c.put(f"{V}/business/documents/certificate", headers=mod, files=photo())
    c.post(f"{V}/business", headers=mod, json=OK)
    own = next(q for q in c.get(A, headers=mod).json() if q["user_id"] == mod_id)
    check("moderator o'zini tasdiqlamaydi", own["is_me"]
          and c.post(f"{A}/{own['id']}/approve", headers=mod).status_code == 409)
    r = c.delete(f"{V}/business", headers=mod)
    check("fikridan qaytish hujjatni o'chiradi", r.status_code == 200 and run(stored(mod_id)) == [])

    c.put(f"{V}/passport/documents/front", headers=other, files=photo())
    run(age_documents(other_id))
    run(auth_prune.main(dry_run=False))
    check("tashlab ketilgan surat tozalanadi", run(stored(other_id)) == [])
    c.put(f"{V}/passport/documents/front", headers=other, files=photo())
    c.post(f"{V}/passport", headers=other, json=OK)
    run(age_documents(other_id))
    run(auth_prune.main(dry_run=False))
    check("ko'rib chiqilayotgani tozalanmaydi", len(run(stored(other_id))) == 1)
    check("hisob o'chdi", c.request("DELETE", "/me", headers=other, json={"confirm": True}).status_code == 204)
    check("hisob bilan hujjat ham ketdi", run(stored(other_id)) == [])
    check("o'chirilgan hisob navbatda yo'q",
          all(q["user_id"] != other_id for q in c.get(A, headers=mod).json()))
    big = {"file": ("x.jpg", b"0" * (13 * 1024 * 1024), "image/jpeg")}
    check("13 MB fayl 413", c.put(f"{V}/business/documents/certificate", headers=mod, files=big).status_code == 413)
