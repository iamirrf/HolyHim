#!/usr/bin/env python3
"""Record an already completed full-size portrait/landscape visual review."""
import argparse
from datetime import datetime
import hashlib
import json
from pathlib import Path
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parents[2]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--chapter', type=int, action='append', default=[])
    parser.add_argument('--range', dest='span', type=int, nargs=2,
                        metavar=('FIRST', 'LAST'))
    args = parser.parse_args()
    numbers = set(args.chapter)
    if args.span:
        numbers.update(range(args.span[0], args.span[1] + 1))
    assert numbers and all(1 <= number <= 73 for number in numbers)
    path = ROOT / 'art/chapter-visual-review.json'
    data = json.loads(path.read_text()) if path.is_file() else {'version': 1, 'chapters': {}}
    today = datetime.now(ZoneInfo('America/New_York')).date().isoformat()
    for number in sorted(numbers):
        chapter = f'unit-{number:02d}'
        folder = ROOT / 'art/generated/chapters' / chapter
        portrait, landscape = folder / 'portrait.png', folder / 'landscape.png'
        assert portrait.is_file() and landscape.is_file(), chapter
        data['chapters'][chapter] = {
            'portraitSha256': digest(portrait),
            'landscapeSha256': digest(landscape),
            'reviewedAt': today,
            'scope': 'Both photographic masters inspected at full size and in contact sheet; physical device pending',
        }
    path.write_text(json.dumps(data, indent=2) + '\n')
    print(f'Recorded full-size visual review for {len(numbers)} chapter sets.')


if __name__ == '__main__':
    main()
