#!/usr/bin/env python3
"""Frame HolyHim's real rendered screens as App Store screenshots.

Input: build/render/store/*.png from `flutter test tool/render/him_screenshots_test.dart`
(real app screens at 1290 x 2796). Output: store/screenshots/app-store/iphone-1290x2796/*.png,
1290 x 2796 RGB, each with a two-line headline in the brand type on First
Watch charcoal. Nothing on the phone is drawn by this script.

  python3 tool/store_screenshots.py
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / 'build/render/store'
OUT = ROOT / 'store/screenshots/app-store/iphone-1290x2796'
FONTS = ROOT / 'assets/fonts'
W, H = 1290, 2796
BONE, BRASS, MUTED = (242, 237, 228), (216, 166, 87), (167, 174, 184)
CAPTIONS = {
    '01-walk': ('A word to stand on.', 'Every morning.'),
    '02-road': ('Walk the road,', 'one day at a time.'),
    '03-scripture': ('Scripture first,', 'word for word.'),
    '04-life': ('Plain words', 'for real life.'),
    '05-amen': ('Hold to say', 'Amen.'),
    '06-brothers': ('Iron sharpens', 'iron.'),
    '07-ranks': ('Stand with', 'your brothers.'),
    '08-growth': ('Earn every', 'medallion.'),
}


def background() -> Image.Image:
    y = np.linspace(0, 1, H, dtype=np.float32)[:, None]
    x = np.linspace(0, 1, W, dtype=np.float32)[None, :]
    top, bottom = np.array([10, 13, 18], np.float32), np.array([20, 27, 36], np.float32)
    base = top + (bottom - top) * y[..., None]
    glow = np.exp(-(((x - .5) / .55) ** 2) - (((y - 1.02) / .22) ** 2))[..., None]
    img = base * (1 - glow * .45) + np.array([216, 166, 87], np.float32) * (glow * .45)
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))


def frame(raw: Image.Image, caption: tuple[str, str]) -> Image.Image:
    canvas = background().convert('RGBA')
    draw = ImageDraw.Draw(canvas)
    eyebrow = ImageFont.truetype(str(FONTS / 'Manrope-ExtraBold.ttf'), 34)
    title = ImageFont.truetype(str(FONTS / 'SourceSerif4Display-Bold.ttf'), 104)
    text = 'H O L Y H I M'
    draw.text((W / 2, 150), text, font=eyebrow, fill=BRASS, anchor='mt')
    draw.text((W / 2, 230), caption[0], font=title, fill=BONE, anchor='mt')
    draw.text((W / 2, 352), caption[1], font=title, fill=BRASS, anchor='mt')
    ui_w = 1004
    ui_h = round(ui_w * raw.height / raw.width)
    x, y = (W - ui_w) // 2, 540
    radius, border = 78, 10
    shadow = Image.new('RGBA', (W, H))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (x - border, y - border + 30, x + ui_w + border, y + ui_h + border + 30), radius=radius + border,
        fill=(0, 0, 0, 150))
    canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(40)))
    ImageDraw.Draw(canvas).rounded_rectangle(
        (x - border, y - border, x + ui_w + border, y + ui_h + border), radius=radius + border,
        fill=(31, 38, 48, 255), outline=(52, 62, 76, 255), width=3)
    screen = raw.convert('RGB').resize((ui_w, ui_h), Image.Resampling.LANCZOS)
    mask = Image.new('L', screen.size)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, ui_w - 1, ui_h - 1), radius=radius, fill=255)
    canvas.paste(screen, (x, y), mask)
    return canvas.convert('RGB')


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = []
    for name, caption in CAPTIONS.items():
        source = RAW / f'{name}.png'
        with Image.open(source) as raw:
            assert raw.size == (W, H), f'{source} is {raw.size}, expected {(W, H)}'
            image = frame(raw, caption)
        target = OUT / f'{name}.png'
        image.save(target, optimize=True)
        manifest.append({'file': str(target.relative_to(ROOT)), 'source': str(source.relative_to(ROOT)),
                         'caption': ' '.join(caption), 'size': list(image.size), 'mode': image.mode})
    (OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'{len(manifest)} App Store screenshots written to {OUT.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
