#!/usr/bin/env python3
"""Package HolyHim's "First Watch" library photos and bronze medallions.

Masters are HolyHer's generated originals, read from HolyHer's git history
(read-only, `git show`), so no 100 MB of masters is copied into HolyHim.
Each is regraded with tool/art/regrade.py and written at the sizes the app
expects. Five soft scenes (lilies, linen, window, garden) are not used; their
file names hold other regraded photographs until replaced one for one.

  python3 tool/art/package_first_watch.py [--holyher PATH] [--rev REV]
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageOps

sys.path.insert(0, str(Path(__file__).resolve().parent))
from regrade import regrade_medallion, regrade_photo  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
LIBRARY = ['jesus-dawn', 'jesus-seaside', 'jesus-shepherd', 'jesus-prayer', 'jesus-path',
           'sky-dawn', 'sky-rays', 'sky-stillness', 'sky-evening', 'sky-clouds',
           'cross-hill', 'cross-window', 'cross-meadow', 'cross-mountain', 'cross-stone',
           'scripture-morning', 'scripture-prayer', 'scripture-chapel', 'scripture-lamp', 'scripture-garden',
           'symbol-olive', 'symbol-dove', 'landscape-water', 'landscape-path', 'symbol-lilies']
# Asset name -> master actually used. Replace one for one with new art later.
ALIAS = {'scripture-morning': 'jesus-dawn', 'symbol-lilies': 'cross-mountain',
         'scripture-garden': 'jesus-seaside', 'cross-window': 'cross-hill', 'cross-meadow': 'cross-stone'}
# Medallion -> master actually used. The Day 30 crescent reads as another
# faith's symbol once it is plain bronze, so it borrows the streak design.
BADGE_ALIAS = {'days-030': 'streak-030'}
BADGES = ['days-001', 'days-003', 'days-007', 'days-014', 'days-021', 'days-030', 'days-050', 'days-075',
          'days-100', 'days-150', 'days-200', 'days-250', 'days-300', 'days-365', 'streak-007',
          'streak-030', 'streak-100', 'first-saved', 'promise-kept']


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def master(holyher: Path, rev: str, path: str) -> tuple[Image.Image, str]:
    raw = subprocess.run(['git', 'show', f'{rev}:{path}'], cwd=holyher, capture_output=True, check=True).stdout
    return Image.open(io.BytesIO(raw)), sha(raw)


def save(image: Image.Image, target: Path, **options) -> dict:
    target.parent.mkdir(parents=True, exist_ok=True)
    image.save(target, **options)
    return {'path': str(target.relative_to(ROOT)), 'sha256': sha(target.read_bytes())}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--holyher', type=Path, default=ROOT.parent / 'HolyHer')
    parser.add_argument('--rev', default='redesign/v2')
    args = parser.parse_args()
    rev = subprocess.run(['git', 'rev-parse', args.rev], cwd=args.holyher, capture_output=True, text=True,
                         check=True).stdout.strip()
    manifest = {'version': 1, 'grade': 'First Watch', 'mastersFrom': f'HolyHer {rev}', 'library': [], 'badges': []}
    graded: dict[str, Image.Image] = {}
    for name in LIBRARY:
        source = ALIAS.get(name, name)
        if source not in graded:
            image, digest = master(args.holyher, rev, f'art/generated/library/{source}.png')
            graded[source] = ImageOps.fit(regrade_photo(image), (1024, 1536), method=Image.Resampling.LANCZOS)
            graded[source].info['master'] = digest
        photo = graded[source]
        out = ROOT / 'assets/art/library'
        row = {'id': name, 'source': source, 'masterSha256': photo.info['master'],
               'asset': save(photo, out / f'{name}.webp', format='WEBP', quality=86, method=6)}
        thumb = ImageOps.fit(photo, (240, 360), method=Image.Resampling.LANCZOS)
        row['thumb'] = save(thumb, out / f'{name}-thumb.webp', format='WEBP', quality=80, method=6)
        row['widget'] = save(thumb, ROOT / 'ios/HolyHimWidget/Art' / f'{name}-thumb.jpg',
                             format='JPEG', quality=83, optimize=True)
        manifest['library'].append(row)
    for name in BADGES:
        image, digest = master(args.holyher, rev, f"art/generated/badges/{BADGE_ALIAS.get(name, name)}.png")
        bronze = regrade_medallion(image)
        bronze = bronze.crop(bronze.getchannel('A').getbbox())
        bronze.thumbnail((820, 820), Image.Resampling.LANCZOS)
        canvas = Image.new('RGBA', (1024, 1024))
        canvas.alpha_composite(bronze, ((1024 - bronze.width) // 2, (1024 - bronze.height) // 2))
        out = ROOT / 'assets/art/badges'
        manifest['badges'].append({
            'id': name, 'masterSha256': digest,
            'asset': save(canvas, out / f'{name}.png', format='PNG', optimize=True),
            'thumb': save(canvas.resize((240, 240), Image.Resampling.LANCZOS), out / f'{name}-thumb.png',
                          format='PNG', optimize=True)})
    for stale in (ROOT / 'ios/HolyHimWidget/Art').glob('unit-*-thumb.jpg'):
        stale.unlink()
    (ROOT / 'art').mkdir(exist_ok=True)
    (ROOT / 'art/first-watch-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f"Packaged {len(manifest['library'])} photos ({len(graded)} masters) and "
          f"{len(manifest['badges'])} medallions from HolyHer {rev[:7]}.")


if __name__ == '__main__':
    main()
