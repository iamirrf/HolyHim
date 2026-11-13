"""Mechanical v2 editorial gate. Does not change authored input."""
from __future__ import annotations
import argparse, json, re, sys
from collections import defaultdict
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
FIELDS={'day','title','reference','theme','verse','meaning','heart','holdOn','prayer','teaser'}
LIMITS={'meaning':(30,45),'heart':(30,45),'holdOn':(8,18),'prayer':(30,50)}
BANNED=('tapestry','delve','navigate','embrace','unlock','beacon','testament to',"in today's fast-paced world","it's important to remember",'transformative journey','sacred dance','gentle reminder')
# First Light voice (content/STYLE.md): plain words, short sentences.
CLINICAL=('practical','component','facilitate','utilize','aspect','dimension','framework','paradigm','leverage','optimal','implement','perspective','significant','mechanism','intentional','ultimately','essentially','prioritize','companionship','consequently','individuals','circumstances','demonstrate')
MAX_GRADE=6.0
MAX_SENTENCE=22
VOICE=ROOT/'content/voice.json'
def syllables(word):
 w=word.lower().replace('’',"'");w=re.sub(r"'s$",'',w)
 if len(w)<=3:return 1
 w=re.sub(r'(?:[^laeiouy]es|ed|[^laeiouy]e)$','',w);w=re.sub(r'^y','',w)
 return max(1,len(re.findall(r'[aeiouy]{1,2}',w)))
def sentences(text):return [s for s in re.split(r'(?<=[.!?])\s+',text.strip()) if words(s)]
def grade(text):
 ws=words(text);ss=sentences(text)
 return .39*len(ws)/len(ss)+11.8*sum(syllables(w) for w in ws)/len(ws)-15.59
def voice_errors(d):
 prefix=f"Day {d['day']}";errors=[]
 body=' '.join(d[k] for k in ('meaning','heart','prayer'))
 g=grade(body)
 if g>MAX_GRADE:errors.append(f'{prefix}: reading grade {g:.1f}, expected at most {MAX_GRADE}')
 for k in ('meaning','heart','prayer','holdOn','teaser'):
  for w in CLINICAL:
   if re.search(r'\b'+re.escape(w)+r'\b',d[k],re.I):errors.append(f'{prefix}: clinical word "{w}" in {k}')
  for s in sentences(d[k]):
   if len(words(s))>MAX_SENTENCE:errors.append(f'{prefix}: {k} sentence of {len(words(s))} words: {s[:60]}')
 return errors
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
 p=argparse.ArgumentParser();p.add_argument('--file',type=Path,default=ROOT/'content/lessons_v2.json');p.add_argument('--partial',action='store_true')
 p.add_argument('--require-voice',action='store_true',help='every day must be written in the First Light voice (release gate)');a=p.parse_args()
 ds=json.loads(a.file.read_text());vs=json.loads((ROOT/'tool/scripture/verses.json').read_text());es=validate(ds,vs,a.partial)
 written=set(json.loads(VOICE.read_text())['days']) if VOICE.exists() else set()
 for d in ds:
  if d.get('day') in written:es+=voice_errors(d)
 if a.require_voice and len(written)<365:es.append(f'{365-len(written)} days are not yet in the First Light voice')
 if es:
  print('\n'.join(es),file=sys.stderr);return 1
 totals=[sum(len(words(d[k])) for k in ('verse','meaning','heart','prayer')) for d in ds]
 grades=[grade(' '.join(d[k] for k in ('meaning','heart','prayer'))) for d in ds if d['day'] in written]
 voice=f' First Light voice: {len(written)}/365 days, reading grade {min(grades):.1f}–{max(grades):.1f}.' if grades else ''
 print(f'{len(ds)} lessons pass: exact WEB, card ranges, unique sentences, trigram overlap, voice bans, prayer endings, teasers. Four-screen words {min(totals)}–{max(totals)}.'+voice);return 0
if __name__=='__main__':raise SystemExit(main())
