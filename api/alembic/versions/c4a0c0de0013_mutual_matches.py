"""O'zaro moslik (F01): moslik ikki tomonlamami va nega.

Faqat qo'shimcha ustunlar, standart qiymatlar bilan — eski qatorlar va
eski mijozlar o'zgarishsiz ishlaydi. `matches` har so'rovda qayta
hisoblanadi, shuning uchun to'ldirish (backfill) kerak emas.

Revision ID: c4a0c0de0013
Revises: c3a0c0de0012
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "c4a0c0de0013"
down_revision = "c3a0c0de0012"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "matches",
        sa.Column("mutual", sa.Boolean, nullable=False, server_default="false"),
    )
    op.add_column(
        "matches",
        sa.Column(
            "reason_codes",
            postgresql.ARRAY(sa.String(32)),
            nullable=False,
            server_default="{}",
        ),
    )
    op.add_column(
        "matches",
        sa.Column(
            "rules_version", sa.String(16), nullable=False, server_default="v0"
        ),
    )


def downgrade() -> None:
    op.drop_column("matches", "rules_version")
    op.drop_column("matches", "reason_codes")
    op.drop_column("matches", "mutual")
