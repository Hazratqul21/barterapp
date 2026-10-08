"""E'lonning o'z hududi va tumani.

Avval hudud filtri egasining hozirgi hududi orqali ishlardi: savdogar
ko'chsa, uning barcha eski e'lonlari ham "ko'chib" ketardi, va bitta
odam ikki viloyatdagi narsani joylay olmasdi. Endi hudud e'lonning
o'zida. Mavjud e'lonlar egasining hududi bilan to'ldiriladi.

Revision ID: c5a0c0de0014
Revises: c4a0c0de0013
"""

import sqlalchemy as sa
from alembic import op

revision = "c5a0c0de0014"
down_revision = "c4a0c0de0013"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("listings", sa.Column("region", sa.String(120)))
    op.add_column("listings", sa.Column("district", sa.String(120)))
    op.execute(
        """
        UPDATE listings AS l
           SET region = u.region, district = u.district
          FROM users AS u
         WHERE u.id = l.owner_id AND l.region IS NULL
        """
    )
    # The feed filter: active listings in one region, newest first.
    op.create_index(
        "ix_listings_region_status", "listings", ["region", "status", "created_at"]
    )


def downgrade() -> None:
    op.drop_index("ix_listings_region_status", table_name="listings")
    op.drop_column("listings", "district")
    op.drop_column("listings", "region")
