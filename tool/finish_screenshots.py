#!/usr/bin/env python3
"""Flatten the rendered App Store screenshots to RGB, check their size and
write the manifest and a contact sheet.

Run after: flutter test tool/render/store_test.dart
"""
from pathlib import Path
import json
import sys
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SHOTS = ROOT / 'store/screenshots/app-store/iphone-1290x2796'
REVIEW = ROOT / 'store/iap-review/offer.png'
SIZE = (1290, 2796)


def flatten(path: Path, target: Path) -> dict:
    image = Image.open(path)
    if image.size != SIZE:
        sys.exit(f'{path.name}: {image.size}, expected {SIZE}')
    rgb = Image.new('RGB', image.size, (255, 255, 255))
    rgb.paste(image, mask=image.getchannel('A') if image.mode == 'RGBA' else None)
    target.parent.mkdir(parents=True, exist_ok=True)
    rgb.save(target, optimize=True)
    return {'file': str(target.relative_to(ROOT)), 'width': SIZE[0],
            'height': SIZE[1], 'mode': 'RGB', 'bytes': target.stat().st_size}


def main() -> None:
    shots = sorted(SHOTS.glob('0*.png'))
    if not 3 <= len(shots) <= 10:
        sys.exit(f'App Store accepts 3 to 10 screenshots; found {len(shots)}')
    manifest = [flatten(p, p) for p in shots]
    review = SHOTS / 'iap-review-offer.png'
    if review.exists():
        flatten(review, REVIEW)
        review.unlink()
    (ROOT / 'store/screenshots/manifest.json').write_text(
        json.dumps(manifest, indent=2) + '\n')
    thumbs = [Image.open(p).resize((430, 932)) for p in shots]
    sheet = Image.new('RGB', (len(thumbs) * 450 - 20, 932), (255, 255, 255))
    for i, thumb in enumerate(thumbs):
        sheet.paste(thumb, (i * 450, 0))
    sheet.save(ROOT / 'store/screenshots/overview.jpg', quality=82)
    print(f'{len(manifest)} screenshots at {SIZE[0]}x{SIZE[1]} RGB; '
          f'review screenshot at {REVIEW.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
