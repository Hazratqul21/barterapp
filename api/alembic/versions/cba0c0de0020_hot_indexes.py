"""Tez-tez ishlatiladigan so'rovlar uchun indekslar.

listings.owner_id (profil, "mening e'lonlarim", hisob o'chirish),
offers.from_user_id (yuborilgan takliflar), offers.listing_id.

Revision ID: cba0c0de0020
Revises: caa0c0de0019
"""

from alembic import op

revision = "cba0c0de0020"
down_revision = "caa0c0de0019"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_index("ix_listings_owner", "listings", ["owner_id", "created_at"])
    op.create_index("ix_offers_outbox", "offers", ["from_user_id", "status", "created_at"])
    op.create_index("ix_offers_listing", "offers", ["listing_id"])


def downgrade() -> None:
    op.drop_index("ix_offers_listing", table_name="offers")
    op.drop_index("ix_offers_outbox", table_name="offers")
    op.drop_index("ix_listings_owner", table_name="listings")
