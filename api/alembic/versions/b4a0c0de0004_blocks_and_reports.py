"""Bloklash va shikoyat jadvallari.

Revision ID: b4a0c0de0004
Revises: b3a0c0de0003
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

revision = "b4a0c0de0004"
down_revision = "b3a0c0de0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "blocks",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "blocker_id",
            UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "blocked_id",
            UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
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
        sa.UniqueConstraint("blocker_id", "blocked_id", name="uq_block_pair"),
        sa.CheckConstraint("blocker_id <> blocked_id", name="no_self_block"),
    )
    op.create_index("ix_blocks_blocker", "blocks", ["blocker_id"])
    op.create_index("ix_blocks_blocked", "blocks", ["blocked_id"])

    target_type = sa.Enum("user", "listing", name="report_target_type")
    reason = sa.Enum(
        "spam", "scam", "offensive", "fake", "illegal", "other", name="report_reason"
    )
    review_status = sa.Enum(
        "open", "reviewed", "actioned", "dismissed", name="report_status"
    )

    op.create_table(
        "reports",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "reporter_id",
            UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("target_type", target_type, nullable=False),
        # Ataylab tashqi kalitsiz: obyekt yo foydalanuvchi, yo e'lon. Shu bois
        # shikoyat o'zi haqidagi e'lon arxivlansa ham saqlanib qoladi — moderator
        # aynan shu holatni o'qishi kerak.
        sa.Column("target_id", UUID(as_uuid=True), nullable=False),
        sa.Column("reason", reason, nullable=False),
        sa.Column("note", sa.String(1000)),
        sa.Column(
            "review_status", review_status, nullable=False, server_default="open"
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
        sa.UniqueConstraint(
            "reporter_id", "target_type", "target_id", name="uq_report_once"
        ),
    )
    op.create_index("ix_reports_queue", "reports", ["review_status", "created_at"])


def downgrade() -> None:
    op.drop_index("ix_reports_queue", table_name="reports")
    op.drop_table("reports")
    op.drop_index("ix_blocks_blocked", table_name="blocks")
    op.drop_index("ix_blocks_blocker", table_name="blocks")
    op.drop_table("blocks")

    for name in ("report_status", "report_reason", "report_target_type"):
        sa.Enum(name=name).drop(op.get_bind(), checkfirst=True)
