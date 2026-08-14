"""Qurilmalar jadvali va bildirishnoma outbox'i.

`notifications.pushed_at` — null bo'lsa hali yuborilmagan. Shu ustun
jadvalni o'z navbatiga aylantiradi: bildirishnoma savdo o'zgarishi bilan
bir tranzaksiyada yoziladi, shuning uchun qaytarilgan tranzaksiya hech
qachon "savdo bo'ldi" degan push qoldirmaydi.

Mavjud qatorlarga `now()` qo'yiladi — ular allaqachon o'qilgan bo'lishi
mumkin, migratsiyadan keyin butun eski tarix bo'yicha push yuborish esa
foydalanuvchini bir necha yuz bildirishnoma bilan ko'mib tashlardi.

Revision ID: b5a0c0de0005
Revises: b4a0c0de0004
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

revision = "b5a0c0de0005"
down_revision = "b4a0c0de0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "devices",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "user_id",
            UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("token", sa.String(500), nullable=False),
        sa.Column(
            "platform",
            sa.Enum("ios", "android", "web", name="device_platform"),
            nullable=False,
        ),
        sa.Column("locale", sa.String(2), nullable=False, server_default="uz"),
        sa.Column("last_seen_at", sa.DateTime(timezone=True)),
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
        sa.UniqueConstraint("token", name="uq_device_token"),
    )
    op.create_index("ix_devices_user", "devices", ["user_id"])

    op.add_column(
        "notifications", sa.Column("pushed_at", sa.DateTime(timezone=True))
    )
    op.execute("UPDATE notifications SET pushed_at = now()")

    op.create_index(
        "ix_notifications_outbox",
        "notifications",
        ["created_at"],
        postgresql_where=sa.text("pushed_at IS NULL"),
    )


def downgrade() -> None:
    op.drop_index("ix_notifications_outbox", table_name="notifications")
    op.drop_column("notifications", "pushed_at")
    op.drop_index("ix_devices_user", table_name="devices")
    op.drop_table("devices")
    sa.Enum(name="device_platform").drop(op.get_bind(), checkfirst=True)
