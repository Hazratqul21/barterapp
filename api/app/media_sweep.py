"""Delete uploaded photos that no row points at any more.

    python -m app.media_sweep              # delete orphans older than 6h
    python -m app.media_sweep --dry-run    # list them, delete nothing
    python -m app.media_sweep --grace-hours 24

Run it on a schedule (cron, a systemd timer) the way an S3 bucket runs a
lifecycle rule. See `app.services.media` for what "orphan" means and why the
grace window exists.
"""

from __future__ import annotations

import argparse
import asyncio

from app.db.session import SessionLocal
from app.services.media import DEFAULT_GRACE_SECONDS, sweep_orphans


async def _run(grace_seconds: int, dry_run: bool) -> None:
    async with SessionLocal() as db:
        report = await sweep_orphans(
            db, grace_seconds=grace_seconds, dry_run=dry_run
        )
    verb = "would remove" if dry_run else "removed"
    freed_kb = report.freed_bytes / 1024
    print(
        f"scanned {report.scanned}, "
        f"kept {report.kept_referenced} referenced + {report.kept_young} recent, "
        f"{verb} {report.removed_count} ({freed_kb:.0f} KB)"
    )
    for name in report.removed:
        print(f"  {verb}: {name}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--grace-hours",
        type=float,
        default=DEFAULT_GRACE_SECONDS / 3600,
        help="Leave files younger than this untouched (default: 6).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="List what would be removed without deleting anything.",
    )
    args = parser.parse_args()
    asyncio.run(_run(int(args.grace_hours * 3600), args.dry_run))


if __name__ == "__main__":
    main()
