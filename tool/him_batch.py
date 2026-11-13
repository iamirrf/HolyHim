#!/usr/bin/env python3
"""Show or apply a HolyHim lesson batch (written in order, at most 28 days).

  python3 tool/him_batch.py show 1 28
  python3 tool/him_batch.py apply batch.json

A batch file is {"units": [{id, title, summary}], "lessons": [{day, title, theme,
meaning, heart, holdOn, prayer, teaser, reference?}]}. A `reference` replaces the
passage: its `verse` is copied from the pinned World English Bible corpus, so the
quotation is exact by construction. REPICKS lists HolyHim's planned passages.
Applied days are recorded in content/voice.json so the voice gates apply.
"""
from __future__ import annotations
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from verify_lessons import validate, voice_errors, grade, ROOT  # noqa: E402

LESSONS = ROOT / 'content/lessons_v2.json'
UNITS = ROOT / 'content/units.json'
VOICE = ROOT / 'content/voice.json'
VERSES = json.loads((ROOT / 'tool/scripture/verses.json').read_text())
PROSE = ('title', 'theme', 'meaning', 'heart', 'holdOn', 'prayer', 'teaser')

# HolyHim's reading plan: day -> passage, where it differs from the inherited one.
REPICKS = {
    2: 'Psalm 119:9', 3: '1 Corinthians 10:13', 4: '1 Samuel 16:7', 5: 'Proverbs 27:17',
    6: '1 Timothy 4:12', 13: 'Genesis 4:7', 14: 'Genesis 12:1', 46: 'Proverbs 18:24',
    47: 'Ecclesiastes 4:12', 48: 'Proverbs 27:6', 49: '1 Samuel 18:3', 50: 'John 15:13',
    51: '1 Samuel 2:26', 52: '1 Samuel 3:19', 56: '1 Samuel 17:47', 64: '1 Kings 2:2',
    82: 'Isaiah 41:10', 86: 'Job 31:1', 140: 'Psalm 71:5', 146: 'Psalm 101:3',
    162: 'Proverbs 6:6', 170: 'Proverbs 22:29', 171: 'Proverbs 20:7', 172: 'Proverbs 25:28',
    177: 'Daniel 1:8', 179: 'Daniel 3:17-18', 204: 'Matthew 16:24', 214: 'Mark 8:36',
    220: 'Mark 1:17', 221: 'John 14:27', 223: 'Luke 2:52', 230: 'Luke 16:10', 233: 'Luke 14:28',
    260: 'Romans 12:21', 263: '1 Corinthians 16:13', 264: 'Romans 8:31', 265: '1 Corinthians 9:24',
    276: 'Ephesians 6:10', 282: 'Philippians 4:13', 288: 'Colossians 3:23', 305: '1 Timothy 6:11',
    309: '2 Timothy 2:22', 315: 'Titus 2:6', 339: '1 Peter 5:8',
}


def passage(reference: str) -> str:
    m = re.fullmatch(r'(.+) (\d+):(\d+)(?:-(\d+))?', reference)
    if not m:
        raise SystemExit(f'Invalid reference {reference}')
    book, chapter, a, b = m.groups()
    return ' '.join(VERSES[f'{book} {chapter}:{n}'] for n in range(int(a), int(b or a) + 1))


def show(a: int, b: int) -> None:
    lessons = json.loads(LESSONS.read_text())
    for d in lessons[a - 1:b]:
        ref = REPICKS.get(d['day'], d['reference'])
        verse = passage(ref)
        flag = ' (new)' if ref != d['reference'] else ''
        print(f"## {d['day']} · {ref}{flag}\nV: {verse}\n")


def apply(path: str) -> int:
    lessons = json.loads(LESSONS.read_text())
    units = json.loads(UNITS.read_text())
    batch = json.loads(Path(path).read_text())
    voice = json.loads(VOICE.read_text()) if VOICE.exists() else {'days': []}
    for item in batch.get('lessons', []):
        day = item['day']
        target = lessons[day - 1]
        assert target['day'] == day
        extra = set(item) - {'day', 'reference', *PROSE}
        assert not extra and set(PROSE) <= set(item), f'Day {day}: fields {sorted(item)}'
        reference = item.get('reference') or REPICKS.get(day, target['reference'])
        target['reference'], target['verse'] = reference, passage(reference)
        for k in PROSE:
            target[k] = item[k].strip()
        if day not in voice['days']:
            voice['days'].append(day)
    for unit in batch.get('units', []):
        row = next(u for u in units if u['id'] == unit['id'])
        row['title'], row['summary'] = unit['title'].strip(), unit['summary'].strip()
    voice['days'].sort()
    days = {i['day'] for i in batch.get('lessons', [])}
    errors = [e for e in validate(lessons, VERSES) if any(e.startswith(f'Day {d}:') for d in days)]
    for d in lessons:
        if d['day'] in days:
            errors += voice_errors(d)
    refs = [d['reference'] for d in lessons]
    errors += [f'Duplicate reference {r}' for r in sorted({r for r in refs if refs.count(r) > 1})]
    LESSONS.write_text(json.dumps(lessons, ensure_ascii=False, indent=2) + '\n')
    UNITS.write_text(json.dumps(units, ensure_ascii=False, indent=2) + '\n')
    VOICE.write_text(json.dumps(voice, indent=1) + '\n')
    if days:
        grades = [grade(' '.join(d[k] for k in ('meaning', 'heart', 'prayer'))) for d in lessons if d['day'] in days]
        print(f'Applied {len(days)} days; grade {min(grades):.1f}-{max(grades):.1f}; voice days {len(voice["days"])}/365')
    print('\n'.join(errors) if errors else 'No errors for this batch.')
    return 1 if errors else 0


if __name__ == '__main__':
    if sys.argv[1] == 'show':
        show(int(sys.argv[2]), int(sys.argv[3]))
    else:
        raise SystemExit(apply(sys.argv[2]))
