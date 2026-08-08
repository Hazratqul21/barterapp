from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import Field

from app.models.offer import OfferStatus
from app.models.social import NotifyKind, NotifyTargetType, VerificationState
from app.schemas.common import ApiModel, Money
from app.schemas.listing import ListingCard
from app.schemas.user import TraderBrief


class OfferCreate(ApiModel):
    listing_id: uuid.UUID
    #: Listings the sender puts on their own side of the trade.
    offered_listing_ids: list[uuid.UUID] = Field(min_length=1, max_length=5)
    #: Positive tops up the sender's side; 0 means a straight swap.
    cash_delta_minor: int = 0
    currency: str = Field(default="UZS", min_length=3, max_length=3)
    message: str | None = Field(default=None, max_length=1000)


class OfferAction(ApiModel):
    """One verb per request; the server owns which transitions are legal."""

    action: str = Field(pattern="^(accept|decline|counter|complete|dispute)$")
    cash_delta_minor: int | None = None
    message: str | None = Field(default=None, max_length=1000)


class OfferOut(ApiModel):
    id: uuid.UUID
    status: OfferStatus
    cash_delta_minor: int
    currency: str
    created_at: datetime
    expires_at: datetime | None = None
    #: True when the signed-in user sent it, so the UI knows which side to show.
    is_mine: bool
    counterparty: TraderBrief
    wanted: ListingCard
    offered: list[ListingCard] = Field(default_factory=list)
    conversation_id: uuid.UUID | None = None


class MessageOut(ApiModel):
    id: uuid.UUID
    body: str
    photo_url: str | None = None
    created_at: datetime
    sender_id: uuid.UUID
    is_mine: bool


class MessageCreate(ApiModel):
    body: str = Field(min_length=1, max_length=2000)
    photo_url: str | None = None


class ConversationSummary(ApiModel):
    """An inbox row: who, what deal, and what still needs an answer."""

    id: uuid.UUID
    peer: TraderBrief
    offer_id: uuid.UUID
    offer_status: OfferStatus
    #: Titles only — see `services.offers.deal_summary`.
    deal_summary: str
    #: The top-up that goes with the deal, so the row can render it in the
    #: reader's language rather than receiving it pre-formatted.
    cash: Money
    last_message: str | None = None
    last_message_at: datetime | None = None
    unread: int = 0


class ConversationDetail(ConversationSummary):
    offer: OfferOut
    messages: list[MessageOut] = Field(default_factory=list)


class NotificationOut(ApiModel):
    id: uuid.UUID
    kind: NotifyKind
    title: str
    body: str
    avatar_url: str | None = None
    created_at: datetime
    is_unread: bool
    #: Where tapping the row should land. Never inferred from `kind`.
    target_type: NotifyTargetType
    target_id: uuid.UUID | None = None


class MarkRead(ApiModel):
    #: Empty list means "all of them".
    ids: list[uuid.UUID] = Field(default_factory=list)


class MatchOut(ApiModel):
    id: uuid.UUID
    score: int
    reason: str
    mine: ListingCard
    theirs: ListingCard
    owner: TraderBrief


class VerificationStepOut(ApiModel):
    step: str
    state: VerificationState
    hint: str | None = None
    weight: int


class VerificationOut(ApiModel):
    trust_score: int
    steps: list[VerificationStepOut]


class PaymentMethodOut(ApiModel):
    id: uuid.UUID
    brand: str
    label: str
    last4: str
    expires: str
    is_primary: bool


class SettlementOut(ApiModel):
    """A cash top-up that moved through escrow on a completed deal."""

    offer_id: uuid.UUID
    amount: Money
    counterparty_name: str
    settled_at: datetime
    #: True when money left this user's side.
    outgoing: bool
