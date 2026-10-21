"""Google identities, password credentials and shared login throttling."""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql
revision = "c9a0c0de0018"
down_revision = "c8a0c0de0017"
branch_labels = None
depends_on = None

def upgrade():
    op.alter_column("users", "phone", existing_type=sa.String(20), nullable=True)
    for name, kind in [("email", sa.String(320)), ("google_sub", sa.String(255)), ("password_hash", sa.Text())]:
        op.add_column("users", sa.Column(name, kind, nullable=True))
    op.create_unique_constraint("uq_users_email", "users", ["email"])
    op.create_unique_constraint("uq_users_google_sub", "users", ["google_sub"])
    op.create_table("login_attempts", sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True), sa.Column("identifier_hash", sa.String(64), nullable=False), sa.Column("created_at", sa.DateTime(timezone=True), nullable=False))
    op.create_index("ix_login_attempts_identifier_hash", "login_attempts", ["identifier_hash"])
    op.create_index("ix_login_attempts_created_at", "login_attempts", ["created_at"])

def downgrade():
    # Google-only users need a verified phone before this migration can reverse.
    op.drop_table("login_attempts")
    op.drop_constraint("uq_users_google_sub", "users")
    op.drop_constraint("uq_users_email", "users")
    for name in ["password_hash", "google_sub", "email"]:
        op.drop_column("users", name)
    op.alter_column("users", "phone", existing_type=sa.String(20), nullable=False)
