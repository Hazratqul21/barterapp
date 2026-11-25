"""Birinchi foydalanuvchilar aksiyasi: kimga berilgani.

Hisoblagich emas, foydalanuvchidagi sana: nechta berilgani shundan sanaladi,
ya'ni bir odam ikki marta olmaydi va son hech qachon haqiqatdan uzilmaydi.

Revision ID: cfa0c0de0024
Revises: cda0c0de0022
"""

import sqlalchemy as sa
from alembic import op

revision = "cfa0c0de0024"
down_revision = "cda0c0de0022"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("promo_granted_at", sa.DateTime(timezone=True)))
    op.create_index(
        "ix_users_promo_granted_at",
        "users",
        ["promo_granted_at"],
        postgresql_where=sa.text("promo_granted_at IS NOT NULL"),
    )


def downgrade() -> None:
    op.drop_index("ix_users_promo_granted_at", table_name="users")
    op.drop_column("users", "promo_granted_at")
