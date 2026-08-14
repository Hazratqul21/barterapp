"""Moderator bayrog'i.

Faqat serverdan beriladi (`python -m app.grant_moderator`). Uni o'zgartira
oladigan endpoint ataylab yo'q.

Revision ID: b8a0c0de0008
Revises: b7a0c0de0007
"""

import sqlalchemy as sa
from alembic import op

revision = "b8a0c0de0008"
down_revision = "b7a0c0de0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "is_moderator", sa.Boolean, nullable=False, server_default="false"
        ),
    )


def downgrade() -> None:
    op.drop_column("users", "is_moderator")
