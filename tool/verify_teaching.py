"""Independent release gate: full teaching coverage, stable links and corpus preservation."""
import argparse, json, re, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--slice',action='store_true');args=p.parse_args()
source=json.loads((ROOT/'content/teaching.json').read_text());server=json.loads((ROOT/'functions/teaching.json').read_text())
assert source==server,'Client source and canonical server content differ'
original=sum([json.loads((ROOT/f'content/{name}').read_text()) for name in ['lessons_001_183.json','lessons_184_365.json']],[])
assert [v['day'] for v in original]==list(range(1,366))
ids=set();expected=list(range(1,6)) if args.slice else list(range(1,366))
assert [v['day'] for v in source['lessons']]==expected, f"Only {len(source['lessons'])}/365 enhanced lessons are authored. Release blocked."
for lesson in source['lessons']:
 day=lesson['day'];assert lesson['id']==f'day-{day:03}'
 assert len(lesson['questions'])==2
 for index,q in enumerate(lesson['questions'],1):
  assert q['id']==f'day-{day:03}-q{index}' and q['id'] not in ids;ids.add(q['id'])
  opts=q['options'];assert len(opts)==4
  assert len(set(o['id'] for o in opts))==len(set(o['text'].casefold() for o in opts))==4
  assert sum(o['id']==q['correctOptionId'] for o in opts)==1
  assert q['teachingSource']==f'day-{day:03}/{"understand" if index==1 else "hope"}'
  assert len(q['explanation'].split())>=10
units=json.loads((ROOT/'content/units.json').read_text());assert len(units)==len(set(u['title'] for u in units))==73
assert [d for u in units for d in range(u['firstDay'],u['lastDay']+1)]==list(range(1,366))
subprocess.run(['python3',str(ROOT/'tool/verify_scripture.py')],check=True,cwd=ROOT)
print(f'Independent verification passed for {len(source["lessons"])} enhanced lessons, {len(ids)} questions, 73 units, and original Scripture. '+('This is a vertical slice, not the full release gate.' if args.slice else 'Full release content gate passed.'))
