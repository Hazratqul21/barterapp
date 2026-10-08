"""Suhbatni arxivlash — har bir ishtirokchi uchun alohida.

Bir tomon arxivlasa, ikkinchisining kirish qutisi o'zgarmaydi. Yangi
xabar kelsa, suhbat ikkala tomonda ham arxivdan chiqadi: arxiv —
"hozircha kerak emas", "bu odamni eshitmayman" emas (u blok).

Revision ID: c6a0c0de0015
Revises: c5a0c0de0014
"""

import sqlalchemy as sa
from alembic import op

revision = "c6a0c0de0015"
down_revision = "c5a0c0de0014"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "conversations",
        sa.Column("archived_by_a_at", sa.DateTime(timezone=True)),
    )
    op.add_column(
        "conversations",
        sa.Column("archived_by_b_at", sa.DateTime(timezone=True)),
    )


def downgrade() -> None:
    op.drop_column("conversations", "archived_by_b_at")
    op.drop_column("conversations", "archived_by_a_at")
