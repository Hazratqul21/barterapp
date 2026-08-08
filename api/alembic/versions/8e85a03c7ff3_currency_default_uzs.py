"""currency default uzs

Revision ID: 8e85a03c7ff3
Revises: 9052adff4b59
Create Date: 2026-08-08 15:41:35.488272
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '8e85a03c7ff3'
down_revision: Union[str, None] = '9052adff4b59'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade() -> None:
    """
    Bring the currency defaults in line with the product.

    The model has said `server_default="UZS"` for a long time; the initial
    migration says `'USD'`, and the migration is what the database actually
    obeys. Everything in this marketplace is priced in so'm — the business plan,
    the seed, `settings.default_currency` — so every row inserted without an
    explicit currency has been quietly stamped as dollars.

    Listings escaped it, because `POST /listings` always sends one. Offers did
    not: seeded and legacy rows carry `USD` for trades denominated in so'm, and
    that is what the inbox was rendering.
    """
    op.alter_column(
        "listings", "currency", server_default="UZS", existing_type=sa.String(3)
    )
    op.alter_column(
        "offers", "currency", server_default="UZS", existing_type=sa.String(3)
    )

    # Repair the rows the wrong default produced. Narrowed to offers whose
    # wanted listing is in so'm, so a genuinely foreign-currency trade — if one
    # is ever added — is left alone.
    op.execute(
        """
        UPDATE offers SET currency = 'UZS'
        WHERE currency = 'USD'
          AND listing_id IN (SELECT id FROM listings WHERE currency = 'UZS')
        """
    )


def downgrade() -> None:
    op.alter_column(
        "offers", "currency", server_default="USD", existing_type=sa.String(3)
    )
    op.alter_column(
        "listings", "currency", server_default="USD", existing_type=sa.String(3)
    )
