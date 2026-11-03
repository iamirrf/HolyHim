#!/usr/bin/env python3
"""Audit capture geometry and detect launch-only frames; visual review remains required."""
import json
from pathlib import Path
from PIL import Image
import numpy as np
root=Path('store/pearl-redesign/gallery');rows=[]
for p in root.glob('*.json'):
 d=json.loads(p.read_text());png=p.with_suffix('.png')
 if not png.exists():continue
 im=Image.open(png).convert('RGB');w,h=im.size
 reasons=[]
 if (w,h)!=(round(d['pixelWidth']),round(d['pixelHeight'])):reasons.append('pixel geometry mismatch')
 if d.get('errors'):reasons.append('Flutter or automation errors')
 if any(d.get('font',{}).get(f'{x}WidthDelta',999)>.05 for x in ['regular','semibold']):reasons.append('font specimen mismatch or missing')
 logical=im.resize((round(d['logicalWidth']),round(d['logicalHeight'])))
 lw,lh=logical.size
 a=np.asarray(logical);mask=(a[:,:,0]<120)&(a[:,:,1]<110)&(a[:,:,2]<120)
 mask[:80,:]=False;mask[lh-30:,:]=False
 mask[max(0,lh//2-64):lh//2+64,max(0,lw//2-64):lw//2+64]=False
 ink=int(mask.sum())
 if ink<180:reasons.append('possible native launch screen; inspect and recapture')
 rows.append({'capture':png.name,'route':d['route'],'inkPixelsOutsideLaunchMark':ink,'issues':reasons})
(root.parent/'gallery-audit.json').write_text(json.dumps(rows,indent=2))
for r in rows:
 if r['issues']:print(r['capture'],r['issues'])
print('Audited',len(rows),'captures;',sum(bool(r['issues']) for r in rows),'need inspection')
