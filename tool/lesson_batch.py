#!/usr/bin/env python3
"""Show a lesson batch for writing, or apply a rewritten batch.

  python3 tool/lesson_batch.py show 1 28
  python3 tool/lesson_batch.py apply path/to/batch.json

A batch file is a JSON list of {day, meaning, heart, holdOn, prayer, teaser}.
`verse`, `reference`, `title` and `theme` are never changed here. Applied
days are recorded in content/voice.json so the First Light gates apply.
"""
import json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from verify_lessons import validate, voice_errors, grade, ROOT  # noqa: E402

LESSONS = ROOT / 'content/lessons_v2.json'
VOICE = ROOT / 'content/voice.json'
FIELDS = ('meaning', 'heart', 'holdOn', 'prayer', 'teaser')

def show(a, b):
    for d in json.loads(LESSONS.read_text())[a - 1:b]:
        print(f"## {d['day']} · {d['title']} · {d['theme']} · {d['reference']}")
        print(f"V: {d['verse']}")
        print(f"M: {d['meaning']}\n")

def apply(path):
    lessons = json.loads(LESSONS.read_text())
    batch = json.loads(Path(path).read_text())
    voice = json.loads(VOICE.read_text()) if VOICE.exists() else {'days': []}
    for item in batch:
        day = item['day']
        target = lessons[day - 1]
        assert target['day'] == day
        assert set(item) == {'day', *FIELDS}, f'Day {day}: fields {sorted(item)}'
        for k in FIELDS:
            target[k] = item[k].strip()
        if day not in voice['days']:
            voice['days'].append(day)
    voice['days'].sort()
    verses = json.loads((ROOT / 'tool/scripture/verses.json').read_text())
    days = {i['day'] for i in batch}
    errors = [e for e in validate(lessons, verses)
              if any(e.startswith(f'Day {d}:') for d in days)]
    for d in lessons:
        if d['day'] in days:
            errors += voice_errors(d)
    LESSONS.write_text(json.dumps(lessons, ensure_ascii=False, indent=2) + '\n')
    VOICE.write_text(json.dumps(voice, indent=1) + '\n')
    grades = [grade(' '.join(d[k] for k in ('meaning', 'heart', 'prayer')))
              for d in lessons if d['day'] in days]
    print(f'Applied {len(batch)} days; grade {min(grades):.1f}–{max(grades):.1f}')
    print('\n'.join(errors) if errors else 'No errors for this batch.')
    return 1 if errors else 0

if __name__ == '__main__':
    if sys.argv[1] == 'show':
        show(int(sys.argv[2]), int(sys.argv[3]))
    else:
        raise SystemExit(apply(sys.argv[2]))
