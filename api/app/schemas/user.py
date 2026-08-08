from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import Field

from app.schemas.common import ApiModel


class TraderBrief(ApiModel):
    """
    How a trader appears anywhere they are mentioned — a feed card, a chat header,
    an owner row. Every screen renders this same shape, so none of them can drift.
    """

    id: uuid.UUID
    #: Always the person's own name. A business line goes in `handle`, never here —
    #: substituting one for the other is how a trader ends up nameless on a card.
    name: str
    handle: str | None = None
    avatar_url: str | None = None
    is_verified: bool
    rating: float | None = None
    deals: int = 0
    is_online: bool = False
    last_seen_at: datetime | None = None


class TraderProfile(TraderBrief):
    cover_url: str | None = None
    bio: str | None = None
    location: str | None = None
    joined_at: datetime
    completion_rate: int | None = Field(
        default=None, description="Percent of accepted deals that reached completed"
    )
    responds_within_minutes: int | None = None
    review_count: int = 0


class Me(TraderProfile):
    phone: str
    first_name: str
    last_name: str
    region: str | None = None
    district: str | None = None
    address: str | None = None
    locale: str
    trust_score: int
    active_listings: int = 0
    completed_trades: int = 0


class MeUpdate(ApiModel):
    first_name: str | None = Field(default=None, min_length=1, max_length=80)
    last_name: str | None = Field(default=None, min_length=1, max_length=80)
    region: str | None = Field(default=None, max_length=120)
    district: str | None = Field(default=None, max_length=120)
    address: str | None = None
    avatar_url: str | None = None
    locale: str | None = Field(default=None, pattern="^(uz|ru|en)$")
    #: Set directly only by a client that has a real fix (GPS). Otherwise the
    #: server derives both from `region` — see `PATCH /me`.
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)


class OtpRequest(ApiModel):
    phone: str = Field(pattern=r"^\+998\d{9}$", examples=["+998901234122"])


class OtpRequestResult(ApiModel):
    sent: bool
    expires_in: int
    debug_code: str | None = Field(
        default=None, description="Only populated while OTP_DEBUG is on"
    )


class OtpVerify(ApiModel):
    phone: str = Field(pattern=r"^\+998\d{9}$")
    code: str = Field(min_length=4, max_length=6)


class TokenPair(ApiModel):
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    is_new_user: bool = False


class RefreshRequest(ApiModel):
    refresh_token: str
