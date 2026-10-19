"""Payme Merchant API — Payme serveri bizga shu manzilga murojaat qiladi.

    POST https://api.mab.uz/payments/payme

JSON-RPC 2.0. HTTP holati har doim 200; xato `error` maydonida qaytadi.
Avtorizatsiya: `Authorization: Basic base64("Paycom:<kassa kaliti>")`.

Hujjat: https://developer.help.paycom.uz/protokol-merchant-api/

Bu yerda karta ma'lumoti umuman yo'q: karta raqami, muddati va SMS kod
Payme sahifasida kiritiladi. Biz faqat "shu buyurtma uchun shuncha pul
to'lanishi mumkinmi" degan savolga javob beramiz va natijani yozamiz.
"""

from __future__ import annotations

import base64
import hmac
import json
import logging
import time
import uuid
from datetime import UTC, datetime
from typing import Any

from fastapi import APIRouter, Depends, Request
from fastapi.responses import JSONResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.db.session import get_db
from app.models.payment import (
    OrderStatus,
    PaymentOrder,
    PaymeTransaction,
    Product,
)
from app.services import billing

router = APIRouter(prefix="/payments", tags=["payments"])

log = logging.getLogger("barter.payme")

#: Yaratilgan, lekin bajarilmagan tranzaksiya shuncha vaqtdan keyin eskiradi
#: (Payme talabi: 12 soat).
TIMEOUT_MS = 12 * 60 * 60 * 1000

#: Bekor qilish sababi: vaqt tugadi (Payme kodi).
REASON_TIMEOUT = 4

STATE_CREATED = 1
STATE_DONE = 2
STATE_CANCELLED = -1
STATE_CANCELLED_AFTER_DONE = -2


class PaymeError(Exception):
    def __init__(self, code: int, uz: str, ru: str, en: str, data: str | None = None):
        super().__init__(en)
        self.code = code
        self.message = {"uz": uz, "ru": ru, "en": en}
        self.data = data


def _auth_error() -> PaymeError:
    return PaymeError(
        -32504,
        "Ruxsat yo'q.",
        "Недостаточно привилегий для выполнения метода.",
        "Insufficient privileges.",
    )


def _order_not_found() -> PaymeError:
    return PaymeError(
        -31050, "Buyurtma topilmadi.", "Заказ не найден.", "Order not found.", "order_id"
    )


def _order_unavailable() -> PaymeError:
    return PaymeError(
        -31051,
        "Buyurtma to'lab bo'lmaydigan holatda.",
        "Заказ недоступен для оплаты.",
        "Order cannot be paid.",
        "order_id",
    )


def _order_busy() -> PaymeError:
    return PaymeError(
        -31052,
        "Buyurtma uchun boshqa to'lov jarayonda.",
        "По заказу уже идёт другая оплата.",
        "Another payment for this order is in progress.",
        "order_id",
    )


def _wrong_amount() -> PaymeError:
    return PaymeError(-31001, "Noto'g'ri summa.", "Неверная сумма.", "Wrong amount.")


def _tx_not_found() -> PaymeError:
    return PaymeError(
        -31003, "Tranzaksiya topilmadi.", "Транзакция не найдена.", "Transaction not found."
    )


def _cannot_perform() -> PaymeError:
    return PaymeError(
        -31008,
        "Amalni bajarib bo'lmaydi.",
        "Невозможно выполнить операцию.",
        "Unable to perform operation.",
    )


def _cannot_cancel() -> PaymeError:
    return PaymeError(
        -31007,
        "Buyurtma bajarilgan, bekor qilib bo'lmaydi.",
        "Заказ выполнен. Невозможно отменить транзакцию.",
        "Order completed, the transaction cannot be cancelled.",
    )


def _bad_request(detail: str = "Invalid request") -> PaymeError:
    return PaymeError(-32600, "Noto'g'ri so'rov.", "Неверный запрос.", detail)


def _now_ms() -> int:
    return int(time.time() * 1000)


def _authorized(request: Request) -> bool:
    if not settings.payme_enabled:
        return False
    header = request.headers.get("authorization", "")
    if not header.startswith("Basic "):
        return False
    try:
        decoded = base64.b64decode(header[6:]).decode()
    except (ValueError, UnicodeDecodeError):
        return False
    login, _, password = decoded.partition(":")
    # Login har doim "Paycom"; kalit — kassa kaliti. Vaqt bo'yicha teng
    # taqqoslash: kalitni harfma-harf taxmin qilib bo'lmasin.
    return login == "Paycom" and hmac.compare_digest(password, settings.payme_key)


def _order_id(params: dict) -> uuid.UUID | None:
    account = params.get("account")
    if not isinstance(account, dict):
        return None
    try:
        return uuid.UUID(str(account.get("order_id", "")))
    except ValueError:
        return None


def _amount(params: dict) -> int:
    amount = params.get("amount")
    if not isinstance(amount, int) or isinstance(amount, bool) or amount <= 0:
        raise _wrong_amount()
    return amount


async def _order_for(db: AsyncSession, params: dict) -> PaymentOrder:
    order_id = _order_id(params)
    if order_id is None:
        raise _order_not_found()
    order = await db.get(PaymentOrder, order_id, with_for_update=True)
    if order is None:
        raise _order_not_found()
    return order


async def _transaction(db: AsyncSession, params: dict) -> PaymeTransaction:
    payme_id = params.get("id")
    if not isinstance(payme_id, str) or not payme_id:
        raise _tx_not_found()
    tx = await db.scalar(
        select(PaymeTransaction)
        .where(PaymeTransaction.payme_id == payme_id)
        .with_for_update()
    )
    if tx is None:
        raise _tx_not_found()
    return tx


async def _cancel(
    db: AsyncSession, tx: PaymeTransaction, reason: int | None
) -> None:
    tx.state = STATE_CANCELLED
    tx.cancel_time = _now_ms()
    tx.reason = reason
    order = await db.get(PaymentOrder, tx.order_id, with_for_update=True)
    if order is not None and order.status == OrderStatus.pending:
        order.status = OrderStatus.cancelled
        order.cancelled_at = datetime.now(UTC)


async def _check_order(db: AsyncSession, params: dict) -> PaymentOrder:
    amount = _amount(params)
    order = await _order_for(db, params)
    if order.status != OrderStatus.pending:
        raise _order_unavailable()
    if amount != order.amount_minor:
        raise _wrong_amount()
    return order


def _detail(order: PaymentOrder, product_code_info: dict | None) -> dict | None:
    """Fiskal chek tafsiloti — faqat MXIK kodi kiritilgan bo'lsa."""
    if not product_code_info or not product_code_info.get("mxik_code"):
        return None
    item = {
        "title": order.title,
        "price": order.amount_minor,
        "count": 1,
        "code": product_code_info["mxik_code"],
        "vat_percent": product_code_info.get("vat_percent", 0),
    }
    if product_code_info.get("package_code"):
        item["package_code"] = product_code_info["package_code"]
    return {"receipt_type": 0, "items": [item]}


async def check_perform(db: AsyncSession, params: dict) -> dict:
    order = await _check_order(db, params)
    product = await db.get(Product, order.product_code)
    result: dict[str, Any] = {"allow": True}
    if product is not None:
        detail = _detail(
            order,
            {
                "mxik_code": product.mxik_code,
                "package_code": product.package_code,
                "vat_percent": product.vat_percent,
            },
        )
        if detail:
            result["detail"] = detail
    return result


async def create_transaction(db: AsyncSession, params: dict) -> dict:
    payme_id = params.get("id")
    payme_time = params.get("time")
    if not isinstance(payme_id, str) or not payme_id or not isinstance(payme_time, int):
        raise _bad_request("id and time are required")

    existing = await db.scalar(
        select(PaymeTransaction)
        .where(PaymeTransaction.payme_id == payme_id)
        .with_for_update()
    )
    if existing is not None:
        if existing.state != STATE_CREATED:
            raise _cannot_perform()
        if _now_ms() - existing.create_time > TIMEOUT_MS:
            await _cancel(db, existing, REASON_TIMEOUT)
            await db.commit()
            raise _cannot_perform()
        return {
            "create_time": existing.create_time,
            "transaction": str(existing.id),
            "state": existing.state,
        }

    order = await _check_order(db, params)

    # Bitta buyurtma — bitta faol to'lov. Aks holda ikki oynada ochilgan
    # to'lov sahifasi bitta xarid uchun ikki marta pul yechardi.
    busy = await db.scalar(
        select(PaymeTransaction.id).where(
            PaymeTransaction.order_id == order.id,
            PaymeTransaction.state == STATE_CREATED,
        )
    )
    if busy is not None:
        raise _order_busy()

    tx = PaymeTransaction(
        id=uuid.uuid4(),
        payme_id=payme_id,
        order_id=order.id,
        amount_minor=order.amount_minor,
        state=STATE_CREATED,
        payme_time=payme_time,
        create_time=_now_ms(),
    )
    db.add(tx)
    await db.commit()
    return {"create_time": tx.create_time, "transaction": str(tx.id), "state": tx.state}


async def perform_transaction(db: AsyncSession, params: dict) -> dict:
    tx = await _transaction(db, params)
    if tx.state == STATE_DONE:
        return {"transaction": str(tx.id), "perform_time": tx.perform_time, "state": tx.state}
    if tx.state != STATE_CREATED:
        raise _cannot_perform()
    if _now_ms() - tx.create_time > TIMEOUT_MS:
        await _cancel(db, tx, REASON_TIMEOUT)
        await db.commit()
        raise _cannot_perform()

    order = await db.get(PaymentOrder, tx.order_id, with_for_update=True)
    if order is None or order.status != OrderStatus.pending:
        raise _cannot_perform()

    tx.state = STATE_DONE
    tx.perform_time = _now_ms()
    await billing.fulfil(db, order)
    await db.commit()
    log.info("payme paid order=%s amount=%s", order.id, order.amount_minor)
    return {"transaction": str(tx.id), "perform_time": tx.perform_time, "state": tx.state}


async def cancel_transaction(db: AsyncSession, params: dict) -> dict:
    tx = await _transaction(db, params)
    reason = params.get("reason")
    reason = reason if isinstance(reason, int) and not isinstance(reason, bool) else None

    if tx.state == STATE_CREATED:
        await _cancel(db, tx, reason)
        await db.commit()
    elif tx.state == STATE_DONE:
        # E'lon kvotasi yoki boost allaqachon berilgan va ishlatilgan bo'lishi
        # mumkin. Pulni qaytarish — qo'lda, qo'llab-quvvatlash orqali.
        raise _cannot_cancel()

    return {"transaction": str(tx.id), "cancel_time": tx.cancel_time, "state": tx.state}


async def check_transaction(db: AsyncSession, params: dict) -> dict:
    tx = await _transaction(db, params)
    return {
        "create_time": tx.create_time,
        "perform_time": tx.perform_time,
        "cancel_time": tx.cancel_time,
        "transaction": str(tx.id),
        "state": tx.state,
        "reason": tx.reason,
    }


async def get_statement(db: AsyncSession, params: dict) -> dict:
    start, end = params.get("from"), params.get("to")
    if not isinstance(start, int) or not isinstance(end, int):
        raise _bad_request("from and to are required")
    rows = (
        await db.scalars(
            select(PaymeTransaction)
            .where(
                PaymeTransaction.create_time >= start,
                PaymeTransaction.create_time <= end,
            )
            .order_by(PaymeTransaction.create_time)
        )
    ).all()
    return {
        "transactions": [
            {
                "id": tx.payme_id,
                "time": tx.payme_time,
                "amount": tx.amount_minor,
                "account": {"order_id": str(tx.order_id)},
                "create_time": tx.create_time,
                "perform_time": tx.perform_time,
                "cancel_time": tx.cancel_time,
                "transaction": str(tx.id),
                "state": tx.state,
                "reason": tx.reason,
            }
            for tx in rows
        ]
    }


async def set_fiscal_data(db: AsyncSession, params: dict) -> dict:
    # Payme fiskal chek ma'lumotini yuboradi. Hozircha faqat logga yoziladi.
    log.info("payme fiscal data id=%s", params.get("id"))
    return {"success": True}


METHODS = {
    "CheckPerformTransaction": check_perform,
    "CreateTransaction": create_transaction,
    "PerformTransaction": perform_transaction,
    "CancelTransaction": cancel_transaction,
    "CheckTransaction": check_transaction,
    "GetStatement": get_statement,
    "SetFiscalData": set_fiscal_data,
}


def _error(rpc_id: Any, err: PaymeError) -> JSONResponse:
    body: dict[str, Any] = {"code": err.code, "message": err.message}
    if err.data:
        body["data"] = err.data
    return JSONResponse({"jsonrpc": "2.0", "id": rpc_id, "error": body})


@router.post("/payme", include_in_schema=False)
async def payme_endpoint(request: Request, db: AsyncSession = Depends(get_db)) -> JSONResponse:
    try:
        payload = json.loads(await request.body())
    except (ValueError, UnicodeDecodeError):
        return _error(
            None,
            PaymeError(-32700, "JSON xato.", "Ошибка парсинга JSON.", "Parse error."),
        )
    if not isinstance(payload, dict):
        return _error(None, _bad_request())
    rpc_id = payload.get("id")

    if not _authorized(request):
        return _error(rpc_id, _auth_error())

    method = METHODS.get(payload.get("method"))
    if method is None:
        return _error(
            rpc_id,
            PaymeError(-32601, "Metod topilmadi.", "Метод не найден.", "Method not found."),
        )
    params = payload.get("params")
    if not isinstance(params, dict):
        return _error(rpc_id, _bad_request("params must be an object"))

    try:
        result = await method(db, params)
    except PaymeError as err:
        await db.rollback()
        return _error(rpc_id, err)
    return JSONResponse({"jsonrpc": "2.0", "id": rpc_id, "result": result})
