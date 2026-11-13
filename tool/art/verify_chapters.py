#!/usr/bin/env python3
"""Independently verify the generated chapter inventory and packaged assets."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SIZES = {
    'portrait': (1080, 1920),
    'landscape': (1280, 720),
    'portraitThumb': (270, 480),
    'subjectThumb': (256, 256),
}


def verify_file(record, *, size=None, kind=None):
    path = ROOT / record['path']
    assert path.is_file(), path
    data = path.read_bytes()
    assert len(data) == record.get('bytes', len(data)), path
    assert hashlib.sha256(data).hexdigest() == record['sha256'], path
    with Image.open(path) as image:
        image.verify()
    with Image.open(path) as image:
        if size is not None:
            assert image.size == size, path
            assert [record['width'], record['height']] == list(size), path
        if kind is not None:
            assert image.format == kind, path
    return len(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-complete', action='store_true')
    args = parser.parse_args()
    units = json.loads((ROOT / 'content/units.json').read_text())
    lessons = json.loads((ROOT / 'content/lessons_v2.json').read_text())
    manifest = json.loads((ROOT / 'art/chapter-manifest.json').read_text())
    review_path = ROOT / 'art/chapter-visual-review.json'
    reviews = json.loads(review_path.read_text()).get('chapters', {}) if review_path.is_file() else {}
    website = json.loads((ROOT / 'public/chapters.json').read_text())
    rows = manifest['chapters']
    assert len(units) == len(rows) == len(website['chapters']) == 73
    assert len(lessons) == 365
    pubspec = (ROOT / 'pubspec.yaml').read_text()
    total = ready = 0
    for unit, row, web in zip(units, rows, website['chapters']):
        assert (row['id'], row['title'], row['firstDay'], row['lastDay']) == (
            unit['id'], unit['title'], unit['firstDay'], unit['lastDay'])
        assert row['lessonTitles'] == [lesson['title'] for lesson in
                                       lessons[unit['firstDay'] - 1:unit['lastDay']]]
        assert all(0 <= value <= 1 for point in row['focalPoints'].values()
                   for value in point)
        assert (web['id'], web['title'], web['firstDay'], web['lastDay']) == (
            unit['id'], unit['title'], unit['firstDay'], unit['lastDay'])
        directory = f"    - assets/art/chapters/{row['id']}/"
        if not row['assets']:
            assert row['masters'] == {} and web['landscape'] is None
            assert row['visualReview'] == 'pending'
            assert directory not in pubspec
            continue
        ready += 1
        assert set(row['assets']) == set(SIZES)
        assert set(row['masters']) == {'portrait', 'landscape'}
        assert pubspec.count(directory) == 1
        for key, record in row['assets'].items():
            assert record['path'].startswith(f"assets/art/chapters/{row['id']}/")
            total += verify_file(record, size=SIZES[key], kind='WEBP')
        for record in row['masters'].values():
            assert record['path'].startswith(f"art/generated/chapters/{row['id']}/")
            verify_file(record, kind='PNG')
        review = reviews.get(row['id'], {})
        matching_review = (review.get('portraitSha256') == row['masters']['portrait']['sha256']
                           and review.get('landscapeSha256') == row['masters']['landscape']['sha256'])
        assert row['visualReview'] == ('passed' if matching_review else
                                      'stale' if review else 'pending')
        verify_file(row['widgetAsset'], kind='JPEG')
        number = row['id'].split('-')[1]
        assert web['landscape'] == f'/images/chapter-{number}-landscape.webp'
        assert hashlib.sha256((ROOT / 'public' / web['landscape'].lstrip('/')).read_bytes()).hexdigest() == (
            row['assets']['landscape']['sha256'])
    assert manifest['packagedAssets'] == ready * 4
    assert manifest['assetBytes'] == total
    assert total <= manifest['targetAssetBytes'] == 45 * 1024 * 1024
    if args.require_complete:
        assert ready == 73, f'{73 - ready} chapter sets remain unfinished'
        assert all(row['visualReview'] == 'passed' for row in rows)
    print(f'{ready}/73 chapter sets verified; {ready * 4}/292 assets; '
          f'{total / 1024 / 1024:.2f} MiB / 45 MiB')


if __name__ == '__main__':
    main()
