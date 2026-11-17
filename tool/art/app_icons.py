#!/usr/bin/env python3
"""Make HolyHim's app icons and put them in the iOS asset catalog.

Theme icons are HolyHim's cross above the first light (tool/art/draw_icon.py),
drawn in each theme's colours, so the set reads as one family. First Watch is
the primary icon; draw_icon.py writes its full-size set, the website icon and
the brand mark, and this script only makes its preview.

Symbol and season icons are drawn in Gemini and saved under
art/icons/gemini/<id>.(png|jpeg|jpg|webp); here they are squared, sized to
1024 and flattened onto an opaque background. Until a drawing exists its
icon is left out of the app (lib/services/app_icon.dart lists what ships).

Each alternate icon becomes a single-size 1024 asset-catalog set (Xcode
makes the rest) and a 180 px preview for the App icon screen.

  python3 tool/art/app_icons.py            # write everything that can be made
  python3 tool/art/app_icons.py --check    # the app's list, the sets and the
                                           # previews must agree; writes nothing
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tool/art'))
from draw_icon import PALETTES, render  # noqa: E402

GEMINI = ROOT / 'art/icons/gemini'
CATALOG = ROOT / 'ios/Runner/Assets.xcassets'
PREVIEWS = ROOT / 'assets/icons'
SIZE = 1024

# Every icon HolyHim offers, in the order the App icon screen shows them:
# (id, asset-catalog set, name shown, group). The first is the primary icon.
ICONS = [
    ('first-watch', 'AppIcon', 'First Watch', 'Themes'),
    ('limestone', 'AppIcon-Limestone', 'Limestone', 'Themes'),
    ('iron', 'AppIcon-Iron', 'Iron', 'Themes'),
    ('ember', 'AppIcon-Ember', 'Ember', 'Themes'),
    ('cedar', 'AppIcon-Cedar', 'Cedar', 'Themes'),
    ('midnight', 'AppIcon-Midnight', 'Midnight', 'Themes'),
    ('sandstone', 'AppIcon-Sandstone', 'Sandstone', 'Themes'),
    ('slate', 'AppIcon-Slate', 'Slate', 'Themes'),
    ('lion', 'AppIcon-Lion', 'Lion of Judah', 'Symbols'),
    ('anchor', 'AppIcon-Anchor', 'Anchor', 'Symbols'),
    ('mountain-dawn', 'AppIcon-MountainDawn', 'Mountain at Dawn', 'Symbols'),
    ('shepherds-staff', 'AppIcon-ShepherdsStaff', 'Shepherd’s Staff', 'Symbols'),
    ('lamp', 'AppIcon-Lamp', 'Lamp', 'Symbols'),
    ('christmas-star', 'AppIcon-ChristmasStar', 'Christmas Star', 'Seasons'),
    ('empty-tomb', 'AppIcon-EmptyTomb', 'Empty Tomb', 'Seasons'),
]


def gemini_source(icon_id: str) -> Path | None:
    for ext in ('png', 'jpeg', 'jpg', 'webp'):
        path = GEMINI / f'{icon_id}.{ext}'
        if path.exists():
            return path
    return None


def squared(path: Path) -> Image.Image:
    """A Gemini drawing, centre-cropped square, 1024 px, opaque."""
    image = Image.open(path).convert('RGB')
    side = min(image.size)
    left, top = (image.width - side) // 2, (image.height - side) // 2
    return image.crop((left, top, left + side, top + side)).resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def write_set(name: str, image: Image.Image) -> None:
    folder = CATALOG / f'{name}.appiconset'
    folder.mkdir(parents=True, exist_ok=True)
    for old in folder.glob('*.png'):
        old.unlink()
    target = folder / f'{name}-1024.png'
    image.save(target, optimize=True)
    contents = {
        'images': [{'filename': target.name, 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}],
        'info': {'author': 'xcode', 'version': 1},
    }
    (folder / 'Contents.json').write_text(json.dumps(contents, indent=2) + '\n')


def available() -> list[tuple[str, str, str, str]]:
    """The icons that can ship now: every theme, and each symbol with a drawing."""
    return [icon for icon in ICONS if icon[0] in PALETTES or gemini_source(icon[0])]


def check() -> list[str]:
    """The app's list, the asset catalog and the previews must agree."""
    problems = []
    source = (ROOT / 'lib/services/app_icon.dart').read_text()
    listed = re.findall(r"AppIconChoice\(\s*'([^']+)',\s*(null|'[^']+')", source)
    expected = [(icon_id, None if set_name == 'AppIcon' else set_name) for icon_id, set_name, _, _ in available()]
    shipped = [(icon_id, None if ios == 'null' else ios.strip("'")) for icon_id, ios in listed]
    if shipped != expected:
        problems.append(f'lib/services/app_icon.dart lists {shipped}, expected {expected}')
    sets = {path.name[:-len('.appiconset')] for path in CATALOG.glob('*.appiconset')}
    wanted = {set_name for _, set_name, _, _ in available()}
    if sets != wanted:
        problems.append(f'asset catalog has {sorted(sets)}, expected {sorted(wanted)}')
    for icon_id, _, _, _ in available():
        if not (PREVIEWS / f'{icon_id}.png').is_file():
            problems.append(f'assets/icons/{icon_id}.png is missing')
    return problems


def main() -> int:
    cli = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    cli.add_argument('--check', action='store_true')
    args = cli.parse_args()
    if args.check:
        found = check()
        print('\n'.join(found) if found else f'{len(available())} app icons agree across the app, the catalog and the previews.')
        return 1 if found else 0
    made, waiting = [], []
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    for icon_id, set_name, _, _ in ICONS:
        if icon_id in PALETTES:
            image = render(icon_id)
        elif (source := gemini_source(icon_id)) is not None:
            image = squared(source)
        else:
            waiting.append(icon_id)
            continue
        if set_name != 'AppIcon':  # draw_icon.py writes the primary's full set
            write_set(set_name, image)
        image.resize((180, 180), Image.Resampling.LANCZOS).save(PREVIEWS / f'{icon_id}.png', optimize=True)
        made.append(icon_id)
    print(f"Made {len(made)} icons: {', '.join(made)}.")
    if waiting:
        print(f"Waiting for Gemini drawings: {', '.join(waiting)} (art/icons/gemini/<id>.png).")
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
