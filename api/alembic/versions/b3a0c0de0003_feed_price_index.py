"""Narx bo'yicha saralash uchun indeks.

Lenta endi `sort=cheap|expensive` ni qo'llaydi. Mavjud `ix_listings_feed`
(status, tag, created_at) bu tartibga yaramaydi — planner har safar butun
jadvalni skanlab, keyin saralashga majbur bo'ladi. Bu indeks aynan shu
kirish yo'li uchun: faol e'lonlar, narx tartibida, `id` esa teng narxlarni
ajratuvchi sifatida (kursor ham shu juftlikka tayanadi).

Revision ID: b3a0c0de0003
Revises: b2a0c0de0002
"""

from alembic import op

revision = "b3a0c0de0003"
down_revision = "b2a0c0de0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_index(
        "ix_listings_price",
        "listings",
        ["status", "value_minor", "id"],
    )


def downgrade() -> None:
    op.drop_index("ix_listings_price", table_name="listings")
