"""Lentaning boshqariladigan bo'laklari.

Banner va tanlangan e'lonlar mijoz kodiga qattiq yozilgan edi: bayram
banneri uchun uch platformaga reliz kerak bo'lardi, App Store ko'rigi
bilan bir hafta. Mavsum bir haftada o'tib ketadi.

Revision ID: c2a0c0de0011
Revises: c1a0c0de0010
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

revision = "c2a0c0de0011"
down_revision = "c1a0c0de0010"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "feed_blocks",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "kind",
            sa.Enum("banner", "promo_listings", "notice", name="feed_block_kind"),
            nullable=False,
        ),
        sa.Column("slot", sa.String(40), nullable=False),
        sa.Column("position", sa.Integer, nullable=False, server_default="0"),
        sa.Column("is_active", sa.Boolean, nullable=False, server_default="true"),
        sa.Column("starts_at", sa.DateTime(timezone=True)),
        sa.Column("ends_at", sa.DateTime(timezone=True)),
        sa.Column("image_url", sa.Text),
        sa.Column("background", sa.String(9)),
        sa.Column(
            "action",
            sa.Enum(
                "none",
                "open_listing",
                "open_search",
                "open_category",
                "open_url",
                name="feed_block_action",
            ),
            nullable=False,
            server_default="none",
        ),
        sa.Column("action_value", sa.Text),
        sa.Column("listing_ids", sa.Text),
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
        sa.CheckConstraint(
            "ends_at IS NULL OR starts_at IS NULL OR ends_at > starts_at",
            name="window_ordered",
        ),
    )
    op.create_index(
        "ix_feed_blocks_slot", "feed_blocks", ["slot", "is_active", "position"]
    )

    op.create_table(
        "feed_block_texts",
        sa.Column(
            "block_id",
            UUID(as_uuid=True),
            sa.ForeignKey("feed_blocks.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column("locale", sa.String(2), primary_key=True),
        sa.Column("title", sa.String(160), nullable=False),
        sa.Column("subtitle", sa.String(300)),
        sa.Column("cta", sa.String(60)),
        sa.CheckConstraint("locale IN ('uz', 'ru', 'en')", name="locale_supported"),
    )


def downgrade() -> None:
    op.drop_table("feed_block_texts")
    op.drop_index("ix_feed_blocks_slot", table_name="feed_blocks")
    op.drop_table("feed_blocks")
    for name in ("feed_block_action", "feed_block_kind"):
        sa.Enum(name=name).drop(op.get_bind(), checkfirst=True)
