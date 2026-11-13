#!/usr/bin/env python3
"""Inventory current Flutter raster captures; never label them device screenshots."""
import hashlib
import html
import json
from datetime import datetime
from pathlib import Path
from PIL import Image
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'store/launch-redesign'
SCREENS = OUT / 'screens'
REFERENCES = {
    'onboarding-1': '../../pearl-redesign/reference/cognein-name-393.png',
    'scripture': '../../pearl-redesign/reference/cognein-surface-393.png',
    'welcome': '../../pearl-redesign/reference/cognein-welcome-393.png',
}

images = []
figures = []
for path in sorted(SCREENS.glob('*.png')):
    with Image.open(path) as image:
        pixels = list(image.size)
    name = path.stem
    images.append({
        'path': f'screens/{path.name}',
        'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
        'kind': 'Flutter raster layout capture; not an iPhone screenshot',
        'logicalSize': [value // 2 for value in pixels],
        'pixelSize': pixels,
    })
    reference = REFERENCES.get(name)
    pair = ''
    if reference:
        pair = (f'<div><small>Cognein saved reference</small><img src="{reference}" '
                f'alt="Cognein saved {html.escape(name)} reference"></div>')
    figures.append(
        f'<figure><div class="pair">{pair}<div><small>HolyHim current raster</small>'
        f'<a href="screens/{path.name}"><img src="screens/{path.name}" '
        f'loading="lazy" alt="HolyHim {html.escape(name)} raster capture"></a></div></div>'
        f'<figcaption>{html.escape(name)}</figcaption></figure>')

(OUT / 'screen-captures.json').write_text(json.dumps({
    'version': 1, 'capturedAt': datetime.now(ZoneInfo('America/New_York')).date().isoformat(),
    'build': 'current local source',
    'images': images,
}, indent=2) + '\n')
(OUT / 'gallery.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>HolyHim launch redesign comparison</title><style>*{box-sizing:border-box}body{margin:0;padding:32px;background:#fff9f6;color:#432d38;font:16px/1.5 system-ui}header{max-width:950px;margin:auto auto 30px}h1{font:42px/1.1 Georgia}p{max-width:75ch}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:24px}figure{margin:0;padding:16px;background:#fff;border-radius:22px;border:1px solid #eadbdc}.pair{display:flex;gap:12px;align-items:start}.pair>div{flex:1;min-width:0}.pair img{width:100%;height:530px;object-fit:contain;object-position:top;border-radius:12px;background:#f6edef}small{display:block;margin-bottom:8px}figcaption{padding-top:12px;font-weight:700}a{color:#934766}</style><header><h1>HolyHim launch redesign</h1><p>''' + str(len(images)) + ''' current Flutter raster layout captures. They are not physical-device screenshots or native glass, motion, touch, accessibility, or performance evidence. Three Cognein references are shown alongside current layouts; the remaining captures have no direct reference image in the saved checkout.</p><p><a href="SCREEN_MATRIX.md">Screen and state inventory</a> · <a href="screen-captures.json">Capture hashes</a> · <a href="../redesign-v3/chapter-contact-sheet.jpg">Chapter art review</a></p></header><main>''' + ''.join(figures) + '</main></html>')
print(f'{len(images)} raster captures inventoried')
