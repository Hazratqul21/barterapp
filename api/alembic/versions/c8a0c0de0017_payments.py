"""To'lovlar: tariflar, buyurtmalar, Payme tranzaksiyalari, e'lon boost muddati.

Revision ID: c8a0c0de0017
Revises: c7a0c0de0016
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "c8a0c0de0017"
down_revision = "c7a0c0de0016"
branch_labels = None
depends_on = None

_kind = postgresql.ENUM("listing_pack", "boost", name="product_kind", create_type=False)
_status = postgresql.ENUM("pending", "paid", "cancelled", name="order_status", create_type=False)


def _ts() -> list[sa.Column]:
    return [
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"),
            nullable=False,
        ),
    ]


def upgrade() -> None:
    bind = op.get_bind()
    postgresql.ENUM("listing_pack", "boost", name="product_kind").create(bind, checkfirst=True)
    postgresql.ENUM("pending", "paid", "cancelled", name="order_status").create(
        bind, checkfirst=True
    )

    op.add_column(
        "listings", sa.Column("premium_until", sa.DateTime(timezone=True), nullable=True)
    )

    op.create_table(
        "products",
        sa.Column("code", sa.String(40), primary_key=True),
        sa.Column("kind", _kind, nullable=False),
        sa.Column("title", postgresql.JSONB, nullable=False),
        sa.Column("price_minor", sa.BigInteger, nullable=False),
        sa.Column("discount_percent", sa.Integer, nullable=False, server_default="0"),
        sa.Column("discount_until", sa.DateTime(timezone=True)),
        sa.Column("quantity", sa.Integer, nullable=False, server_default="1"),
        sa.Column("duration_days", sa.Integer),
        sa.Column("is_active", sa.Boolean, nullable=False, server_default="false"),
        sa.Column("position", sa.Integer, nullable=False, server_default="0"),
        sa.Column("mxik_code", sa.String(20)),
        sa.Column("package_code", sa.String(20)),
        sa.Column("vat_percent", sa.Integer, nullable=False, server_default="0"),
        *_ts(),
        sa.CheckConstraint("price_minor >= 0", name="ck_products_price_non_negative"),
        sa.CheckConstraint(
            "discount_percent >= 0 AND discount_percent <= 100",
            name="ck_products_discount_range",
        ),
        sa.CheckConstraint("quantity >= 1", name="ck_products_quantity_positive"),
    )

    op.create_table(
        "payment_orders",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
        ),
        sa.Column("product_code", sa.String(40), nullable=False),
        sa.Column("kind", _kind, nullable=False),
        sa.Column(
            "listing_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("listings.id", ondelete="SET NULL"),
        ),
        sa.Column("quantity", sa.Integer, nullable=False, server_default="1"),
        sa.Column("duration_days", sa.Integer),
        sa.Column("amount_minor", sa.BigInteger, nullable=False),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("status", _status, nullable=False, server_default="pending"),
        sa.Column("provider", sa.String(20), nullable=False, server_default="payme"),
        sa.Column("paid_at", sa.DateTime(timezone=True)),
        sa.Column("cancelled_at", sa.DateTime(timezone=True)),
        *_ts(),
        sa.CheckConstraint("amount_minor > 0", name="ck_payment_orders_amount_positive"),
    )
    op.create_index("ix_payment_orders_user", "payment_orders", ["user_id", "created_at"])

    op.create_table(
        "payme_transactions",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("payme_id", sa.String(64), nullable=False),
        sa.Column(
            "order_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("payment_orders.id"),
            nullable=False,
        ),
        sa.Column("amount_minor", sa.BigInteger, nullable=False),
        sa.Column("state", sa.SmallInteger, nullable=False),
        sa.Column("payme_time", sa.BigInteger, nullable=False),
        sa.Column("create_time", sa.BigInteger, nullable=False),
        sa.Column("perform_time", sa.BigInteger, nullable=False, server_default="0"),
        sa.Column("cancel_time", sa.BigInteger, nullable=False, server_default="0"),
        sa.Column("reason", sa.SmallInteger),
        *_ts(),
        sa.UniqueConstraint("payme_id", name="uq_payme_transactions_payme_id"),
    )
    op.create_index("ix_payme_transactions_order", "payme_transactions", ["order_id"])
    op.create_index(
        "ix_payme_transactions_create_time", "payme_transactions", ["create_time"]
    )


def downgrade() -> None:
    op.drop_table("payme_transactions")
    op.drop_table("payment_orders")
    op.drop_table("products")
    op.drop_column("listings", "premium_until")
    op.execute("DROP TYPE IF EXISTS order_status")
    op.execute("DROP TYPE IF EXISTS product_kind")
