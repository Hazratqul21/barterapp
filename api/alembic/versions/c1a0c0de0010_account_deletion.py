"""Hisobni o'chirish belgisi.

Qator o'chirilmaydi, ichi tozalanadi: users.id ga o'nlab jadval CASCADE
bilan bog'langan va ularning yarmi qarshi tomonga tegishli — yakunlangan
savdolar, suhbatlar, sharhlar. Mening hisobimni o'chirganim birovning
savdo tarixini o'chirishi mumkin emas.

Revision ID: c1a0c0de0010
Revises: b9a0c0de0009
"""

import sqlalchemy as sa
from alembic import op

revision = "c1a0c0de0010"
down_revision = "b9a0c0de0009"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("deleted_at", sa.DateTime(timezone=True)))
    # Tirik hisoblar bo'yicha so'rovlar uchun — ularning soni o'chirilganlardan
    # ancha ko'p bo'ladi, shuning uchun qisman indeks.
    op.create_index(
        "ix_users_deleted",
        "users",
        ["deleted_at"],
        postgresql_where=sa.text("deleted_at IS NOT NULL"),
    )


def downgrade() -> None:
    op.drop_index("ix_users_deleted", table_name="users")
    op.drop_column("users", "deleted_at")
