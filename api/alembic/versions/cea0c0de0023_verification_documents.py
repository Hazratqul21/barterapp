"""Shaxsni tasdiqlash: hujjatlar, qaror izi va yangi vaznlar.

Ilgari `POST /me/verification/{step}` hech narsa yuklamay bosqichni `pending`
qilardi va uni hech kim ko'ra olmasdi. Shu yo'l bilan "kutilmoqda" bo'lib
qolgan qatorlar `todo` ga qaytadi: ular ortida hujjat yo'q.

Bank bosqichi olib tashlanadi (ortida hech qanday xizmat yo'q edi). Qolgan
vaznlar: telefon 20, pasport 35, selfi 30, korxona 15 — jami 100. Pasport va
selfi birga 65, ya'ni telefon raqamisiz (Google/email) ochilgan hisob ham
60 ballik "Tasdiqlangan" chegarasidan o'tadi; pasport + telefon esa 55.

Revision ID: cea0c0de0023
Revises: cda0c0de0022
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "cea0c0de0023"
down_revision = "cda0c0de0022"
branch_labels = None
depends_on = None

_RECOMPUTE = """
    UPDATE users u SET trust_score = s.score, is_verified = (s.score >= 60)
    FROM (SELECT user_id, COALESCE(SUM(weight) FILTER (WHERE state = 'done'), 0) AS score
          FROM verification_steps GROUP BY user_id) s
    WHERE u.id = s.user_id AND u.deleted_at IS NULL
"""


def upgrade() -> None:
    op.create_table(
        "verification_documents",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("step", sa.String(40), nullable=False),
        sa.Column("kind", sa.String(40), nullable=False),
        sa.Column("data", sa.LargeBinary, nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("user_id", "step", "kind", name="uq_verification_document"),
    )
    op.create_index(
        "ix_verification_documents_created_at", "verification_documents", ["created_at"]
    )
    for column in (
        sa.Column("reject_reason", sa.String(300)),
        sa.Column("submitted_at", sa.DateTime(timezone=True)),
        sa.Column("consented_at", sa.DateTime(timezone=True)),
        sa.Column("reviewed_at", sa.DateTime(timezone=True)),
        sa.Column(
            "reviewed_by",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
        ),
    ):
        op.add_column("verification_steps", column)

    op.execute("DELETE FROM verification_steps WHERE step = 'bank'")
    op.execute("UPDATE verification_steps SET state = 'todo' WHERE state = 'pending'")
    op.execute(
        "UPDATE verification_steps SET weight = CASE step WHEN 'phone' THEN 20 "
        "WHEN 'passport' THEN 35 WHEN 'video' THEN 30 WHEN 'business' THEN 15 "
        "ELSE weight END"
    )
    op.execute(
        "UPDATE verification_steps SET hint = 'Hujjat ushlab olingan selfi' "
        "WHERE step = 'video'"
    )
    op.execute(_RECOMPUTE)


def downgrade() -> None:
    op.execute(
        "UPDATE verification_steps SET weight = CASE step WHEN 'phone' THEN 20 "
        "WHEN 'passport' THEN 25 WHEN 'video' THEN 10 WHEN 'business' THEN 25 "
        "ELSE weight END"
    )
    op.execute(
        "INSERT INTO verification_steps (id, user_id, step, hint, weight, state) "
        "SELECT gen_random_uuid(), user_id, 'bank', 'Escrow to‘lovlari uchun', 20, 'todo' "
        "FROM verification_steps WHERE step = 'phone'"
    )
    op.execute(_RECOMPUTE)
    for name in ("reviewed_by", "reviewed_at", "consented_at", "submitted_at", "reject_reason"):
        op.drop_column("verification_steps", name)
    op.drop_index("ix_verification_documents_created_at", table_name="verification_documents")
    op.drop_table("verification_documents")
