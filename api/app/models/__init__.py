"""Every model is imported here so Alembic autogenerate sees the full metadata."""

from app.models.desire import Desire  # noqa: F401
from app.models.listing import (  # noqa: F401
    Listing,
    ListingPhoto,
    ListingTranslation,
    ListingWant,
    ListingWantTranslation,
)
from app.models.moderation import Block, Report  # noqa: F401
from app.models.offer import Conversation, Message, Offer, OfferItem  # noqa: F401
from app.models.review import Review  # noqa: F401
from app.models.social import (  # noqa: F401
    Match,
    Notification,
    PaymentMethod,
    VerificationStep,
)
from app.models.user import OtpChallenge, User, UserType  # noqa: F401

__all__ = [
    "Block",
    "Conversation",
    "Desire",
    "Listing",
    "ListingPhoto",
    "ListingTranslation",
    "ListingWant",
    "ListingWantTranslation",
    "Match",
    "Message",
    "Notification",
    "Offer",
    "OfferItem",
    "OtpChallenge",
    "PaymentMethod",
    "Report",
    "Review",
    "User",
    "UserType",
    "VerificationStep",
]
