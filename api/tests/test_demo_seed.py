"""Demo ma'lumotlar: qo'shiladi, qayta ishga tushirilsa takrorlanmaydi,
`--remove` faqat demo hisoblarni olib tashlaydi — haqiqiy e'lonlar qoladi."""

import subprocess
import sys
from pathlib import Path

import httpx

BASE = "http://127.0.0.1:8010"
API = Path(__file__).resolve().parent.parent


def check(label: str, ok: bool, extra: str = "") -> None:
    print(f"{'PASS' if ok else 'FAIL'}  {label}" + (f"  — {extra}" if extra else ""))
    if not ok:
        raise SystemExit(1)


def seed(*args: str) -> None:
    subprocess.run([sys.executable, "-m", "app.demo_seed", *args], cwd=API, check=True)


def demo_titles(c: httpx.Client) -> list[str]:
    items = c.get("/listings", params={"limit": 50}, headers={"Accept-Language": "uz"}).json()
    items = items["items"] if isinstance(items, dict) else items
    return [i["title"] for i in items]


with httpx.Client(base_url=BASE, timeout=30) as c:
    seed("--remove")
    before = demo_titles(c)
    check("demo yo'q holatda boshlandi", "MTZ-82.1 traktor, 2018" not in before)

    seed("--no-photos")
    after = demo_titles(c)
    check("demo e'lonlar lentada", "MTZ-82.1 traktor, 2018" in after and len(after) > len(before),
          f"{len(before)} → {len(after)}")
    def count(tag: str) -> int:
        body = c.get("/listings", params={"tag": tag}).json()
        return len(body["items"] if isinstance(body, dict) else body)

    empty = [tag for tag in ("agri", "livestock", "machinery", "transport", "electronics",
                             "construction") if count(tag) == 0]
    check("har bir kategoriyada e'lon bor", not empty, str(empty))

    seed("--no-photos")
    check("qayta ishga tushirish takrorlamaydi", len(demo_titles(c)) == len(after))

    seed("--remove")
    check("--remove faqat demoni olib tashlaydi", sorted(demo_titles(c)) == sorted(before))

print("\nHammasi o'tdi.")
