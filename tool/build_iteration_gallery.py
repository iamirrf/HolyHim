#!/usr/bin/env python3
"""Index physical screenshots and composition reviews with distinct evidence labels."""
import html, json
from pathlib import Path
root = Path(__file__).resolve().parents[1]/'store/pearl-redesign'
for folder, description in [('device-gallery', 'Physical iPhone screenshots of production screens with isolated development fixtures. Normal launch uses the actual account. Captures do not establish physical finger feel or VoiceOver traversal.'), ('review-renders', 'Offscreen Flutter composition review with macOS rounded system tables streamed only in memory. These are not native iOS screenshots and do not establish device performance.')]:
    target = root/folder
    target.mkdir(exist_ok=True)
    cards = []
    for file in sorted(target.glob('*.json')):
        image = file.with_suffix('.png')
        if not image.exists():
            continue
        data = json.loads(file.read_text())
        title = f"{data['route']} · {data['logicalWidth']:g} × {data['logicalHeight']:g} · text {data['textScale']:g}"
        cards.append(f'<figure data-search="{html.escape(title.lower())}"><a href="{image.name}"><img loading="lazy" src="{image.name}" alt="{html.escape(title)}"></a><figcaption>{html.escape(title)}<br><a href="{file.name}">Route and capture evidence</a></figcaption></figure>')
    (target/'index.html').write_text('<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>HolyHer design review</title><style>*{box-sizing:border-box}body{background:#fff9fb;color:#382331;margin:32px;font:16px/1.5 system-ui}header{max-width:900px}a{color:#9c456b}input{font:inherit;padding:12px;border:1px solid #735867;border-radius:12px;width:min(100%,480px);margin:16px 0 32px}main{display:grid;grid-template-columns:repeat(auto-fill,minmax(270px,1fr));gap:24px}figure{margin:0;padding:12px;background:white;border-radius:24px;border:1px solid #e9d4df}img{width:100%;height:600px;object-fit:contain;object-position:top}figcaption{padding:12px 4px;font-size:14px}p{color:#735867}</style><header><h1>HolyHer · Second design pass</h1><p>'+html.escape(description)+'</p><p>'+str(len(cards))+' frames · <a href="../REVIEW.md">Critique and revisions</a> · <a href="../VERIFICATION.md">Verification</a></p><input type="search" id="filter" placeholder="Filter by screen, state, size or scale" aria-label="Filter screenshots"></header><main>'+''.join(cards)+'</main><script>document.querySelector("#filter").oninput=e=>document.querySelectorAll("figure").forEach(f=>f.hidden=!f.dataset.search.includes(e.target.value.toLowerCase()))</script></html>')
    print(folder, len(cards))
(root/'index.html').write_text('<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>HolyHer redesign</title><style>body{font:18px/1.6 system-ui;background:#fff9fb;color:#382331;max-width:720px;margin:64px auto;padding:24px}a{color:#9c456b}</style><h1>HolyHer · Second design pass</h1><p><a href="device-gallery/index.html">Physical iPhone review</a></p><p><a href="review-renders/index.html">Composition review across screen sizes and text scales</a></p><p><a href="REVIEW.md">Visible defects and revisions</a> · <a href="VERIFICATION.md">Checks and remaining device gates</a></p><p>The original simulator gallery and three direction studies remain <a href="gallery/index.html">archived as first-pass evidence</a>. They show the earlier implementation.</p></html>')
