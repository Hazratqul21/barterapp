"""Package the supplied MAB artwork into platform-required sizes.

No redrawing or recolouring: keep the original asset and letter proportions.
App Store icons are RGB, full-bleed squares without baked-in rounded corners.
"""
from pathlib import Path
from PIL import Image
from make_icons import IOS, ANDROID

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'app/assets/brand/mab-logo.png'


def icon(size, fraction=0.86):
    artwork = Image.open(SOURCE).convert('RGBA')
    artwork.thumbnail((round(size * fraction), round(size * fraction)), Image.Resampling.LANCZOS)
    tile = Image.new('RGBA', (size, size), (250, 248, 244, 255))
    tile.alpha_composite(artwork, ((size - artwork.width) // 2, (size - artwork.height) // 2))
    return tile.convert('RGB')


def main():
    for name, size in IOS.items():
        icon(size).save(ROOT / 'app/ios/Runner/Assets.xcassets/AppIcon.appiconset' / name)
    for folder, size in ANDROID.items():
        icon(size, 0.7).save(ROOT / 'app/android/app/src/main/res' / folder / 'ic_launcher.png')
    for size in (192, 512):
        icon(size).save(ROOT / f'app/web/icons/Icon-{size}.png')
        icon(size, 0.7).save(ROOT / f'app/web/icons/Icon-maskable-{size}.png')
    icon(32).save(ROOT / 'app/web/favicon.png')
    for scale in (1, 2, 3):
        artwork = Image.open(SOURCE).convert('RGBA')
        artwork.thumbnail((250 * scale, 100 * scale), Image.Resampling.LANCZOS)
        suffix = '' if scale == 1 else f'@{scale}x'
        artwork.save(ROOT / f'app/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage{suffix}.png')
    print('MAB assets packaged: iOS, Android, web, native launch screen')


if __name__ == '__main__':
    main()
