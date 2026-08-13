"""Reclaiming disk from photos nothing points at any more.

Every uploaded photo lands as a file in `media_root` and is *then* referenced by
a row — a listing photo, an avatar, a chat photo. The two steps are not one
transaction: a person can upload a photo and never finish the listing, or
replace an avatar and leave the old file behind. Nothing deletes those files, so
the directory only ever grows.

This is the local-disk equivalent of an S3 lifecycle rule: list what the
database still points at, and remove the files it does not — but only files old
enough that they cannot be an upload still on its way to becoming a row.
"""

from __future__ import annotations

import time
from dataclasses import dataclass
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.listing import ListingPhoto
from app.models.offer import Message
from app.models.social import Notification
from app.models.user import User

#: An upload becomes a row within seconds. A file younger than this might be one
#: of those in-flight uploads, so it is left alone no matter what — the sweep
#: must never race a `create_listing` that has written the file but not the row.
DEFAULT_GRACE_SECONDS = 6 * 3600


def _local_name(url: str | None) -> str | None:
    """The on-disk filename a media URL points at, or None if it is not one of
    ours. Seed and category photos are absolute Unsplash URLs; they share no
    filename with anything in `media_root`, so they simply never match."""
    if not url:
        return None
    marker = settings.media_url_prefix.rstrip("/") + "/"
    idx = url.find(marker)
    if idx == -1:
        return None
    name = url[idx + len(marker):].split("?", 1)[0].split("/", 1)[0]
    return name or None


async def referenced_names(db: AsyncSession) -> set[str]:
    """Every media filename the database still points at."""
    columns = (
        ListingPhoto.url,
        User.avatar_url,
        Message.photo_url,
        Notification.avatar_url,
    )
    names: set[str] = set()
    for column in columns:
        for url in (await db.scalars(select(column).where(column.is_not(None)))).all():
            name = _local_name(url)
            if name is not None:
                names.add(name)
    return names


@dataclass
class SweepReport:
    scanned: int
    kept_referenced: int
    kept_young: int
    removed: list[str]
    freed_bytes: int

    @property
    def removed_count(self) -> int:
        return len(self.removed)


async def sweep_orphans(
    db: AsyncSession,
    *,
    grace_seconds: int = DEFAULT_GRACE_SECONDS,
    dry_run: bool = False,
) -> SweepReport:
    """Delete files in `media_root` that no row references and that are older
    than `grace_seconds`. With `dry_run` the files are only listed, not touched.
    """
    root: Path = settings.media_root
    referenced = await referenced_names(db)
    now = time.time()

    scanned = kept_referenced = kept_young = 0
    removed: list[str] = []
    freed = 0

    if not root.exists():
        return SweepReport(0, 0, 0, [], 0)

    for path in root.iterdir():
        if not path.is_file():
            continue
        scanned += 1
        if path.name in referenced:
            kept_referenced += 1
            continue
        if now - path.stat().st_mtime < grace_seconds:
            kept_young += 1
            continue
        size = path.stat().st_size
        if not dry_run:
            path.unlink()
        removed.append(path.name)
        freed += size

    return SweepReport(scanned, kept_referenced, kept_young, removed, freed)
