"""Build a portable gallery of actual Flutter and browser captures."""
import html,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'store/walk-redesign'
manifest=json.loads((OUT/'manifest.json').read_text())
cards=[]
for entry in manifest:
 name=Path(entry['file']).name
 detail=f"{entry['theme'].title()} · {int(entry['width'])} × {int(entry['height'])} · {entry['textScale']:g}× text"
 cards.append(f'<figure><a href="{html.escape(name)}"><img loading="lazy" src="{html.escape(name)}" alt="{html.escape(name[:-4].replace("-"," "))}"></a><figcaption><strong>{html.escape(name[:-4])}</strong><br>{detail}</figcaption></figure>')
for p in sorted([*OUT.glob('browser-*.png'),*OUT.glob('site-*.png')]):
 cards.append(f'<figure class="browser"><a href="{p.name}"><img loading="lazy" src="{p.name}" alt="{html.escape(p.stem)}"></a><figcaption>{html.escape(p.stem)}</figcaption></figure>')
page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>HolyHim · Walk with God review</title><style>body{margin:0;padding:clamp(20px,4vw,60px);background:#fffaf7;color:#382735;font:16px/1.6 system-ui}header{max-width:850px;margin-bottom:36px}h1{font:clamp(30px,4vw,56px)/1.12 Georgia,serif}a{color:#98516a}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:26px}figure{margin:0;border:1px solid #ead7df;border-radius:24px;padding:16px;background:#fffdfb}img{display:block;max-width:100%;width:100%;height:520px;object-fit:contain;object-position:top;border-radius:14px;background:#f8edf0}figcaption{padding:14px 0 0;font-size:14px}.browser{grid-column:span 2}.browser img{height:480px;object-fit:cover}@media(max-width:650px){.browser{grid-column:span 1}}</style><header><p>HOLYHIM · VERSION 1.2.0 (4)</p><h1>A quieter moment.<br>A closer walk.</h1><p>Actual Flutter widget captures with isolated QA fixtures, plus local browser screenshots. These demonstrate the implemented interface; they are not physical-device acceptance evidence. Artwork is the botanical fallback. Gemini generation remains pending.</p><p><a href="../WALK_WITH_GOD_STATUS.md">Release status</a> · <a href="browser-qa.json">Browser and storage checks</a> · <a href="account-browser-qa.json">Authenticated browser checks</a> · <a href="../WALK_CONTENT_REVIEW.md">365-lesson review</a></p></header><main class="grid">'''+''.join(cards)+'</main></html>'
(OUT/'index.html').write_text(page)
print(f'Built gallery with {len(cards)} captures.')
