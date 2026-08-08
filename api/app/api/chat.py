from __future__ import annotations

import asyncio
import uuid
from collections import defaultdict
from datetime import UTC, datetime

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    WebSocket,
    WebSocketDisconnect,
    status,
)
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.locale import resolve_locale
from app.core.security import current_user, decode_token
from app.db.session import SessionLocal, get_db
from app.models.offer import Conversation, Message, Offer
from app.models.social import NotifyKind, NotifyTargetType
from app.models.user import User
from app.schemas.common import Money
from app.schemas.trade import (
    ConversationDetail,
    ConversationSummary,
    MessageCreate,
    MessageOut,
)
from app.services import offers as offer_service
from app.services import stats
from app.services.presenter import trader_brief

router = APIRouter(tags=["chat"])


class Hub:
    """
    In-process fan-out for live messages and typing.

    Deliberately not Redis yet: with one API process this is correct and has no
    moving parts. The moment a second process exists, swap the internals here —
    nothing outside this class knows how delivery works.
    """

    def __init__(self) -> None:
        self._sockets: dict[uuid.UUID, set[WebSocket]] = defaultdict(set)
        self._lock = asyncio.Lock()

    async def join(self, user_id: uuid.UUID, socket: WebSocket) -> None:
        async with self._lock:
            self._sockets[user_id].add(socket)

    async def leave(self, user_id: uuid.UUID, socket: WebSocket) -> None:
        async with self._lock:
            self._sockets[user_id].discard(socket)
            if not self._sockets[user_id]:
                self._sockets.pop(user_id, None)

    async def send(self, user_id: uuid.UUID, payload: dict) -> None:
        for socket in list(self._sockets.get(user_id, ())):
            try:
                await socket.send_json(payload)
            except Exception:
                # A dead socket is not an error worth failing the request over.
                await self.leave(user_id, socket)


hub = Hub()


async def _peer_id(thread: Conversation, me_id: uuid.UUID) -> uuid.UUID:
    return thread.user_b_id if thread.user_a_id == me_id else thread.user_a_id


async def _summary(
    db: AsyncSession, thread: Conversation, me: User, locale: str
) -> ConversationSummary:
    offer = await offer_service.load_offer(db, thread.offer_id)
    out = await offer_service.present(db, offer, me.id, locale)

    last = await db.scalar(
        select(Message)
        .where(Message.conversation_id == thread.id)
        .order_by(Message.created_at.desc())
        .limit(1)
    )
    unread = (
        await db.scalar(
            select(func.count(Message.id)).where(
                Message.conversation_id == thread.id,
                Message.sender_id != me.id,
                Message.read_at.is_(None),
            )
        )
        or 0
    )

    return ConversationSummary(
        id=thread.id,
        peer=out.counterparty,
        offer_id=offer.id,
        offer_status=offer.status,
        deal_summary=offer_service.deal_summary(out),
        gives=offer_service.sides(out)[0],
        receives=offer_service.sides(out)[1],
        cash=Money(minor=offer.cash_delta_minor, currency=offer.currency),
        last_message=last.body if last else None,
        last_message_at=last.created_at if last else None,
        unread=unread,
    )


@router.get("/conversations", response_model=list[ConversationSummary])
async def list_conversations(
    locale: str = Depends(resolve_locale),
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> list[ConversationSummary]:
    threads = (
        await db.scalars(
            select(Conversation)
            .where(
                (Conversation.user_a_id == me.id) | (Conversation.user_b_id == me.id)
            )
            .order_by(Conversation.last_message_at.desc().nullslast())
        )
    ).all()
    return [await _summary(db, thread, me, locale) for thread in threads]


@router.get("/conversations/{thread_id}", response_model=ConversationDetail)
async def read_conversation(
    thread_id: uuid.UUID,
    locale: str = Depends(resolve_locale),
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> ConversationDetail:
    thread = await db.get(Conversation, thread_id)
    if thread is None or me.id not in (thread.user_a_id, thread.user_b_id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Suhbat topilmadi.")

    # Opening a thread reads it. The inbox badge and this screen therefore agree
    # the moment the user goes back.
    await db.execute(
        update(Message)
        .where(
            Message.conversation_id == thread.id,
            Message.sender_id != me.id,
            Message.read_at.is_(None),
        )
        .values(read_at=datetime.now(UTC))
    )
    await db.commit()

    summary = await _summary(db, thread, me, locale)
    offer = await offer_service.load_offer(db, thread.offer_id)

    rows = (
        await db.scalars(
            select(Message)
            .where(Message.conversation_id == thread.id)
            .order_by(Message.created_at.asc())
        )
    ).all()

    return ConversationDetail(
        **summary.model_dump(),
        offer=await offer_service.present(db, offer, me.id, locale),
        messages=[
            MessageOut(
                id=m.id,
                body=m.body,
                photo_url=m.photo_url,
                created_at=m.created_at,
                sender_id=m.sender_id,
                is_mine=m.sender_id == me.id,
            )
            for m in rows
        ],
    )


@router.post(
    "/conversations/{thread_id}/messages",
    response_model=MessageOut,
    status_code=status.HTTP_201_CREATED,
)
async def send_message(
    thread_id: uuid.UUID,
    payload: MessageCreate,
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> MessageOut:
    thread = await db.get(Conversation, thread_id)
    if thread is None or me.id not in (thread.user_a_id, thread.user_b_id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Suhbat topilmadi.")

    now = datetime.now(UTC)
    message = Message(
        conversation_id=thread.id,
        sender_id=me.id,
        body=payload.body,
        photo_url=payload.photo_url,
        created_at=now,
    )
    db.add(message)
    thread.last_message_at = now

    peer = await _peer_id(thread, me.id)
    await offer_service.notify(
        db,
        user_id=peer,
        kind=NotifyKind.message,
        title=f"{me.full_name} yozdi",
        body=payload.body[:120],
        target_type=NotifyTargetType.chat,
        target_id=thread.id,
        avatar_url=me.avatar_url,
    )
    await db.commit()

    out = MessageOut(
        id=message.id,
        body=message.body,
        photo_url=message.photo_url,
        created_at=message.created_at,
        sender_id=me.id,
        is_mine=True,
    )
    # The recipient sees `is_mine: false` for the same message.
    await hub.send(
        peer,
        {
            "type": "message",
            "conversation_id": str(thread.id),
            "message": {**out.model_dump(mode="json"), "is_mine": False},
        },
    )
    return out


@router.websocket("/ws")
async def live(websocket: WebSocket, token: str = "") -> None:
    """
    Live channel for the three things that must not wait for a refresh:
    new messages, typing, and offer status changes.

    The token arrives as a query parameter because browsers cannot set headers
    on a WebSocket handshake.
    """
    try:
        user_id = decode_token(token, "access")
    except HTTPException:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    async with SessionLocal() as db:
        user = await db.scalar(select(User).where(User.id == user_id))
        if user is None:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return

    await websocket.accept()
    await hub.join(user_id, websocket)

    try:
        while True:
            event = await websocket.receive_json()
            if event.get("type") != "typing":
                continue

            thread_id = event.get("conversation_id")
            if not thread_id:
                continue

            async with SessionLocal() as db:
                thread = await db.get(Conversation, uuid.UUID(thread_id))
                if thread is None or user_id not in (
                    thread.user_a_id,
                    thread.user_b_id,
                ):
                    continue
                peer = await _peer_id(thread, user_id)

            await hub.send(
                peer,
                {
                    "type": "typing",
                    "conversation_id": thread_id,
                    "user_id": str(user_id),
                },
            )
    except WebSocketDisconnect:
        pass
    finally:
        await hub.leave(user_id, websocket)


@router.get("/conversations/{thread_id}/peer", response_model=dict)
async def peer_presence(
    thread_id: uuid.UUID,
    me: User = Depends(current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    thread = await db.get(Conversation, thread_id)
    if thread is None or me.id not in (thread.user_a_id, thread.user_b_id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Suhbat topilmadi.")

    peer_id = await _peer_id(thread, me.id)
    peer = await db.get(User, peer_id)
    ratings = await stats.rating_and_reviews(db, [peer_id])
    deals = await stats.completed_deals(db, [peer_id])
    return trader_brief(
        peer, rating=ratings.get(peer_id, (None, 0))[0], deals=deals.get(peer_id, 0)
    ).model_dump(mode="json")
