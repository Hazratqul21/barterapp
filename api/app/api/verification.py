"""Shaxsni tasdiqlash: foydalanuvchi hujjat topshiradi."""

from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile, status
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.concurrency import run_in_threadpool

from app.api.uploads import MAX_UPLOAD_BYTES, _process
from app.core.ratelimit import source, uploads as upload_limit
from app.core.security import current_user
from app.db.session import get_db
from app.models.social import VerificationDocument, VerificationState, VerificationStep
from app.models.user import User
from app.schemas.common import ApiModel
from app.schemas.trade import VerificationOut, VerificationStepOut
from app.services import verification

router = APIRouter(prefix="/me/verification", tags=["verification"])


class SubmitIn(ApiModel):
    #: Shaxsiy hujjatni ko'rib chiqishga rozilik. Ekranda belgilanadi.
    consent: bool = False


async def _overview(db: AsyncSession, me: User) -> VerificationOut:
    steps = (
        await db.scalars(
            select(VerificationStep)
            .where(VerificationStep.user_id == me.id)
            .order_by(VerificationStep.weight.desc())
        )
    ).all()
    uploaded: dict[str, list[str]] = {}
    for step, kind in await db.execute(
        select(VerificationDocument.step, VerificationDocument.kind).where(
            VerificationDocument.user_id == me.id
        )
    ):
        uploaded.setdefault(step, []).append(kind)
    return VerificationOut(
        trust_score=me.trust_score,
        steps=[
            VerificationStepOut(
                step=s.step,
                state=s.state,
                hint=s.hint,
                weight=s.weight,
                required=list(verification.REQUIRED.get(s.step, ())),
                optional=list(verification.OPTIONAL.get(s.step, ())),
                uploaded=sorted(uploaded.get(s.step, [])),
                reject_reason=s.reject_reason,
                submitted_at=s.submitted_at,
            )
            for s in steps
        ],
    )


async def _open_step(db: AsyncSession, me: User, step: str) -> VerificationStep:
    """Hali topshirilmagan bosqich; qator qulflanadi."""
    row = await db.scalar(
        select(VerificationStep)
        .where(VerificationStep.user_id == me.id, VerificationStep.step == step)
        .with_for_update()
    )
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Bunday bosqich yo‘q.")
    if row.state == VerificationState.done:
        raise HTTPException(status.HTTP_409_CONFLICT, "Bu bosqich allaqachon tasdiqlangan.")
    if row.state == VerificationState.pending:
        raise HTTPException(
            status.HTTP_409_CONFLICT, "Hujjatlaringiz ko‘rib chiqilmoqda."
        )
    if step not in verification.REQUIRED:
        raise HTTPException(
            status.HTTP_409_CONFLICT, "Bu bosqich hujjat bilan tasdiqlanmaydi."
        )
    return row


@router.get("", response_model=VerificationOut)
async def read_verification(
    me: User = Depends(current_user), db: AsyncSession = Depends(get_db)
) -> VerificationOut:
    return await _overview(db, me)


@router.put("/{step}/documents/{kind}", response_model=VerificationOut)
async def upload_document(
    step: str,
    kind: str,
    request: Request,
    file: UploadFile = File(...),
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> VerificationOut:
    """Surat qo'yadi yoki borini almashtiradi. Topshirilgach almashtirilmaydi."""
    upload_limit.check(source(request, me))
    if kind not in verification.kinds(step):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Bunday hujjat turi yo‘q.")

    raw = await file.read(MAX_UPLOAD_BYTES + 1)
    if not raw:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Fayl bo‘sh.")
    if len(raw) > MAX_UPLOAD_BYTES:
        raise HTTPException(
            status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            "Rasm juda katta. 12 MB dan kichik rasm yuklang.",
        )
    # Xuddi oddiy surat kabi: rasm ekani tekshiriladi, EXIF (GPS) olib tashlanadi.
    processed, _, _ = await run_in_threadpool(_process, raw)

    await _open_step(db, me, step)
    sealed = verification.seal(processed, me.id, step, kind)
    now = datetime.now(UTC)
    await db.execute(
        insert(VerificationDocument)
        .values(user_id=me.id, step=step, kind=kind, data=sealed, created_at=now)
        .on_conflict_do_update(
            constraint="uq_verification_document", set_={"data": sealed, "created_at": now}
        )
    )
    await db.commit()
    return await _overview(db, me)


@router.post("/{step}", response_model=VerificationOut)
async def submit_step(
    step: str,
    payload: SubmitIn | None = None,
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> VerificationOut:
    """Yuklangan hujjatlarni ko'rib chiqishga topshiradi."""
    row = await _open_step(db, me, step)

    have = set(
        (
            await db.scalars(
                select(VerificationDocument.kind).where(
                    VerificationDocument.user_id == me.id,
                    VerificationDocument.step == step,
                )
            )
        ).all()
    )
    if not set(verification.REQUIRED[step]) <= have:
        # Ilovaning eski versiyalari shu yerga hujjatsiz keladi: matn ularning
        # ekranida chiqadi.
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "Avval hujjat suratini yuklang. Yuklash joyi bo‘lmasa, ilovani yangilang.",
        )
    if payload is None or not payload.consent:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            "Shaxsiy hujjatni ko‘rib chiqishga rozilik bering.",
        )
    if step == "video":
        # Selfi yolg'iz hech narsani isbotlamaydi: uni solishtirish uchun hujjat kerak.
        passport = await db.scalar(
            select(VerificationStep.state).where(
                VerificationStep.user_id == me.id, VerificationStep.step == "passport"
            )
        )
        if passport not in (VerificationState.pending, VerificationState.done):
            raise HTTPException(
                status.HTTP_409_CONFLICT, "Avval pasport yoki ID kartani topshiring."
            )

    now = datetime.now(UTC)
    row.state = VerificationState.pending
    row.reject_reason = None
    row.submitted_at = now
    row.consented_at = now
    row.reviewed_at = None
    row.reviewed_by = None
    await db.commit()
    return await _overview(db, me)


@router.delete("/{step}", response_model=VerificationOut)
async def withdraw_step(
    step: str,
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> VerificationOut:
    """Fikridan qaytish: hujjatlar shu zahoti o'chadi."""
    row = await db.scalar(
        select(VerificationStep)
        .where(VerificationStep.user_id == me.id, VerificationStep.step == step)
        .with_for_update()
    )
    if row is None or step not in verification.REQUIRED:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Bunday bosqich yo‘q.")
    if row.state == VerificationState.done:
        raise HTTPException(status.HTTP_409_CONFLICT, "Bu bosqich allaqachon tasdiqlangan.")
    row.state = VerificationState.todo
    row.submitted_at = None
    row.consented_at = None
    await verification.drop_documents(db, me.id, step)
    await db.commit()
    return await _overview(db, me)
