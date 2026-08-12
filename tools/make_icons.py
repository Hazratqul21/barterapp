"""BarterApp ilova ikonkasi — light brend belgisi, kodda chizilgan.

Ikkilikda saqlangan PNG kerak (do'konlar shuni talab qiladi), lekin uni
qo'lda chizish o'rniga shu skript yasaydi: rang yoki shakl o'zgarsa,
skriptni qayta yurgizish kifoya.
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

SURFACE = (249, 252, 250)
INK = (18, 59, 49)
HAIR = (217, 230, 223)
S = 1024                # eng katta o'lcham, qolgani shundan kichraytiriladi
SS = 4                  # supersampling


def arrow(draw, points, colour, width):
    """Rounded segment plus a crisp arrowhead for the circular swap mark."""
    draw.line(points[:-1], fill=colour, width=width, joint="curve")
    tip, base = points[-1], points[-2]
    dx, dy = tip[0] - base[0], tip[1] - base[1]
    length = math.hypot(dx, dy)
    nx, ny = -dy / length, dx / length
    head = width * 1.35
    draw.polygon([tip, (base[0] + nx * head * .65, base[1] + ny * head * .65),
                   (base[0] - nx * head * .65, base[1] - ny * head * .65)], fill=colour)


def build(size, scale=1.0):
    """
    The icon at `size` pixels. `scale` shrinks the mark without shrinking the
    background — what a maskable icon needs, since the launcher crops it to a
    circle and would otherwise cut the arrowheads off.
    """
    n = size * SS
    img = Image.new("RGBA", (n, n), SURFACE + (255,))
    d = ImageDraw.Draw(img)

    # Light app tile with two curved arrows, matching the in-app brand mark.
    def s(fraction):
        """A fraction of the square, pulled toward the centre by `scale`."""
        return n * (0.5 + (fraction - 0.5) * scale)

    inset = n * .10
    d.rounded_rectangle([inset, inset, n - inset, n - inset], radius=n * .23,
                        outline=HAIR + (255,), width=max(1, n // 180))
    w = int(n * 0.085 * scale)
    ink = INK + (255,)
    arrow(d, [(s(.31), s(.58)), (s(.31), s(.38)), (s(.50), s(.38)), (s(.67), s(.38))], ink, w)
    arrow(d, [(s(.69), s(.42)), (s(.69), s(.62)), (s(.50), s(.62)), (s(.33), s(.62))], ink, w)

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
