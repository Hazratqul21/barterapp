"""Huquqiy hujjatlar: maxfiylik, shartlar, oferta — admin paneldan tahrirlanadi.

Boshlang'ich matn `app/legal_defaults/*.md` dan olinadi. Keyin u faqat
admin panelda o'zgaradi; bu migratsiya qayta ishlasa ham mavjud matnga
tegmaydi.

Revision ID: c9a0c0de0018
Revises: c8a0c0de0017
"""

from pathlib import Path

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "c9a0c0de0018"
down_revision = "c8a0c0de0017"
branch_labels = None
depends_on = None

_DEFAULTS = Path(__file__).resolve().parents[2] / "app" / "legal_defaults"

#: slug, nomlar, tartib.
_SEED = [
    ("privacy", {"uz": "Maxfiylik siyosati", "ru": "Политика конфиденциальности",
                 "en": "Privacy policy"}, 10),
    ("terms", {"uz": "Foydalanish shartlari", "ru": "Условия использования",
               "en": "Terms of use"}, 20),
    ("offer", {"uz": "Ommaviy oferta", "ru": "Публичная оферта",
               "en": "Public offer"}, 30),
    ("delete-account", {"uz": "Hisobni o'chirish", "ru": "Удаление аккаунта",
                        "en": "Delete account"}, 40),
]


def upgrade() -> None:
    table = op.create_table(
        "legal_documents",
        sa.Column("slug", sa.String(40), primary_key=True),
        sa.Column("title", postgresql.JSONB, nullable=False),
        sa.Column("body", postgresql.JSONB, nullable=False),
        sa.Column("file_url", sa.Text, nullable=True),
        sa.Column("is_published", sa.Boolean, nullable=False, server_default="true"),
        sa.Column("position", sa.Integer, nullable=False, server_default="0"),
        sa.Column(
            "updated_by",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"),
            nullable=False,
        ),
    )
    op.bulk_insert(
        table,
        [
            {
                "slug": slug,
                "title": title,
                "body": {"uz": (_DEFAULTS / f"{slug}.md").read_text(encoding="utf-8")},
                "is_published": True,
                "position": position,
            }
            for slug, title, position in _SEED
        ],
    )


def downgrade() -> None:
    op.drop_table("legal_documents")
