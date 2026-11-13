"""Mechanical v2 editorial gate. Does not change authored input."""
from __future__ import annotations
import argparse, json, re, sys
from collections import defaultdict
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
FIELDS={'day','title','reference','theme','verse','meaning','heart','holdOn','prayer','teaser'}
LIMITS={'meaning':(30,45),'heart':(30,45),'holdOn':(8,18),'prayer':(30,50)}
BANNED=('tapestry','delve','navigate','embrace','unlock','beacon','testament to',"in today's fast-paced world","it's important to remember",'transformative journey','sacred dance','gentle reminder')
def words(text): return re.findall(r"[\w]+(?:[’'-][\w]+)*",text)
def passage(reference,verses):
 m=re.fullmatch(r'(.+) (\d+):(\d+)(?:-(\d+))?',reference)
 if not m: raise ValueError('Invalid reference '+reference)
 book,ch,a,b=m.groups();return ' '.join(verses[f'{book} {ch}:{n}'] for n in range(int(a),int(b or a)+1))
def validate(lessons, verses, partial=False):
 errors=[]; sentences={}; grams=defaultdict(set); all_tri={}
 days=[d.get('day') for d in lessons]
 if days!=list(range(1,len(lessons)+1)) or (not partial and len(lessons)!=365):errors.append('Expected exactly days 1–365 in order' if not partial else 'Expected contiguous days from 1')
 for d in lessons:
  n=d.get('day');prefix=f'Day {n}'
  if set(d)!=FIELDS: errors.append(prefix+': wrong fields');continue
  try:
   if d['verse']!=passage(d['reference'],verses):errors.append(prefix+': verse differs from pinned WEB')
  except (ValueError,KeyError) as e:errors.append(prefix+': '+str(e))
  for k,(lo,hi) in LIMITS.items():
   count=len(words(d[k]))
   if not lo<=count<=hi:errors.append(f'{prefix}: {k} {count} words, expected {lo}–{hi}')
  if not d['prayer'].endswith('Amen.'):errors.append(prefix+': prayer must end Amen.')
  if len(d['teaser'])>90:errors.append(prefix+': teaser exceeds 90 characters')
  for k in LIMITS:
   text=d[k]
   for banned in BANNED:
    if re.search(r'\b'+re.escape(banned)+r'\b',text,re.I):errors.append(prefix+': banned phrase '+banned)
   for s in re.split(r'(?<=[.!?])\s+',text):
    normalized=' '.join(words(s.lower()))
    if len(normalized.split())<5:continue
    if normalized in sentences and sentences[normalized]!=n:errors.append(f'{prefix}: sentence shared with day {sentences[normalized]}: {s}')
    sentences[normalized]=n
  tokens=words(' '.join(d[k] for k in LIMITS).lower());tri=set(zip(tokens,tokens[1:],tokens[2:]));candidates=set()
  for g in tri:candidates.update(grams[g])
  for other in candidates:
   other_tri=all_tri[other]
   overlap=len(tri&other_tri)/max(1,min(len(tri),len(other_tri)))
   if overlap>.42:errors.append(f'{prefix}: high trigram overlap ({overlap:.0%}) with day {other}')
  all_tri[n]=tri
  for g in tri:grams[g].add(n)
 return errors
def main():
 p=argparse.ArgumentParser();p.add_argument('--file',type=Path,default=ROOT/'content/lessons_v2.json');p.add_argument('--partial',action='store_true');a=p.parse_args()
 ds=json.loads(a.file.read_text());vs=json.loads((ROOT/'tool/scripture/verses.json').read_text());es=validate(ds,vs,a.partial)
 if es:
  print('\n'.join(es),file=sys.stderr);return 1
 totals=[sum(len(words(d[k])) for k in ('verse','meaning','heart','prayer')) for d in ds]
 print(f'{len(ds)} lessons pass: exact WEB, card ranges, unique sentences, trigram overlap, voice bans, prayer endings, teasers. Four-screen words {min(totals)}–{max(totals)} (long Scripture retained; legacy takeaway excluded).');return 0
if __name__=='__main__':raise SystemExit(main())
