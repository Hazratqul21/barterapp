"""Hodisalar jadvali.

Bu jadvalning boshqalardan farqi: uni orqaga qaytib to'ldirib bo'lmaydi.
Kod keyin ham yoziladi, model keyin ham o'rgatiladi, lekin bugun yozilmagan
hodisa butunlay yo'qoladi. Shu sababli u modeldan oldin quriladi.

Revision ID: b9a0c0de0009
Revises: b8a0c0de0008
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB, UUID

revision = "b9a0c0de0009"
down_revision = "b8a0c0de0008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "events",
        # bigserial: bu jadval boshqalardan yuz barobar tez o'sadi.
        sa.Column("id", sa.BigInteger, primary_key=True, autoincrement=True),
        sa.Column("occurred_at", sa.DateTime(timezone=True), nullable=False),
        # SET NULL: hisob o'chirilganda tahlil yo'qolmasin, lekin hodisa
        # endi hech kimga bog'lanmasin.
        sa.Column(
            "user_id",
            UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
        ),
        sa.Column("session_id", sa.String(64)),
        sa.Column("kind", sa.String(40), nullable=False),
        sa.Column("target_type", sa.String(20)),
        sa.Column("target_id", UUID(as_uuid=True)),
        sa.Column("payload", JSONB, nullable=False, server_default="{}"),
        sa.Column("locale", sa.String(2)),
        sa.Column("platform", sa.String(10)),
        sa.Column("dedupe_key", sa.String(64)),
        sa.UniqueConstraint("dedupe_key", name="uq_event_dedupe"),
    )
    op.create_index("ix_events_kind_time", "events", ["kind", "occurred_at"])
    op.create_index(
        "ix_events_target", "events", ["target_type", "target_id", "occurred_at"]
    )
    op.create_index("ix_events_user_time", "events", ["user_id", "occurred_at"])


def downgrade() -> None:
    op.drop_index("ix_events_user_time", table_name="events")
    op.drop_index("ix_events_target", table_name="events")
    op.drop_index("ix_events_kind_time", table_name="events")
    op.drop_table("events")
