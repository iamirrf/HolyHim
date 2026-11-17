"""Render the App Store product page header and search results assets.

The art is Gemini's (art/generated/store/*-epic-*.jpeg, in the library style
of art/redesign-prompts.json). This script scales and grades it, then
tool/render/creative_test.dart sets the words in HolyHim's own fonts, lit
with a gradient fill and a halo of glow and bloom, and this script writes
the PNGs App Store Connect takes for these assets (it accepts no JPEG here).

Each phrase sits inside Apple's art safe area for its size
(developer.apple.com/help/app-store-connect/reference/app-information/
creative-assets-specifications):

  header          3840 x 1646 (21:9)  safe 1646 x 661 at (1097, 493)
  search results  3840 x 2560 (3:2)   safe 2168 x 1030 at (836, 765)

Search results is set at its largest size and delivered at 1920 x 1280,
Apple's smallest: the art holds about 2500 pixels of real detail across,
and the smaller file uploads well.

  python3 tool/art/store_creative.py
writes store/creative/header-3840x1646.png and
store/creative/search-1920x1280.png (RGB, sRGB, no alpha).
"""
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageCms, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'art/generated/store'
WORK = ROOT / 'build/creative'
OUT = ROOT / 'store/creative'

# name: (art, set size, crop anchor x/y from 0 = top-left to 1 = bottom-right,
#        delivered file and size)
ASSETS = {
    'header-3840x1646': ('header-epic-21x9.jpeg', (3840, 1646), (0.5, 0.5),
                         'header-3840x1646.png', (3840, 1646)),
    'search-3840x2560': ('search-epic-3x2.jpeg', (3840, 2560), (0.5, 0.5),
                         'search-1920x1280.png', (1920, 1280)),
}
NAVY = np.array([6, 10, 16], np.float32) / 255


def cover(art, size, anchor):
    """The art scaled to cover the canvas with Lanczos, lightly sharpened."""
    w, h = size
    with Image.open(ART / art) as source:
        source = source.convert('RGB')
        scale = max(w / source.width, h / source.height)
        scaled = source.resize((round(source.width * scale),
                                round(source.height * scale)), Image.LANCZOS)
    left = round((scaled.width - w) * anchor[0])
    top = round((scaled.height - h) * anchor[1])
    canvas = scaled.crop((left, top, left + w, top + h))
    return canvas.filter(ImageFilter.UnsharpMask(radius=2.2, percent=55, threshold=2))


def grade(image):
    """A cinematic grade: deep navy corners, a little weight at top and foot."""
    a = np.asarray(image, dtype=np.float32) / 255
    h, w = a.shape[:2]
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    nx, ny = (x / w - 0.5) / 0.5, (y / h - 0.54) / 0.5
    d = np.sqrt((nx / 0.84) ** 2 + (ny / 0.96) ** 2)
    corners = np.clip((d - 0.55) / 0.6, 0, 1) ** 1.6 * 0.6
    top = np.clip(1 - (y / h) / 0.3, 0, 1) * 0.42
    foot = np.clip(((y / h) - 0.76) / 0.24, 0, 1) * 0.34
    dark = (1 - (1 - corners) * (1 - top) * (1 - foot))[..., None]
    out = a * (1 - dark) + NAVY * dark
    return Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8))


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (art, size, anchor, _, _) in ASSETS.items():
        grade(cover(art, size, anchor)).save(WORK / f'{name}-graded.png')
    subprocess.run(['flutter', 'test', 'tool/render/creative_test.dart'],
                   cwd=ROOT, check=True)
    srgb = ImageCms.ImageCmsProfile(ImageCms.createProfile('sRGB')).tobytes()
    for name, (_, size, _, file, delivered) in ASSETS.items():
        with Image.open(WORK / f'{name}-type.png') as typed:
            if typed.size != size:
                raise SystemExit(f'{name}: rendered {typed.size}, expected {size}')
            final = typed.convert('RGB')
        if delivered != size:
            final = final.resize(delivered, Image.LANCZOS)
        target = OUT / file
        final.save(target, 'PNG', optimize=True, compress_level=9, icc_profile=srgb)
        print(f'{target.relative_to(ROOT)}  {final.size[0]}x{final.size[1]}  '
              f'{target.stat().st_size / 1e6:.1f} MB')


if __name__ == '__main__':
    main()
