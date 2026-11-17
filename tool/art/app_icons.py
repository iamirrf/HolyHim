#!/usr/bin/env python3
"""Make HolyHim's app icons and put them in the iOS asset catalog.

Theme icons are the master cross (art/icons/master-cross.png, the original
1024 icon) in each theme's colours. The master is split into its gradient,
the cross and the cross's soft shadow; every theme gets the same cross and
shadow over its own gradient, following the master's gradient shape, so the
set reads as one family. Dark themes trade the shadow for a quiet glow.

Symbol and seasonal icons are drawn in Gemini and saved under
art/icons/gemini/<id>.(png|jpeg); here they are only squared, sized to 1024
and flattened onto an opaque background.

Each icon becomes an asset-catalog set named in ICONS below (single-size
1024 sets; Xcode makes the rest), plus a 180 px preview the app shows in
its App icon screen.

  python3 tool/art/app_icons.py            # write everything
  python3 tool/art/app_icons.py --check    # the master's own colours must
                                           # rebuild the master closely
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
MASTER = ROOT / "art/icons/master-cross.png"
GEMINI = ROOT / "art/icons/gemini"
OUT = ROOT / "art/icons"
CATALOG = ROOT / "ios/Runner/Assets.xcassets"
PREVIEWS = ROOT / "assets/icons"
SIZE = 1024

# Corner colours of each theme's gradient: light at the top left, deep at
# the bottom right, as in the master. Dark themes add a glow colour.
THEMES = {
    "rose": ((252, 226, 231), (158, 50, 84), None),
    "lavender": ((241, 233, 249), (118, 90, 158), None),
    "sunrise": ((255, 234, 208), (212, 112, 66), None),
    "pearl": ((250, 247, 242), (166, 138, 126), None),
    "olive-grove": ((237, 241, 223), (92, 122, 84), None),
    "evening": ((78, 36, 54), (20, 13, 17), (230, 163, 183)),
    "starlight": ((50, 46, 92), (13, 12, 24), (196, 196, 255)),
}

# Every icon the app offers, in the order the App icon screen shows them:
# (id, asset-catalog set, name shown, group). The first is the primary icon.
ICONS = [
    ("first-light", "AppIcon", "First Light", "Themes"),
    ("rose", "AppIcon-Rose", "Rosé", "Themes"),
    ("lavender", "AppIcon-Lavender", "Lavender", "Themes"),
    ("sunrise", "AppIcon-Sunrise", "Sunrise", "Themes"),
    ("pearl", "AppIcon-Pearl", "Pearl", "Themes"),
    ("olive-grove", "AppIcon-OliveGrove", "Olive Grove", "Themes"),
    ("evening", "AppIcon-Evening", "Evening", "Themes"),
    ("starlight", "AppIcon-Starlight", "Starlight", "Themes"),
    ("dove", "AppIcon-Dove", "Dove", "Symbols"),
    ("lily", "AppIcon-Lily", "Lily", "Symbols"),
    ("cross-at-sunrise", "AppIcon-CrossSunrise", "Cross at Sunrise", "Symbols"),
    ("olive-branch", "AppIcon-OliveBranch", "Olive Branch", "Symbols"),
    ("candle", "AppIcon-Candle", "Candle", "Symbols"),
    ("christmas-star", "AppIcon-ChristmasStar", "Christmas Star", "Seasons"),
    ("easter-morning", "AppIcon-EasterMorning", "Easter Morning", "Seasons"),
]


def load(path: Path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.float64)


def saturation(rgb: np.ndarray) -> np.ndarray:
    hi, lo = rgb.max(-1), rgb.min(-1)
    return np.where(hi > 0, (hi - lo) / np.maximum(hi, 1e-6), 0)


def luminance(rgb: np.ndarray) -> np.ndarray:
    return rgb @ np.array([0.2126, 0.7152, 0.0722])


def split(master: np.ndarray):
    """The master's gradient position t (0 top left .. 1 bottom right),
    the cross's coverage and colour, and the shadow's strength."""
    h, w, _ = master.shape
    sat = saturation(master)
    cross = sat < 0.08
    near = np.asarray(Image.fromarray((cross * 255).astype(np.uint8))
                      .filter(ImageFilter.MaxFilter(81))) > 0
    ys, xs = np.mgrid[0:h, 0:w] / (SIZE - 1)
    terms = [np.ones_like(xs), xs, ys, xs * xs, xs * ys, ys * ys]
    basis = np.stack(terms, -1)
    keep = ~near
    fit = np.linalg.lstsq(basis[keep][::7], master[keep][::7], rcond=None)[0]
    bg = basis @ fit
    # The gradient's shape, read from its luminance between the corners.
    lum = luminance(bg)
    t = np.clip((lum.max() - lum) / (lum.max() - lum.min()), 0, 1)
    # Mixing with the white cross pulls saturation down; a shadow darkens
    # but keeps it.
    coverage = np.clip(1 - sat / np.maximum(saturation(bg), 1e-6), 0, 1)
    coverage[~near] = 0
    shade = np.clip(1 - luminance(master) / np.maximum(lum, 1e-6), 0, 1)
    shade = np.where(near, shade * (1 - coverage), 0)
    white = np.clip(luminance(master) / 247.0, 0.9, 1.02)
    white = np.asarray(Image.fromarray(((white - 0.9) / 0.12 * 255).astype(np.uint8))
                       .filter(ImageFilter.GaussianBlur(3)), dtype=np.float64) / 255 * 0.12 + 0.9
    return t, coverage, white, shade, bg


def gradient(t: np.ndarray, top: tuple, bottom: tuple) -> np.ndarray:
    a, b = np.array(top, float), np.array(bottom, float)
    return a + (b - a) * t[..., None]


def theme_icon(parts, top, bottom, glow) -> np.ndarray:
    t, coverage, white, shade, _ = parts
    bg = gradient(t, top, bottom)
    if glow is None:
        under = bg * (1 - shade[..., None])
    else:
        halo = np.asarray(Image.fromarray((coverage * 255).astype(np.uint8))
                          .filter(ImageFilter.GaussianBlur(46)), dtype=np.float64) / 255
        g = np.array(glow, float)
        lift = (halo * 0.55)[..., None]
        under = bg + (g - bg) * lift  # a soft light behind the cross
    cross = np.array([247.0, 246.0, 246.0]) * white[..., None]
    if glow is not None:
        cross = cross * 0.94 + np.array(glow, float) * 0.06
    out = under * (1 - coverage[..., None]) + cross * coverage[..., None]
    return np.clip(out, 0, 255)


def stars(img: np.ndarray, coverage: np.ndarray) -> np.ndarray:
    """A few small, soft stars for Starlight, kept clear of the cross."""
    rng = np.random.default_rng(7)
    h, w, _ = img.shape
    layer = np.zeros((h, w))
    clear = np.asarray(Image.fromarray((coverage * 255).astype(np.uint8))
                       .filter(ImageFilter.MaxFilter(121))) < 8
    placed = 0
    while placed < 16:
        x, y = rng.integers(70, w - 70), rng.integers(70, h - 70)
        if not clear[y, x]:
            continue
        r = rng.uniform(2.2, 4.6)
        yy, xx = np.ogrid[-12:13, -12:13]
        dot = np.exp(-(xx * xx + yy * yy) / (2 * r * r)) * rng.uniform(0.45, 0.9)
        layer[y - 12:y + 13, x - 12:x + 13] = np.maximum(layer[y - 12:y + 13, x - 12:x + 13], dot)
        placed += 1
    star = np.array([236.0, 236.0, 255.0])
    return img + (star - img) * layer[..., None]


def squared(path: Path) -> np.ndarray:
    """A Gemini drawing, centre-cropped square, 1024 px, opaque."""
    im = Image.open(path).convert("RGB")
    side = min(im.size)
    left, top = (im.width - side) // 2, (im.height - side) // 2
    im = im.crop((left, top, left + side, top + side)).resize((SIZE, SIZE), Image.LANCZOS)
    return np.asarray(im, dtype=np.float64)


def gemini_source(icon_id: str) -> Path | None:
    for ext in ("png", "jpeg", "jpg", "webp"):
        p = GEMINI / f"{icon_id}.{ext}"
        if p.exists():
            return p
    return None


def save(img: np.ndarray, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.round(img).astype(np.uint8), "RGB").save(path, optimize=True)


def write_set(name: str, png: Path) -> None:
    folder = CATALOG / f"{name}.appiconset"
    folder.mkdir(parents=True, exist_ok=True)
    if name == "AppIcon":
        return  # the primary icon keeps its hand-made full size set
    for old in folder.glob("*.png"):
        old.unlink()
    target = folder / f"{name}-1024.png"
    target.write_bytes(png.read_bytes())
    contents = {
        "images": [{"filename": target.name, "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
        "info": {"author": "xcode", "version": 1},
    }
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def main() -> int:
    cli = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    cli.add_argument("--check", action="store_true")
    args = cli.parse_args()
    master = load(MASTER)
    parts = split(master)
    t, coverage = parts[0], parts[1]
    top = tuple(master[6:20, 6:20].reshape(-1, 3).mean(0))
    bottom = tuple(master[-20:-6, -20:-6].reshape(-1, 3).mean(0))
    rebuilt = theme_icon(parts, top, bottom, None)
    error = np.abs(rebuilt - master).mean()
    print(f"Master rebuilt from its parts: mean error {error:.2f} of 255.")
    if args.check:
        return 0 if error < 3 else 1
    made, missing = [], []
    for icon_id, set_name, _, _ in ICONS:
        png = OUT / f"{icon_id}.png"
        if icon_id == "first-light":
            img = master
        elif icon_id in THEMES:
            img = theme_icon(parts, *THEMES[icon_id])
            if icon_id == "starlight":
                img = stars(img, coverage)
        else:
            source = gemini_source(icon_id)
            if source is None:
                missing.append(icon_id)
                continue
            img = squared(source)
        save(img, png)
        write_set(set_name, png)
        preview = Image.fromarray(np.round(img).astype(np.uint8), "RGB").resize((180, 180), Image.LANCZOS)
        PREVIEWS.mkdir(parents=True, exist_ok=True)
        preview.save(PREVIEWS / f"{icon_id}.png", optimize=True)
        made.append(icon_id)
    print(f"Made {len(made)} icons: {', '.join(made)}.")
    if missing:
        print(f"Waiting for Gemini drawings: {', '.join(missing)} (art/icons/gemini/<id>.png).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
