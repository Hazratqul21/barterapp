"""Shaxsni tasdiqlash: hujjatlarni yopiq saqlash va ball hisobi.

Pasport surati `/media` ga tushmaydi: u papka internetga ochiq va nomini bilgan
har kim o'qiy oladi. Suratlar shifrlanib (AES-256-GCM) bazada turadi va ularni
faqat moderator, bitta-bittadan, admin API orqali ko'radi.

Qaror chiqishi bilan suratlar o'chadi. Saqlanadigani — kim, qachon, qanday
qaror qilgani; buning uchun pasportning o'zi kerak emas.
"""

from __future__ import annotations

import os
import uuid
from datetime import timedelta

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.social import VerificationDocument, VerificationState, VerificationStep
from app.models.user import User

#: Har hisob boshlaydigan bosqichlar; vaznlar yig'indisi 100.
#: "Tasdiqlangan" chegarasi 60: pasport + selfi (65) yetadi, telefon + pasport
#: (55) yetmaydi. `video` — tarixiy nom, bugun u selfi surati.
STARTER_STEPS = [
    ("phone", "SMS orqali tasdiqlangan", 20),
    ("passport", "Pasport yoki JSHSHIR", 35),
    ("video", "Hujjat ushlab olingan selfi", 30),
    ("business", "Korxona hujjatlari", 15),
]
VERIFIED_FROM = 60

#: Bosqich → (majburiy, ixtiyoriy) suratlar. Bu yerda yo'q bosqich hujjat bilan
#: topshirilmaydi (telefon SMS orqali tasdiqlanadi).
REQUIRED: dict[str, tuple[str, ...]] = {
    "passport": ("front",),
    "video": ("selfie",),
    "business": ("certificate",),
}
OPTIONAL: dict[str, tuple[str, ...]] = {"passport": ("back",)}

#: Yuklab, topshirilmay tashlab ketilgan suratlar shuncha turadi.
ABANDONED_AFTER = timedelta(days=3)


def kinds(step: str) -> tuple[str, ...]:
    return REQUIRED.get(step, ()) + OPTIONAL.get(step, ())


def _cipher() -> AESGCM:
    key = HKDF(
        algorithm=hashes.SHA256(), length=32, salt=None, info=b"mab/verification/v1"
    ).derive(settings.jwt_secret.encode())
    return AESGCM(key)


def _context(user_id: uuid.UUID, step: str, kind: str) -> bytes:
    # Shifr egasiga bog'langan: bazada qatorlar almashtirib qo'yilsa,
    # birovning pasporti boshqa odamniki bo'lib ochilmaydi.
    return f"{user_id}/{step}/{kind}".encode()


def seal(data: bytes, user_id: uuid.UUID, step: str, kind: str) -> bytes:
    nonce = os.urandom(12)
    return nonce + _cipher().encrypt(nonce, data, _context(user_id, step, kind))


def unseal(document: VerificationDocument) -> bytes | None:
    """Ochilgan surat; kalit almashgan yoki qator buzilgan bo'lsa — None."""
    raw = bytes(document.data)
    try:
        return _cipher().decrypt(
            raw[:12], raw[12:], _context(document.user_id, document.step, document.kind)
        )
    except InvalidTag:
        return None


async def drop_documents(
    db: AsyncSession, user_id: uuid.UUID, step: str | None = None
) -> None:
    query = delete(VerificationDocument).where(VerificationDocument.user_id == user_id)
    if step is not None:
        query = query.where(VerificationDocument.step == step)
    await db.execute(query)


async def recompute(db: AsyncSession, user: User) -> None:
    """Profildagi raqam har doim bosqichlar yig'indisiga teng bo'lsin."""
    await db.flush()
    steps = (
        await db.scalars(select(VerificationStep).where(VerificationStep.user_id == user.id))
    ).all()
    user.trust_score = sum(s.weight for s in steps if s.state == VerificationState.done)
    user.is_verified = user.trust_score >= VERIFIED_FROM
