from __future__ import annotations

#: Uzbekistan's fourteen regions, each with the coordinates of its capital.
#:
#: Distance is 30% of a match score, and until now nothing could set a user's
#: coordinates: `MeUpdate` had `region` as free text and no latitude at all, so
#: `location_score` fell back to its 0.5 "unknown" value for every account that
#: was not seeded. Everyone scored the same on distance, which is the same as
#: the signal not existing.
#:
#: A capital's coordinates are coarse — a farm outside Jomboy is not in the
#: centre of Samarqand — but the score only needs to tell "same region" from
#: "the other end of the country", and at that scale it does. A precise
#: location can replace this later without the matcher changing at all.
REGION_CENTROIDS: dict[str, tuple[float, float]] = {
    "Qoraqalpog‘iston": (42.4531, 59.6103),   # Nukus
    "Andijon": (40.7821, 72.3442),
    "Buxoro": (39.7681, 64.4556),
    "Farg‘ona": (40.3894, 71.7864),
    "Jizzax": (40.1158, 67.8422),
    "Xorazm": (41.5500, 60.6333),             # Urganch
    "Namangan": (40.9983, 71.6726),
    "Navoiy": (40.0844, 65.3792),
    "Qashqadaryo": (38.8610, 65.7887),        # Qarshi
    "Samarqand": (39.6270, 66.9750),
    "Sirdaryo": (40.3833, 68.6500),           # Guliston
    "Surxondaryo": (37.2242, 67.2783),        # Termiz
    "Toshkent viloyati": (41.0000, 69.6000),
    "Toshkent shahri": (41.2995, 69.2401),
}

#: Accepted spellings, folded to the canonical key. The client sends the exact
#: string it was given, but a listing seeded by hand or imported from elsewhere
#: may use an apostrophe variant or the Russian name.
_ALIASES: dict[str, str] = {
    "qoraqalpogiston": "Qoraqalpog‘iston",
    "qoraqalpog'iston": "Qoraqalpog‘iston",
    "karakalpakstan": "Qoraqalpog‘iston",
    "каракалпакстан": "Qoraqalpog‘iston",
    "fargona": "Farg‘ona",
    "farg'ona": "Farg‘ona",
    "fergana": "Farg‘ona",
    "фергана": "Farg‘ona",
    "andijan": "Andijon",
    "андижан": "Andijon",
    "bukhara": "Buxoro",
    "бухара": "Buxoro",
    "jizzakh": "Jizzax",
    "джизак": "Jizzax",
    "khorezm": "Xorazm",
    "хорезм": "Xorazm",
    "наманган": "Namangan",
    "навои": "Navoiy",
    "kashkadarya": "Qashqadaryo",
    "кашкадарья": "Qashqadaryo",
    "samarkand": "Samarqand",
    "самарканд": "Samarqand",
    "syrdarya": "Sirdaryo",
    "сырдарья": "Sirdaryo",
    "surkhandarya": "Surxondaryo",
    "сурхандарья": "Surxondaryo",
    "tashkent region": "Toshkent viloyati",
    "ташкентская область": "Toshkent viloyati",
    "tashkent": "Toshkent shahri",
    "ташкент": "Toshkent shahri",
}


def coordinates_for(region: str | None) -> tuple[float, float] | None:
    """The capital's coordinates for a region name, or None if it is unknown."""
    if not region:
        return None

    if region in REGION_CENTROIDS:
        return REGION_CENTROIDS[region]

    folded = region.strip().lower().replace("‘", "'")
    canonical = _ALIASES.get(folded) or _ALIASES.get(folded.replace("'", ""))
    return REGION_CENTROIDS.get(canonical) if canonical else None


def region_names() -> list[str]:
    """The canonical list, for a client that wants to offer a choice."""
    return list(REGION_CENTROIDS)
