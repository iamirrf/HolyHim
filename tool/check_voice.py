#!/usr/bin/env python3
"""HolyHim's own voice rules for the lessons, beyond the shared validator.

content/STYLE.md bans the words of hype and the manosphere: warrior, alpha,
grind, hustle, crush it, level up, beast mode, "real men", and journey as a
cliché. tool/verify_lessons.py is shared with the engine and does not know
them, so this checks every lesson's words and titles for them.

A use that is plainly not that voice (David "a king and a warrior", God as
"the Alpha and the Omega") is allowed only by name in content/voice-allow.json,
with the reason a reader agreed it is right.

  python3 tool/check_voice.py           # exit 1 and list every problem
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LESSONS = ROOT / 'content/lessons_v2.json'
ALLOW = ROOT / 'content/voice-allow.json'
BANNED = ('warrior', 'alpha', 'grind', 'hustle', 'crush it', 'level up', 'beast mode',
          'real men', 'real man', 'journey', 'manhood', 'masculinity', 'boss up')
FIELDS = ('title', 'teaser', 'meaning', 'heart', 'holdOn', 'prayer')


def problems(lessons: list[dict], allow: dict[str, dict]) -> list[str]:
    found = []
    for lesson in lessons:
        allowed = {word.lower() for word in allow.get(str(lesson['day']), {}).get('words', [])}
        for field in FIELDS:
            for word in BANNED:
                if word in allowed:
                    continue
                if re.search(r'\b' + re.escape(word) + r'\w*\b', lesson[field], re.I):
                    found.append(f"Day {lesson['day']}: {field} uses \"{word}\" (content/STYLE.md)")
    for day, entry in allow.items():
        if not entry.get('reason'):
            found.append(f'content/voice-allow.json: Day {day} needs the reason it is allowed')
    return found


def main() -> int:
    lessons = json.loads(LESSONS.read_text(encoding='utf-8'))
    allow = json.loads(ALLOW.read_text(encoding='utf-8')) if ALLOW.exists() else {}
    found = problems(lessons, allow)
    if found:
        print('\n'.join(found))
        return 1
    print(f'{len(lessons)} lessons keep HolyHim\'s voice rules ({len(allow)} reviewed exceptions).')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
