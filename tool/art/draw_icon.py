#!/usr/bin/env python3
"""Draw HolyHim's icon: a brass cross above a line of first light, on
charcoal-navy. Rendered at 4x and reduced, so every edge is clean. Writes
the 1024 master and every iOS size listed in the app icon set, plus the
brand mark and the website icon.

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


def master() -> Image.Image:
    y = np.linspace(0, 1, S, dtype=np.float32)[:, None]
    x = np.linspace(0, 1, S, dtype=np.float32)[None, :]
    top, bottom = np.array([9, 12, 17], np.float32), np.array([24, 31, 42], np.float32)
    base = top + (bottom - top) * y[..., None]
    horizon = .695
    # First light: a wide warm glow centred on the horizon below the cross.
    glow = np.exp(-(((x - .5) / .42) ** 2) - (((y - horizon) / .11) ** 2))
    warm = np.array([216, 166, 87], np.float32)
    img = base * (1 - glow[..., None] * .55) + warm * (glow[..., None] * .55)
    # Ground below the horizon stays dark and cool.
    ground = np.clip((y - horizon) / .012, 0, 1)
    img = img * (1 - ground[..., None] * .62) + np.array([10, 13, 18], np.float32) * (ground[..., None] * .62)
    canvas = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).convert('RGBA')
    d = ImageDraw.Draw(canvas)
    # The horizon line itself, bright at the centre and fading to the edges.
    line = Image.new('L', (S, S), 0)
    ld = ImageDraw.Draw(line)
    hy = int(S * horizon)
    ld.rectangle([0, hy - int(S * .0045), S, hy + int(S * .0045)], fill=255)
    fade = (np.exp(-(((np.linspace(0, 1, S) - .5) / .24) ** 2)) * 255).astype(np.uint8)
    line = Image.fromarray((np.asarray(line, np.float32) * fade[None, :] / 255).astype(np.uint8))
    light = Image.new('RGBA', (S, S), (246, 214, 150, 0))
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
    shadow.putalpha(mask.filter(ImageFilter.GaussianBlur(S * .02)).point(lambda v: int(v * .55)))
    canvas.alpha_composite(shadow, dest=(0, int(S * .012)))
    gy = np.linspace(0, 1, S, dtype=np.float32)[:, None]
    gx = np.linspace(0, 1, S, dtype=np.float32)[None, :]
    hi, lo = np.array([243, 205, 132], np.float32), np.array([170, 118, 52], np.float32)
    t = np.clip((gy - top_y / S) / ((bottom_y - top_y) / S), 0, 1)
    brass = hi + (lo - hi) * t[..., None] ** .8
    sheen = np.exp(-(((gx - (cx - w * .18) / S) / (w * .22 / S)) ** 2))
    brass = brass * (1 + .12 * sheen[..., None])
    brass_img = Image.fromarray(np.ascontiguousarray(np.clip(np.broadcast_to(brass, (S, S, 3)), 0, 255).astype(np.uint8))).convert('RGBA')
    brass_img.putalpha(mask)
    canvas.alpha_composite(brass_img)
    return canvas.convert('RGB')


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
