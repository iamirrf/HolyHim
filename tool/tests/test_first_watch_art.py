"""The packaged library photos and medallions must be the First Watch grade.

A HolyHer packager once overwrote them with the pink originals; this catches
that before a build does.
"""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class FirstWatchArtTest(unittest.TestCase):
    def test_packaged_art_matches_manifest(self):
        manifest = json.loads((ROOT / 'art/first-watch-manifest.json').read_text())
        rows = manifest['library'] + manifest.get('badges', [])
        self.assertGreaterEqual(len(manifest['library']), 25)
        for row in rows:
            for key in ('asset', 'thumb'):
                entry = row.get(key)
                if not entry:
                    continue
                path = ROOT / entry['path']
                self.assertTrue(path.exists(), entry['path'])
                digest = hashlib.sha256(path.read_bytes()).hexdigest()
                self.assertEqual(digest, entry['sha256'],
                                 f"{entry['path']} is not the First Watch grade; run tool/art/package_first_watch.py")


if __name__ == '__main__':
    unittest.main()
