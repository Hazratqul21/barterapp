"""Saqlangan e'lonlar.

Revision ID: b7a0c0de0007
Revises: b6a0c0de0006
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

revision = "b7a0c0de0007"
down_revision = "b6a0c0de0006"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "favorites",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "user_id",
            UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "listing_id",
            UUID(as_uuid=True),
            sa.ForeignKey("listings.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.UniqueConstraint("user_id", "listing_id", name="uq_favorite_pair"),
    )
    op.create_index("ix_favorites_user", "favorites", ["user_id", "created_at"])
    op.create_index("ix_favorites_listing", "favorites", ["listing_id"])


def downgrade() -> None:
    op.drop_index("ix_favorites_listing", table_name="favorites")
    op.drop_index("ix_favorites_user", table_name="favorites")
    op.drop_table("favorites")
