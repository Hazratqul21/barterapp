"""Ishlab turgan serverda o'zgartiriladigan sozlamalar.

Firebase kaliti `.env` da emas, chunki `.env` ni o'zgartirish server
fayllariga kirishni va qayta ishga tushirishni talab qiladi. Kalit esa
mahsulot egasi qo'lida bo'ladi va u serverga kira olmaydi — natijada
"kalit bor-u, uni qo'yadigan odam yo'q" holati chiqadi.

Revision ID: c3a0c0de0012
Revises: c2a0c0de0011
"""

import sqlalchemy as sa
from alembic import op

revision = "c3a0c0de0012"
down_revision = "c2a0c0de0011"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "app_settings",
        sa.Column("key", sa.String(60), primary_key=True),
        sa.Column("value", sa.Text, nullable=False),
        sa.Column("is_secret", sa.Boolean, nullable=False, server_default="false"),
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
    )


def downgrade() -> None:
    op.drop_table("app_settings")
