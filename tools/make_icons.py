"""BarterApp ilova ikonkasi — brend belgisi, kodda chizilgan.

Ikkilikda saqlangan PNG kerak (do'konlar shuni talab qiladi), lekin uni
qo'lda chizish o'rniga shu skript yasaydi: rang yoki shakl o'zgarsa,
skriptni qayta yurgizish kifoya.
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

GIVE = (20, 168, 107)   # brand500
TAKE = (59, 118, 240)   # take500
S = 1024                # eng katta o'lcham, qolgani shundan kichraytiriladi
SS = 4                  # supersampling


def gradient(size):
    """give → take, diagonal bo'ylab."""
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * size - 2)
            px[x, y] = tuple(round(GIVE[i] + (TAKE[i] - GIVE[i]) * t) for i in range(3))
    return img


def star(draw, cx, cy, outer, inner, colour, width):
    pts = []
    for i in range(16):
        r = outer if i % 2 == 0 else inner
        a = -math.pi / 2 + i * math.pi / 8
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    draw.polygon(pts, outline=colour, width=width)


def arrow(draw, y, x0, x1, colour, width, head):
    """A rounded shaft with a solid head.

    Drawn as shapes rather than strokes: at icon sizes a stroked arrowhead
    leaves ragged corners where the two lines meet, and every store renders
    this at a dozen resolutions.
    """
    d = 1 if x1 > x0 else -1
    tip = x1
    base = x1 - d * head
    half = width / 2

    draw.rounded_rectangle(
        [min(x0, base), y - half, max(x0, base), y + half],
        radius=half,
        fill=colour,
    )
    draw.polygon(
        [(tip, y), (base, y - head * 0.86), (base, y + head * 0.86)],
        fill=colour,
    )


def build(size, scale=1.0):
    """
    The icon at `size` pixels. `scale` shrinks the mark without shrinking the
    background — what a maskable icon needs, since the launcher crops it to a
    circle and would otherwise cut the arrowheads off.
    """
    n = size * SS
    img = gradient(n).convert("RGBA")
    d = ImageDraw.Draw(img)

    # No tilework here. It belongs on a full screen, where there is room to
    # notice it; at 40 pixels on a home screen it collides with the mark and
    # both turn to mud. The gradient and the two arrows are the brand.

    # Kept well inside the square — every platform crops this differently, and
    # iOS rounds the corners hard.
    def s(fraction):
        """A fraction of the square, pulled toward the centre by `scale`."""
        return n * (0.5 + (fraction - 0.5) * scale)

    w = n * 0.075 * scale
    head = n * 0.105 * scale
    white = (255, 255, 255, 255)
    arrow(d, s(0.395), s(0.265), s(0.735), white, w, head)
    arrow(d, s(0.605), s(0.735), s(0.265), white, w, head)

    return img.resize((size, size), Image.LANCZOS)





# ─────────────────────────────────────────────────────────────────────────────
# Every size each platform asks for
# ─────────────────────────────────────────────────────────────────────────────

IOS = {
    "Icon-App-1024x1024@1x.png": 1024,
    "Icon-App-20x20@1x.png": 20, "Icon-App-20x20@2x.png": 40, "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29, "Icon-App-29x29@2x.png": 58, "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40, "Icon-App-40x40@2x.png": 80, "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120, "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76, "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
}

ANDROID = {
    "mipmap-mdpi": 48, "mipmap-hdpi": 72, "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144, "mipmap-xxxhdpi": 192,
}


def maskable(size):
    """
    Android and the PWA installer crop this to a circle, keeping roughly the
    middle 80%. Only the mark shrinks — compositing a scaled-down copy over the
    full-bleed background left a visible square seam where the two gradients,
    running at different rates, met.
    """
    return build(size, scale=0.66)


def write_all(root: Path):
    ios = root / "app/ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for name, size in IOS.items():
        # iOS forbids alpha in app icons; the gradient is opaque anyway.
        build(size).convert("RGB").save(ios / name)

    for folder, size in ANDROID.items():
        target = root / "app/android/app/src/main/res" / folder / "ic_launcher.png"
        build(size).save(target)

    web = root / "app/web/icons"
    build(192).save(web / "Icon-192.png")
    build(512).save(web / "Icon-512.png")
    maskable(192).save(web / "Icon-maskable-192.png")
    maskable(512).save(web / "Icon-maskable-512.png")
    build(32).save(root / "app/web/favicon.png")

    print(f"  iOS {len(IOS)} · Android {len(ANDROID)} · web 5")


if __name__ == "__main__":
    write_all(Path(__file__).resolve().parents[1])
