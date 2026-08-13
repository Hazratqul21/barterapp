"""Refresh token sessiyalari jadvali

Har bir berilgan refresh token uchun bitta qator: bekor qilish (logout, parol
almashtirish, o'g'irlik) va rotation/reuse aniqlash shu yozuv orqali ishlaydi.
Token — imzolangan JWT bo'lib, o'z qatorining id sini `jti` sifatida ko'taradi.

Revision ID: b2a0c0de0002
Revises: b1a0c0de0001
Create Date: 2026-08-13
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

revision: str = "b2a0c0de0002"
down_revision: str | None = "b1a0c0de0001"
branch_labels: Sequence[str] | None = None
depends_on: Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "refresh_tokens",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", UUID(as_uuid=True), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(
        "ix_refresh_tokens_user_id", "refresh_tokens", ["user_id"]
    )


def downgrade() -> None:
    op.drop_index("ix_refresh_tokens_user_id", table_name="refresh_tokens")
    op.drop_table("refresh_tokens")
