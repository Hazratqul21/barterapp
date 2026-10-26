"""The six things this marketplace trades in, named in all three languages.

Served rather than compiled into the app, for the same reason the region list
is: a renamed category or a corrected spelling should not need a release on
three platforms.

The ids are the `ListingTag` values, so a category id can be handed straight
back as the `tag` filter on `/listings` with nothing to translate in between.

Pictures: the apps carry a bundled picture per category, and the admin panel
can replace any of them (`/admin/categories`). `image_url` is that uploaded
picture, or null when the bundled one should show. The old Unsplash links are
gone: they were never shown by the apps and had already started to rot.
"""

from __future__ import annotations

from app.models.listing import ListingTag

#: The setting that holds a category's uploaded picture, as a path under
#: `media_root` (`categories/<tag>-<hex>.jpg`).
IMAGE_SETTING_PREFIX = "category_image:"

CATEGORY_NAMES: dict[ListingTag, dict[str, str]] = {
    ListingTag.agri: {"uz": "Qishloq xo‘jaligi", "ru": "Сельское хозяйство", "en": "Agriculture"},
    ListingTag.livestock: {"uz": "Chorvachilik", "ru": "Животноводство", "en": "Livestock"},
    ListingTag.machinery: {"uz": "Texnika", "ru": "Техника", "en": "Machinery"},
    ListingTag.transport: {"uz": "Transport", "ru": "Транспорт", "en": "Transport"},
    ListingTag.electronics: {"uz": "Elektronika", "ru": "Электроника", "en": "Electronics"},
    ListingTag.construction: {"uz": "Qurilish", "ru": "Строительство", "en": "Construction"},
}


def image_setting(tag: ListingTag) -> str:
    return IMAGE_SETTING_PREFIX + tag.value


def categories(locale: str, images: dict[str, str] | None = None) -> list[dict[str, str | None]]:
    """The category list, already in one language — never all three at once.

    `images` maps a tag to the absolute URL of its uploaded picture.
    """
    images = images or {}
    return [
        {
            "id": tag.value,
            "name": names.get(locale, names["uz"]),
            "image_url": images.get(tag.value),
        }
        for tag, names in CATEGORY_NAMES.items()
    ]
