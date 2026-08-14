"""Bildirishnoma sozlamalari.

Qatorlar oldindan yaratilmaydi: qatori yo'q hisob uchun standart qiymat
kodda turadi. Shu sababli keyinchalik yangi tur qo'shilsa, u mavjud
hisoblarda o'z-o'zidan yoqilgan bo'ladi va backfill kerak bo'lmaydi.

Revision ID: b6a0c0de0006
Revises: b5a0c0de0005
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

revision = "b6a0c0de0006"
down_revision = "b5a0c0de0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "notification_settings",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "user_id",
            UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("offers", sa.Boolean, nullable=False, server_default="true"),
        sa.Column("matches", sa.Boolean, nullable=False, server_default="true"),
        sa.Column("messages", sa.Boolean, nullable=False, server_default="true"),
        sa.Column("system", sa.Boolean, nullable=False, server_default="true"),
        sa.Column("quiet_from", sa.Integer),
        sa.Column("quiet_to", sa.Integer),
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
        sa.UniqueConstraint("user_id", name="uq_notification_setting_user"),
        sa.CheckConstraint(
            "quiet_from IS NULL OR (quiet_from BETWEEN 0 AND 23)",
            name="quiet_from_hour",
        ),
        sa.CheckConstraint(
            "quiet_to IS NULL OR (quiet_to BETWEEN 0 AND 23)", name="quiet_to_hour"
        ),
        sa.CheckConstraint(
            "(quiet_from IS NULL) = (quiet_to IS NULL)", name="quiet_pair"
        ),
    )


def downgrade() -> None:
    op.drop_table("notification_settings")
