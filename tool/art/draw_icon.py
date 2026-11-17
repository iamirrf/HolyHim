#!/usr/bin/env python3
"""Draw HolyHim's icon: a brass cross above a line of first light, on
charcoal-navy. Rendered at 4x and reduced, so every edge is clean. Writes
the 1024 master and every iOS size listed in the app icon set, plus the
brand mark and the website icon.

The same drawing in each theme's colours makes the alternate icons
(PALETTES, used by tool/art/app_icons.py). First Watch is the primary icon
and its numbers are the original ones, so it redraws identically.

  python3 tool/art/draw_icon.py
"""
from __future__ import annotations
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
S = 4096


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(len(a)))


# Each theme's light: the sky top to bottom, the glow at the horizon and how
# much of it shows, the ground, the horizon line, the cross's metal (light
# to deep), the shadow under it, and stars for the night themes.
PALETTES = {
    'first-watch': dict(top=(9, 12, 17), bottom=(24, 31, 42), warm=(216, 166, 87), glow=.55,
                        ground=(10, 13, 18), groundMix=.62, light=(246, 214, 150),
                        hi=(243, 205, 132), lo=(170, 118, 52), shadow=.55, stars=0),
    'limestone': dict(top=(246, 244, 240), bottom=(222, 219, 212), warm=(226, 200, 158), glow=.42,
                      ground=(204, 200, 191), groundMix=.55, light=(150, 104, 44),
                      hi=(104, 112, 124), lo=(31, 38, 48), shadow=.30, stars=0),
    'iron': dict(top=(12, 13, 14), bottom=(36, 38, 41), warm=(176, 182, 190), glow=.42,
                 ground=(11, 12, 13), groundMix=.62, light=(226, 230, 235),
                 hi=(236, 239, 242), lo=(122, 128, 136), shadow=.55, stars=0),
    'ember': dict(top=(15, 10, 7), bottom=(42, 26, 16), warm=(232, 140, 68), glow=.58,
                  ground=(13, 9, 6), groundMix=.62, light=(255, 196, 132),
                  hi=(250, 198, 142), lo=(166, 86, 38), shadow=.55, stars=0),
    'sandstone': dict(top=(249, 242, 230), bottom=(229, 211, 184), warm=(236, 190, 128), glow=.50,
                      ground=(212, 192, 162), groundMix=.55, light=(166, 104, 50),
                      hi=(164, 106, 52), lo=(98, 58, 26), shadow=.30, stars=0),
    'cedar': dict(top=(9, 15, 12), bottom=(27, 42, 33), warm=(205, 176, 119), glow=.50,
                  ground=(9, 14, 11), groundMix=.62, light=(236, 216, 160),
                  hi=(238, 222, 178), lo=(146, 118, 60), shadow=.55, stars=0),
    'midnight': dict(top=(6, 9, 20), bottom=(22, 32, 64), warm=(130, 164, 240), glow=.42,
                     ground=(6, 9, 19), groundMix=.62, light=(212, 226, 255),
                     hi=(232, 238, 255), lo=(118, 136, 190), shadow=.55, stars=18),
    'slate': dict(top=(241, 244, 247), bottom=(204, 214, 224), warm=(176, 198, 222), glow=.50,
                  ground=(190, 201, 213), groundMix=.55, light=(45, 90, 134),
                  hi=(64, 98, 136), lo=(26, 40, 56), shadow=.30, stars=0),
}


def master(palette: str = 'first-watch') -> Image.Image:
    p = PALETTES[palette]
    y = np.linspace(0, 1, S, dtype=np.float32)[:, None]
    x = np.linspace(0, 1, S, dtype=np.float32)[None, :]
    top, bottom = np.array(p['top'], np.float32), np.array(p['bottom'], np.float32)
    base = top + (bottom - top) * y[..., None]
    horizon = .695
    # First light: a wide warm glow centred on the horizon below the cross.
    glow = np.exp(-(((x - .5) / .42) ** 2) - (((y - horizon) / .11) ** 2))
    warm = np.array(p['warm'], np.float32)
    img = base * (1 - glow[..., None] * p['glow']) + warm * (glow[..., None] * p['glow'])
    # Ground below the horizon stays dark and cool.
    ground = np.clip((y - horizon) / .012, 0, 1)
    img = img * (1 - ground[..., None] * p['groundMix']) + np.array(p['ground'], np.float32) * (ground[..., None] * p['groundMix'])
    if p['stars']:
        img = _stars(img, horizon, p['stars'])
    canvas = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).convert('RGBA')
    d = ImageDraw.Draw(canvas)
    # The horizon line itself, bright at the centre and fading to the edges.
    line = Image.new('L', (S, S), 0)
    ld = ImageDraw.Draw(line)
    hy = int(S * horizon)
    ld.rectangle([0, hy - int(S * .0045), S, hy + int(S * .0045)], fill=255)
    fade = (np.exp(-(((np.linspace(0, 1, S) - .5) / .24) ** 2)) * 255).astype(np.uint8)
    line = Image.fromarray((np.asarray(line, np.float32) * fade[None, :] / 255).astype(np.uint8))
    light = Image.new('RGBA', (S, S), (*p['light'], 0))
    light.putalpha(line)
    canvas.alpha_composite(light.filter(ImageFilter.GaussianBlur(S * .004)))
    canvas.alpha_composite(light)
    # The cross: slim, slightly tall, brass with a soft vertical sheen.
    cx, w = S // 2, int(S * .088)
    top_y, bottom_y = int(S * .17), hy - int(S * .012)
    arm_y, arm_w = int(S * .325), int(S * .43)
    mask = Image.new('L', (S, S), 0)
    md = ImageDraw.Draw(mask)
    r = int(w * .16)
    md.rounded_rectangle([cx - w // 2, top_y, cx + w // 2, bottom_y], radius=r, fill=255)
    md.rounded_rectangle([cx - arm_w // 2, arm_y, cx + arm_w // 2, arm_y + w], radius=r, fill=255)
    shadow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    shadow.putalpha(mask.filter(ImageFilter.GaussianBlur(S * .02)).point(lambda v: int(v * p['shadow'])))
    canvas.alpha_composite(shadow, dest=(0, int(S * .012)))
    gy = np.linspace(0, 1, S, dtype=np.float32)[:, None]
    gx = np.linspace(0, 1, S, dtype=np.float32)[None, :]
    hi, lo = np.array(p['hi'], np.float32), np.array(p['lo'], np.float32)
    t = np.clip((gy - top_y / S) / ((bottom_y - top_y) / S), 0, 1)
    brass = hi + (lo - hi) * t[..., None] ** .8
    sheen = np.exp(-(((gx - (cx - w * .18) / S) / (w * .22 / S)) ** 2))
    brass = brass * (1 + .12 * sheen[..., None])
    brass_img = Image.fromarray(np.ascontiguousarray(np.clip(np.broadcast_to(brass, (S, S, 3)), 0, 255).astype(np.uint8))).convert('RGBA')
    brass_img.putalpha(mask)
    canvas.alpha_composite(brass_img)
    return canvas.convert('RGB')


def _stars(img: np.ndarray, horizon: float, count: int) -> np.ndarray:
    """A few small soft stars in the sky, clear of the cross and the horizon."""
    rng = np.random.default_rng(11)
    cx, half = S / 2, S * .26
    placed = 0
    while placed < count:
        x, y = rng.uniform(S * .06, S * .94), rng.uniform(S * .05, S * (horizon - .08))
        if abs(x - cx) < half and y > S * .12:
            continue  # behind the cross and its arms
        r = rng.uniform(S * .0022, S * .0046)
        box = int(r * 6)
        x0, y0 = int(x) - box, int(y) - box
        yy, xx = np.mgrid[0:2 * box, 0:2 * box]
        dot = np.exp(-((xx - box) ** 2 + (yy - box) ** 2) / (2 * r * r)) * rng.uniform(.45, .9)
        region = img[y0:y0 + 2 * box, x0:x0 + 2 * box]
        star = np.array([226, 234, 255], np.float32)
        img[y0:y0 + 2 * box, x0:x0 + 2 * box] = region + (star - region) * dot[..., None].astype(np.float32)
        placed += 1
    return img


def render(palette: str, size: int = 1024) -> Image.Image:
    """One theme's icon, reduced from the 4x drawing."""
    return master(palette).resize((size, size), Image.Resampling.LANCZOS)


def main() -> None:
    big = master()
    icon = big.resize((1024, 1024), Image.Resampling.LANCZOS)
    sets = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    contents = json.loads((sets / 'Contents.json').read_text())
    for entry in contents['images']:
        name = entry.get('filename')
        if not name:
            continue
        points = float(entry['size'].split('x')[0])
        scale = int(entry['scale'].rstrip('x'))
        px = int(round(points * scale))
        icon.resize((px, px), Image.Resampling.LANCZOS).save(sets / name, optimize=True)
    icon.save(ROOT / 'public/app-icon.png', optimize=True)
    mark = big.resize((512, 512), Image.Resampling.LANCZOS)
    mark.save(ROOT / 'assets/brand/holyhim-mark.png', optimize=True)
    (ROOT / 'public/images').mkdir(exist_ok=True)
    mark.save(ROOT / 'public/images/holyhim-mark.png', optimize=True)
    for folder, px in {'mipmap-mdpi': 48, 'mipmap-hdpi': 72, 'mipmap-xhdpi': 96, 'mipmap-xxhdpi': 144,
                       'mipmap-xxxhdpi': 192}.items():
        out = ROOT / 'android/app/src/main/res' / folder
        if out.is_dir():
            icon.resize((px, px), Image.Resampling.LANCZOS).save(out / 'ic_launcher.png', optimize=True)
    print('Icon written to the iOS icon set, website, brand mark and Android launchers.')


if __name__ == '__main__':
    main()


def launch_wordmark() -> tuple[int, int]:
    """The splash wordmark as an image, so the native launch screen matches
    the first Flutter frame: Holy in bone, Him in brass, 46 pt."""
    from PIL import ImageFont
    font_path = str(ROOT / 'assets/fonts/SourceSerif4Display-Bold.ttf')
    out = ROOT / 'ios/Runner/Assets.xcassets/LaunchImage.imageset'
    size_pt = 46
    tracking = -.8
    for scale, name in [(1, 'LaunchImage.png'), (2, 'LaunchImage@2x.png'), (3, 'LaunchImage@3x.png')]:
        font = ImageFont.truetype(font_path, size_pt * scale)
        parts = [('Holy', (245, 241, 234, 255)), ('Him', (226, 182, 106, 255))]
        widths = []
        for text, _ in parts:
            for ch in text:
                widths.append(font.getlength(ch) + tracking * scale)
        width = int(sum(widths) + 8 * scale)
        ascent, descent = font.getmetrics()
        canvas = Image.new('RGBA', (width, ascent + descent + 4 * scale), (0, 0, 0, 0))
        d = ImageDraw.Draw(canvas)
        x = 4 * scale
        for text, colour in parts:
            for ch in text:
                d.text((x, 2 * scale), ch, font=font, fill=colour)
                x += font.getlength(ch) + tracking * scale
        canvas.save(out / name, optimize=True)
        if scale == 1:
            points = canvas.size
    return points


if __name__ == '__main__' and 'launch' in __import__('sys').argv:
    print('launch wordmark points:', launch_wordmark())
