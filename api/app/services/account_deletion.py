"""Hisobni o'chirish.

Do'konlar buni talab qiladi (Apple 5.1.1(v), Google Play), lekin talab
"foydalanuvchi qatorini o'chir" degani emas — u "shaxsiy ma'lumotni olib
tashla va hisobga kirishni to'xtat" degani.

**Nega qator o'chirilmaydi.** `users.id` ga o'nlab jadval `ON DELETE CASCADE`
bilan bog'langan. Qator o'chirilsa ular bilan birga quyidagilar ham ketadi:

- yakunlangan savdolar — **ikkala tomonning** tarixi;
- suhbatlar va xabarlar — qarshi tomon o'z yozishmasini yo'qotadi;
- bu odam yozgan sharhlar — boshqa savdogarlarning reytingi pasayadi;
- u haqidagi sharhlar — yozganlarning mehnati yo'qoladi.

Ularning yarmi boshqa odamga tegishli. Mening hisobimni o'chirganim birovning
savdo tarixini va reytingini o'chirishi mumkin emas.

Shuning uchun: qator qoladi, ichi tozalanadi. Tashqaridan bu odam butunlay
yo'qolgandek ko'rinadi — nomi ham, surati ham, telefoni ham yo'q, kirish ham
mumkin emas — lekin u qatnashgan savdolar joyida qoladi.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from sqlalchemy import delete, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.device import Device
from app.models.favorite import Favorite
from app.models.listing import Listing, ListingStatus
from app.models.moderation import Block
from app.models.notify_pref import NotificationSetting
from app.models.offer import Offer, OfferStatus
from app.models.user import RefreshToken, User

#: Bekor qilinishi kerak bo'lgan savdo holatlari. Yakunlanganiga tegilmaydi —
#: u tarix, ochig'i esa qarshi tomonni javob kutib qoldirmasligi kerak.
_LIVE = (OfferStatus.pending, OfferStatus.talking, OfferStatus.accepted)


#: `users.phone` ustuni `String(20)`. To'liq UUID (36 belgi) sig'maydi —
#: birinchi urinishda aynan shu 500 bergan edi. Hex'ning 16 belgisi 64 bitni
#: tashiydi, ya'ni to'qnashuv amalda bo'lmaydi; bo'lsa ham unique cheklov uni
#: jimgina buzilish emas, ochiq xato qilib ko'rsatadi.
_DELETED_PREFIX = "del:"


def freed_phone(user_id: uuid.UUID) -> str:
    """
    O'chirilgan hisobning telefoni o'rniga qo'yiladigan qiymat.

    `phone` ustuni unique. Eski raqam qolsa, o'sha odam fikridan qaytib qayta
    ro'yxatdan o'tmoqchi bo'lganda — yoki raqam boshqa odamga o'tganda —
    kirish umuman imkonsiz bo'lardi. Raqam bo'shatiladi, o'rniga hech qachon
    haqiqiy raqamga o'xshamaydigan noyob qiymat qoladi.
    """
    return f"{_DELETED_PREFIX}{user_id.hex[:16]}"


async def delete_account(db: AsyncSession, user: User) -> None:
    """
    Shaxsiy ma'lumotni tozalaydi, kirishni to'xtatadi, izini qoldiradi.

    Commit qilmaydi — chaqiruvchi qiladi, chunki bularning hammasi bitta
    tranzaksiyada bo'lishi shart. Yarim o'chirilgan hisob — telefoni
    bo'shatilgan, lekin e'lonlari lentada turgan holat — eng yomon natija.
    """
    now = datetime.now(UTC)

    # --- 1. Shaxsiy ma'lumot ------------------------------------------------

    user.deleted_at = now
    user.phone = freed_phone(user.id)
    user.first_name = ""
    user.last_name = ""
    user.handle = None
    user.tax_id = None
    user.avatar_url = None
    user.cover_url = None
    user.bio = None
    user.region = None
    user.district = None
    user.address = None
    user.latitude = None
    user.longitude = None
    user.last_seen_at = None
    # Huquq ham olinadi: o'chirilgan hisob moderator bo'lib qolmasin.
    user.is_moderator = False
    user.is_verified = False

    # --- 2. Kirishni to'xtatish ---------------------------------------------

    # Har bir ochiq sessiya bekor qilinadi. Aks holda boshqa qurilmadagi
    # access token o'z muddatigacha ishlayverardi — ya'ni o'chirilgan hisob
    # bir soat davomida hali ham tirik bo'lardi.
    await db.execute(
        update(RefreshToken)
        .where(RefreshToken.user_id == user.id, RefreshToken.revoked_at.is_(None))
        .values(revoked_at=now)
    )

    # --- 3. Bozordan chiqarish ----------------------------------------------

    # Faol e'lonlar arxivlanadi. O'chirilmaydi: ular yakunlangan savdoning
    # bir qismi bo'lishi mumkin va o'sha savdo qarshi tomonning tarixida
    # ko'rinib turishi kerak.
    await db.execute(
        update(Listing)
        .where(
            Listing.owner_id == user.id,
            Listing.status.in_(
                (ListingStatus.draft, ListingStatus.active, ListingStatus.in_negotiation)
            ),
        )
        .values(status=ListingStatus.archived)
    )

    # Ochiq takliflar bekor qilinadi — qarshi tomon hech qachon kelmaydigan
    # javobni kutib qolmasin.
    await db.execute(
        update(Offer)
        .where(
            Offer.status.in_(_LIVE),
            (Offer.from_user_id == user.id) | (Offer.to_user_id == user.id),
        )
        .values(status=OfferStatus.expired)
    )

    # --- 4. Faqat shu odamga tegishli narsalar -------------------------------

    # Bular boshqa hech kimga ko'rinmaydi va hech kimning tarixi emas,
    # shuning uchun butunlay o'chiriladi.
    await db.execute(delete(Device).where(Device.user_id == user.id))
    await db.execute(delete(Favorite).where(Favorite.user_id == user.id))
    await db.execute(
        delete(NotificationSetting).where(NotificationSetting.user_id == user.id)
    )
    # O'zi qo'ygan bloklar ham. Uni bloklaganlarniki qoladi: bu boshqa
    # odamning qarori va uni bekor qilish bu yerdan mumkin emas.
    await db.execute(delete(Block).where(Block.blocker_id == user.id))


async def is_deleted(db: AsyncSession, user_id: uuid.UUID) -> bool:
    """Tokenni tekshirishda ishlatiladi."""
    row = await db.scalar(select(User.deleted_at).where(User.id == user_id))
    return row is not None
