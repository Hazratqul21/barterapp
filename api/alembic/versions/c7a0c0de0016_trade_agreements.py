"""F02: kelishuv, band qilish, ikki tomonlama tasdiq, nizo.

Revision ID: c7a0c0de0016
Revises: c6a0c0de0015
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "c7a0c0de0016"
down_revision = "c6a0c0de0015"
branch_labels = None
depends_on = None

_reason = postgresql.ENUM(
    "no_show", "not_received", "not_as_described", "other", name="dispute_reason"
)
_status = postgresql.ENUM("escalated", "resolved", name="dispute_status")
_resolution = postgresql.ENUM("cancel", "complete", name="dispute_resolution")


def upgrade() -> None:
    op.create_table(
        "trade_agreements",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "offer_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("offers.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("terms", postgresql.JSONB, nullable=False),
        sa.Column("value_minor", sa.BigInteger, nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.UniqueConstraint("offer_id", name="uq_agreement_offer"),
    )
    op.create_table(
        "reservations",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "listing_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("listings.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "offer_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("offers.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("active", sa.Boolean, nullable=False, server_default="true"),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("expires_at", sa.DateTime(timezone=True)),
        sa.Column("released_at", sa.DateTime(timezone=True)),
        sa.Column("release_reason", sa.String(20)),
    )
    op.create_index(
        "uq_reservation_active_listing",
        "reservations",
        ["listing_id"],
        unique=True,
        postgresql_where=sa.text("active"),
    )
    op.create_index("ix_reservations_offer", "reservations", ["offer_id"])
    op.create_table(
        "trade_confirmations",
        sa.Column(
            "offer_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("offers.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column(
            "confirmed_at", sa.DateTime(timezone=True),
            server_default=sa.text("now()"), nullable=False,
        ),
    )
    _reason.create(op.get_bind(), checkfirst=True)
    _status.create(op.get_bind(), checkfirst=True)
    _resolution.create(op.get_bind(), checkfirst=True)
    op.create_table(
        "disputes",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "offer_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("offers.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "opened_by",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("reason", postgresql.ENUM(name="dispute_reason", create_type=False),
                  nullable=False),
        sa.Column("note", sa.Text),
        sa.Column("status", postgresql.ENUM(name="dispute_status", create_type=False),
                  nullable=False),
        sa.Column("resolution",
                  postgresql.ENUM(name="dispute_resolution", create_type=False)),
        sa.Column(
            "resolved_by",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
        ),
        sa.Column("decided_by_rule", sa.String(60)),
        sa.Column("rules_version", sa.Integer),
        sa.Column("resolution_note", sa.Text),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("resolved_at", sa.DateTime(timezone=True)),
        sa.UniqueConstraint("offer_id", name="uq_dispute_offer"),
    )
    op.create_index("ix_disputes_status", "disputes", ["status", "created_at"])


def downgrade() -> None:
    op.drop_index("ix_disputes_status", table_name="disputes")
    op.drop_table("disputes")
    op.drop_table("trade_confirmations")
    op.drop_index("ix_reservations_offer", table_name="reservations")
    op.drop_index("uq_reservation_active_listing", table_name="reservations")
    op.drop_table("reservations")
    op.drop_table("trade_agreements")
    _resolution.drop(op.get_bind(), checkfirst=True)
    _status.drop(op.get_bind(), checkfirst=True)
    _reason.drop(op.get_bind(), checkfirst=True)
