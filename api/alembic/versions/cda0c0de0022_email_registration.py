"""Email orqali ro'yxatdan o'tish: tasdiqlash kodlari va kirish usuli.

`email_challenges` — emailga yuborilgan 6 xonali kodlar (faqat HMAC'i, xuddi
`otp_challenges` kabi). Telefon jadvali `String(20)` va telefon cheklovlari
bilan qurilgan; email uchun alohida jadval o'sha qoidalarni buzmaydi.

`has_sign_in` cheklovi endi email bilan ochilgan hisobni ham qabul qiladi:
bunday hisobda telefon ham, Google ham yo'q — faqat tasdiqlangan email va parol.

Revision ID: cda0c0de0022
Revises: cca0c0de0021
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "cda0c0de0022"
down_revision = "cca0c0de0021"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "email_challenges",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("email", sa.String(320), nullable=False),
        #: "register" yoki "reset" — bir maqsadning kodi ikkinchisiga o'tmaydi.
        sa.Column("purpose", sa.String(16), nullable=False),
        sa.Column("code_hash", sa.String(64), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("consumed_at", sa.DateTime(timezone=True)),
        sa.Column("attempts", sa.Integer, nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint("purpose IN ('register', 'reset')", name="email_purpose"),
    )
    op.create_index("ix_email_challenges_email", "email_challenges", ["email"])

    op.execute("ALTER TABLE users DROP CONSTRAINT ck_users_has_sign_in")
    op.execute(
        "ALTER TABLE users ADD CONSTRAINT ck_users_has_sign_in CHECK ("
        "phone IS NOT NULL OR google_sub IS NOT NULL "
        "OR (email IS NOT NULL AND password_hash IS NOT NULL))"
    )


def downgrade() -> None:
    # Faqat email bilan ochilgan hisoblar eski cheklovga sig'maydi. Ularni
    # jimgina o'chirish o'rniga to'xtaymiz — qaror odamniki.
    left = op.get_bind().scalar(
        sa.text("SELECT count(*) FROM users WHERE phone IS NULL AND google_sub IS NULL")
    )
    if left:
        raise RuntimeError(
            f"{left} ta hisob faqat email bilan ochilgan — downgrade ularni buzadi."
        )
    op.execute("ALTER TABLE users DROP CONSTRAINT ck_users_has_sign_in")
    op.execute(
        "ALTER TABLE users ADD CONSTRAINT ck_users_has_sign_in "
        "CHECK (phone IS NOT NULL OR google_sub IS NOT NULL)"
    )
    op.drop_index("ix_email_challenges_email", table_name="email_challenges")
    op.drop_table("email_challenges")
