#!/usr/bin/env python3
"""Regrade warm pink-dawn artwork into HolyHim's "First Watch" light.

A tone map, not a filter stack: luminance drives a blue-hour to brass
gradient (deep slate shadows, cool midtones, amber light), blended with the
desaturated original so trees, stone and skin keep believable colour. Pinks
and magentas are pulled toward amber first, so no rose cast survives.
Medallions use a bronze map instead and keep their transparency.
"""
from __future__ import annotations
import numpy as np
from PIL import Image

PHOTO_STOPS = [(0.00, (7, 10, 15)), (0.22, (24, 33, 46)), (0.45, (63, 74, 86)),
               (0.66, (139, 128, 110)), (0.82, (214, 165, 98)), (1.00, (247, 232, 203))]
BRONZE_STOPS = [(0.00, (20, 14, 9)), (0.28, (58, 40, 24)), (0.52, (120, 82, 47)),
                (0.72, (176, 128, 74)), (0.88, (222, 183, 120)), (1.00, (246, 226, 182))]


def _ramp(lum: np.ndarray, stops) -> np.ndarray:
    xs = np.array([s[0] for s in stops])
    out = np.empty(lum.shape + (3,), np.float32)
    for c in range(3):
        out[..., c] = np.interp(lum, xs, np.array([s[1][c] for s in stops], np.float32) / 255)
    return out


def _luminance(rgb: np.ndarray) -> np.ndarray:
    return rgb[..., 0] * .2126 + rgb[..., 1] * .7152 + rgb[..., 2] * .0722


def _blur(channel: np.ndarray, radius: float) -> np.ndarray:
    from PIL import ImageFilter
    im = Image.fromarray(np.clip(channel * 255, 0, 255).astype(np.uint8), 'L')
    return np.asarray(im.filter(ImageFilter.GaussianBlur(radius)), np.float32) / 255


def regrade_photo(image: Image.Image) -> Image.Image:
    """Blue hour above, brass light at the sun, cool shadows below."""
    rgb = np.asarray(image.convert('RGB'), np.float32) / 255
    h, w = rgb.shape[:2]
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    # 1. Pink and magenta (red and blue both above green) become amber.
    pink = np.clip((np.minimum(r, b) - g) * 3.0, 0, 1) + np.clip((r - g) * 1.2 - .10, 0, 1) * .5
    pink = np.clip(pink, 0, 1)[..., None]
    amber = np.stack([r * .96 + g * .04, r * .62 + g * .38, g * .42 + b * .22], -1)
    rgb = rgb * (1 - pink) + amber * pink
    lum = _luminance(rgb)
    # 2. Where the light is: a wide halo around the brightest part of the frame.
    hot = np.clip((lum - .80) * 5, 0, 1)
    halo = np.clip(_blur(hot, max(w, h) * .10) * 3.8, 0, 1)
    # 3. Sky weight: bright, smooth pixels in the upper part of the frame.
    y = np.linspace(0, 1, h, dtype=np.float32)[:, None]
    upper = np.clip((.62 - y) / .45, 0, 1)
    texture = np.abs(lum - _blur(lum, 6))
    smooth = np.clip(1 - texture * 18, 0, 1)
    sky = np.clip(upper * smooth * np.clip((lum - .35) * 2.5, 0, 1), 0, 1)
    sky = _blur(sky, 12)
    # 4. Tone: darker overall, firmer mids, deep cool blacks.
    tone = np.clip(lum * .86, 0, 1)
    tone = np.clip(.5 + (tone - .5) * 1.14, 0, 1)
    sky_tone = np.clip(.18 + tone * .62, 0, 1)
    tone = tone * (1 - sky) + sky_tone * sky
    # 5. Colour: cool slate by default, blue-hour sky, brass near the light.
    slate = np.array([.80, .92, 1.10], np.float32)
    blue = np.array([.58, .84, 1.22], np.float32)
    brass = np.array([1.40, 1.02, .58], np.float32)
    tint = np.ones_like(rgb) * slate
    tint = tint * (1 - sky[..., None]) + blue * sky[..., None]
    warm = np.clip(halo * 1.0 + np.clip((lum - .55) * 1.6, 0, 1) * .45 * (1 - sky), 0, 1)[..., None]
    tint = tint * (1 - warm) + brass * warm
    grey = tone[..., None]
    chroma = rgb - _luminance(rgb)[..., None]
    out = grey * tint + chroma * .48
    return Image.fromarray(np.clip(out * 255 + .5, 0, 255).astype(np.uint8), 'RGB')


def regrade_medallion(image: Image.Image) -> Image.Image:
    rgba = np.asarray(image.convert('RGBA'), np.float32) / 255
    lum = np.clip(_luminance(rgba[..., :3]), 0, 1)
    lum = np.clip(.5 + (lum - .5) * 1.18 - .04, 0, 1)
    rgb = _ramp(lum, BRONZE_STOPS)
    out = np.concatenate([rgb, rgba[..., 3:]], -1)
    return Image.fromarray(np.clip(out * 255 + .5, 0, 255).astype(np.uint8), 'RGBA')
