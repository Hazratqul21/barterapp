"""Google orqali kirish: users.google_sub, users.email; telefon ixtiyoriy.

Revision ID: caa0c0de0019
Revises: c9a0c0de0018
"""

import sqlalchemy as sa
from alembic import op

revision = "caa0c0de0019"
down_revision = "c9a0c0de0018"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("google_sub", sa.String(64), nullable=True))
    op.add_column("users", sa.Column("email", sa.String(254), nullable=True))
    op.create_unique_constraint("uq_users_google_sub", "users", ["google_sub"])
    op.alter_column("users", "phone", existing_type=sa.String(20), nullable=True)
    op.create_check_constraint(
        "has_sign_in", "users", "phone IS NOT NULL OR google_sub IS NOT NULL"
    )


def downgrade() -> None:
    # Telefonsiz (faqat Google) hisoblar bo'lsa, bu qadam to'xtaydi — ataylab:
    # ularni jimgina o'chirib yuborishdan ko'ra xato yaxshi.
    op.drop_constraint("ck_users_has_sign_in", "users", type_="check")
    op.alter_column("users", "phone", existing_type=sa.String(20), nullable=False)
    op.drop_constraint("uq_users_google_sub", "users", type_="unique")
    op.drop_column("users", "email")
    op.drop_column("users", "google_sub")
