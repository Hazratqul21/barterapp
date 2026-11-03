"""Kategoriyalar jadvali: admin qo'shadi, tahrirlaydi, yashiradi.

Oltita kategoriya avval `listing_tag` enum'i va koddagi lug'at edi — yangisini
qo'shish uchun migratsiya va uch platformada reliz kerak bo'lardi. Endi ular
`categories` jadvalida; `listings.tag` va `desires.category` unga tashqi kalit.
Id'lar o'zgarmaydi (`agri`, `livestock` …), shuning uchun ilovalar va
`/listings?tag=` filtri avvalgidek ishlaydi.

Admin yuklagan rasmlar `app_settings` dagi `category_image:<id>` qatorlaridan
jadvalning `image` ustuniga ko'chiriladi.

Revision ID: cca0c0de0021
Revises: cba0c0de0020
"""

import json

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "cca0c0de0021"
down_revision = "cba0c0de0020"
branch_labels = None
depends_on = None

DEFAULTS = [
    ("agri", {"uz": "Qishloq xo‘jaligi", "ru": "Сельское хозяйство", "en": "Agriculture"}),
    ("livestock", {"uz": "Chorvachilik", "ru": "Животноводство", "en": "Livestock"}),
    ("machinery", {"uz": "Texnika", "ru": "Техника", "en": "Machinery"}),
    ("transport", {"uz": "Transport", "ru": "Транспорт", "en": "Transport"}),
    ("electronics", {"uz": "Elektronika", "ru": "Электроника", "en": "Electronics"}),
    ("construction", {"uz": "Qurilish", "ru": "Строительство", "en": "Construction"}),
]
IMAGE_PREFIX = "category_image:"


def upgrade() -> None:
    op.create_table(
        "categories",
        sa.Column("id", sa.String(40), nullable=False),
        sa.Column("name", postgresql.JSONB(), nullable=False),
        sa.Column("image", sa.Text(), nullable=True),
        sa.Column("is_active", sa.Boolean(), server_default="true", nullable=False),
        sa.Column("position", sa.Integer(), server_default="0", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint("id", name="pk_categories"),
    )

    bind = op.get_bind()
    for position, (tag, name) in enumerate(DEFAULTS):
        bind.execute(
            sa.text(
                "INSERT INTO categories (id, name, position) "
                "VALUES (:id, CAST(:name AS jsonb), :position)"
            ),
            {"id": tag, "name": json.dumps(name, ensure_ascii=False), "position": position},
        )

    # Yuklangan rasmlar sozlamadan ustunga.
    bind.execute(
        sa.text(
            "UPDATE categories c SET image = s.value FROM app_settings s "
            "WHERE s.key = :prefix || c.id"
        ),
        {"prefix": IMAGE_PREFIX},
    )
    bind.execute(
        sa.text("DELETE FROM app_settings WHERE key LIKE :pattern"),
        {"pattern": IMAGE_PREFIX + "%"},
    )

    # Enum → matn + tashqi kalit. Indeks ustunga bog'liq, shuning uchun qayta quriladi.
    op.drop_index("ix_listings_feed", table_name="listings")
    op.alter_column(
        "listings", "tag",
        type_=sa.String(40), postgresql_using="tag::text", existing_nullable=False,
    )
    op.alter_column(
        "desires", "category",
        type_=sa.String(40), postgresql_using="category::text", existing_nullable=True,
    )
    op.execute("DROP TYPE listing_tag")
    op.create_index("ix_listings_feed", "listings", ["status", "tag", "created_at"])
    op.create_foreign_key(
        "fk_listings_tag_categories", "listings", "categories", ["tag"], ["id"],
        onupdate="CASCADE", ondelete="RESTRICT",
    )
    op.create_foreign_key(
        "fk_desires_category_categories", "desires", "categories", ["category"], ["id"],
        onupdate="CASCADE", ondelete="SET NULL",
    )


def downgrade() -> None:
    # Admin qo'shgan kategoriyalar enum'ga sig'maydi: ulardagi e'lonlar
    # bo'lsa, qaytarish to'xtaydi — ma'lumotni jimgina buzgandan ko'ra yaxshi.
    tags = [tag for tag, _ in DEFAULTS]
    op.drop_constraint("fk_desires_category_categories", "desires", type_="foreignkey")
    op.drop_constraint("fk_listings_tag_categories", "listings", type_="foreignkey")
    op.drop_index("ix_listings_feed", table_name="listings")
    listing_tag = postgresql.ENUM(*tags, name="listing_tag")
    listing_tag.create(op.get_bind())
    op.execute(
        "UPDATE desires SET category = NULL WHERE category IS NOT NULL "
        "AND category NOT IN ('" + "','".join(tags) + "')"
    )
    op.alter_column(
        "listings", "tag",
        type_=listing_tag, postgresql_using="tag::listing_tag", existing_nullable=False,
    )
    op.alter_column(
        "desires", "category",
        type_=listing_tag, postgresql_using="category::listing_tag", existing_nullable=True,
    )
    op.create_index("ix_listings_feed", "listings", ["status", "tag", "created_at"])

    bind = op.get_bind()
    bind.execute(
        sa.text(
            "INSERT INTO app_settings (key, value) "
            "SELECT :prefix || id, image FROM categories WHERE image IS NOT NULL"
        ),
        {"prefix": IMAGE_PREFIX},
    )
    op.drop_table("categories")
