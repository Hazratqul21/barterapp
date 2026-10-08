"""Saqlanganlar 50 tadan ko'p bo'lsa ham hammasi ochiladi.

Avval `/favorites` 50 ta bilan to'xtardi va qolganiga yo'l yo'q edi.
Endi kursor: har sahifa takrorsiz, tartib buzilmaydi, oxirida `next_cursor`
null. Bir xil vaqtda saqlanganlar ham (id bo'yicha) yo'qolmaydi.
"""

import asyncio
import sys
import uuid
from datetime import UTC, datetime, timedelta
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import delete, select  # noqa: E402
from sqlalchemy.orm import selectinload  # noqa: E402

from app.db.session import SessionLocal  # noqa: E402
from app.models.favorite import Favorite  # noqa: E402
from app.models.listing import Listing, ListingStatus, ListingTranslation  # noqa: E402

BASE = "http://127.0.0.1:8010"
VIEWER = "+998901234961"
TOTAL = 63  # 50 dan ko'p, sahifa hajmiga karrali emas

_loop = asyncio.new_event_loop()
asyncio.set_event_loop(_loop)
run = _loop.run_until_complete


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


async def make_favorites(viewer_id: uuid.UUID) -> tuple[list[uuid.UUID], list[str]]:
    """TOTAL ta e'lon (boshqa savdogarniki) va ularning hammasini saqlash.

    Har uchinchisi oldingisi bilan bir xil vaqtda saqlanadi — kursor faqat
    vaqtga tayansa, shu yerda qator yo'qoladi yoki takrorlanadi.
    """
    async with SessionLocal() as db:
        template = await db.scalar(
            select(Listing)
            .options(selectinload(Listing.translations))
            .where(Listing.status == ListingStatus.active, Listing.owner_id != viewer_id)
            .limit(1)
        )
        base = datetime.now(UTC) - timedelta(days=1)
        made: list[uuid.UUID] = []
        keys: list[tuple[datetime, uuid.UUID, uuid.UUID]] = []
        for i in range(TOTAL):
            listing = Listing(
                owner_id=template.owner_id,
                tag=template.tag,
                value_minor=template.value_minor,
                latitude=template.latitude,
                longitude=template.longitude,
                translations=[
                    ListingTranslation(
                        locale=t.locale,
                        title=f"{t.title} #{i}",
                        description=t.description,
                        image_alt=t.image_alt,
                        category=t.category,
                        condition=t.condition,
                        quantity=t.quantity,
                        wants_summary=t.wants_summary,
                    )
                    for t in template.translations
                ],
            )
            db.add(listing)
            await db.flush()
            saved_at = base + timedelta(seconds=i - (i % 3 == 2))
            fav = Favorite(user_id=viewer_id, listing_id=listing.id, created_at=saved_at)
            db.add(fav)
            await db.flush()
            made.append(listing.id)
            keys.append((saved_at, fav.id, listing.id))
        await db.commit()
        # Kutilgan tartib: saqlangan vaqt, teng bo'lsa favorite id — kamayish.
        expected = [str(k[2]) for k in sorted(keys, reverse=True)]
        return made, expected


async def cleanup(listing_ids: list[uuid.UUID]) -> None:
    async with SessionLocal() as db:
        await db.execute(delete(Listing).where(Listing.id.in_(listing_ids)))
        await db.commit()


with httpx.Client(base_url=BASE, timeout=30) as c:
    tok, me_id = login(c, VIEWER)
    h = {"Authorization": f"Bearer {tok}"}
    made, expected = run(make_favorites(uuid.UUID(me_id)))
    try:

        for limit in (20, 50):
            seen: list[str] = []
            cursor = None
            pages = 0
            while True:
                params = {"limit": limit}
                if cursor:
                    params["cursor"] = cursor
                r = c.get("/favorites", headers=h, params=params)
                check(f"limit={limit}: sahifa {pages + 1} 200", r.status_code == 200,
                      "" if r.status_code == 200 else r.text[:200])
                body = r.json()
                seen += [i["id"] for i in body["items"]]
                pages += 1
                cursor = body["next_cursor"]
                if cursor is None or pages > 10:
                    break
            mine = [x for x in seen if x in set(expected)]
            check(f"limit={limit}: {TOTAL} tasi ham keldi", len(set(mine)) == TOTAL, str(len(set(mine))))
            check(f"limit={limit}: takror yo'q", len(seen) == len(set(seen)))
            check(f"limit={limit}: yangi saqlangan birinchi", mine == expected)
            check(
                f"limit={limit}: oxirgi sahifada next_cursor null",
                cursor is None and pages == -(-len(seen) // limit),
                f"{pages} sahifa",
            )

        first = c.get("/favorites", headers=h, params={"limit": 50}).json()
        check("birinchi sahifa to'la va kursor bor",
              len(first["items"]) == 50 and first["next_cursor"])

        r = c.get("/favorites", headers=h, params={"cursor": "yaroqsiz!!"})
        check("yaroqsiz kursor 400", r.status_code == 400, str(r.status_code))

        r = c.get("/favorites", headers=h, params={"limit": 51})
        check("limit 50 dan oshmaydi", r.status_code == 422, str(r.status_code))
    finally:
        run(cleanup(made))
