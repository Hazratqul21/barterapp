from __future__ import annotations

from fastapi import Header

from app.core.config import settings


def resolve_locale(accept_language: str | None = Header(default=None)) -> str:
    """
    Pick one of the three supported languages from `Accept-Language`.

    The API always answers in exactly one language: the client never receives all
    three and picks at render time, which is what let the prototype ship a screen
    showing Cyrillic and Latin names side by side.
    """
    if not accept_language:
        return settings.default_locale

    for part in accept_language.split(","):
        tag = part.split(";")[0].strip().lower()
        primary = tag.split("-")[0]
        if primary in settings.supported_locales:
            return primary
    return settings.default_locale
