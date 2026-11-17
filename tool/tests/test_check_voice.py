"""HolyHim's voice rules (content/STYLE.md) hold for every lesson."""
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tool'))
from check_voice import problems


class VoiceTests(unittest.TestCase):
    def test_every_lesson_keeps_the_voice(self):
        lessons = json.loads((ROOT / 'content/lessons_v2.json').read_text())
        allow = json.loads((ROOT / 'content/voice-allow.json').read_text())
        self.assertEqual(problems(lessons, allow), [])

    def test_hype_is_refused_and_a_reviewed_use_is_not(self):
        lesson = {'day': 9, 'title': 'Rise', 'teaser': '', 'meaning': 'Be a prayer warrior and grind.',
                  'heart': 'Real men level up.', 'holdOn': '', 'prayer': 'Amen.'}
        self.assertEqual(len(problems([lesson], {})), 4)
        self.assertEqual(len(problems([lesson], {'9': {'words': ['warrior', 'grind', 'real men', 'level up'],
                                                       'reason': 'test'}})), 0)
        self.assertTrue(problems([lesson], {'9': {'words': ['warrior']}}))


if __name__ == '__main__':
    unittest.main()
