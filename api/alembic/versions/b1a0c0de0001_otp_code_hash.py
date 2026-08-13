"""OTP kodini hash sifatida saqlash

`otp_challenges.code` (ochiq 6 xonali kod) → `code_hash` (HMAC-SHA256, 64
belgi). Kodlar qisqa umrli (5 daqiqa), shuning uchun mavjud qatorlar
ahamiyatsiz — ustun nomi o'zgartiriladi va kengaytiriladi, eski qiymatlar
yangi hash bilan mos kelmaydi (o'sha challenge'lar shunchaki yangi kod
so'raladi).

Revision ID: b1a0c0de0001
Revises: 8e85a03c7ff3
Create Date: 2026-08-13
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "b1a0c0de0001"
down_revision: str | None = "8e85a03c7ff3"
branch_labels: Sequence[str] | None = None
depends_on: Sequence[str] | None = None


def upgrade() -> None:
    op.alter_column(
        "otp_challenges",
        "code",
        new_column_name="code_hash",
        existing_type=sa.String(length=6),
        type_=sa.String(length=64),
        existing_nullable=False,
    )


def downgrade() -> None:
    op.alter_column(
        "otp_challenges",
        "code_hash",
        new_column_name="code",
        existing_type=sa.String(length=64),
        type_=sa.String(length=6),
        existing_nullable=False,
    )
