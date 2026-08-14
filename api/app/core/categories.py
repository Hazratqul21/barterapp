"""The six things this marketplace trades in, named in all three languages.

Served rather than compiled into the app, for the same reason the region list
is: a renamed category or a corrected spelling should not need a release on
three platforms. The clients had been shipping their own copy of this list —
with hardcoded Uzbek names and photo URLs that had rotted to 404 — which is
exactly the drift this endpoint removes.

The ids are the `ListingTag` values, so a category id can be handed straight
back as the `tag` filter on `/listings` with nothing to translate in between.
"""

from __future__ import annotations

from app.models.listing import ListingTag

#: name per locale, then the photograph that fronts the category.
#:
#: The pictures are stable Unsplash ids chosen to read at tile size — a field,
#: a herd, a tractor — because the tile carries no icon and the photograph is
#: what names the category at a glance.
_CATEGORIES: dict[ListingTag, tuple[dict[str, str], str]] = {
    ListingTag.agri: (
        {"uz": "Qishloq xo‘jaligi", "ru": "Сельское хозяйство", "en": "Agriculture"},
        "https://images.unsplash.com/photo-1560493676-04071c5f467b",
    ),
    ListingTag.livestock: (
        {"uz": "Chorvachilik", "ru": "Животноводство", "en": "Livestock"},
        "https://images.unsplash.com/photo-1516467508483-a7212febe31a",
    ),
    ListingTag.machinery: (
        {"uz": "Texnika", "ru": "Техника", "en": "Machinery"},
        "https://images.unsplash.com/photo-1504307651254-35680f356dfd",
    ),
    ListingTag.transport: (
        {"uz": "Transport", "ru": "Транспорт", "en": "Transport"},
        "https://images.unsplash.com/photo-1601584115197-04ecc0da31d7",
    ),
    ListingTag.electronics: (
        {"uz": "Elektronika", "ru": "Электроника", "en": "Electronics"},
        "https://images.unsplash.com/photo-1518770660439-4636190af475",
    ),
    ListingTag.construction: (
        {"uz": "Qurilish", "ru": "Строительство", "en": "Construction"},
        "https://images.unsplash.com/photo-1518709268805-4e9042af9f23",
    ),
}

#: Cropped and format-negotiated at the source, so a phone on mobile data is not
#: handed a full-resolution photograph for a 118px tile.
_IMAGE_PARAMS = "?w=400&h=520&fit=crop&auto=format"


def categories(locale: str) -> list[dict[str, str]]:
    """The category list, already in one language — never all three at once."""
    return [
        {
            "id": tag.value,
            "name": names.get(locale, names["uz"]),
            "image_url": photo + _IMAGE_PARAMS,
        }
        for tag, (names, photo) in _CATEGORIES.items()
    ]
