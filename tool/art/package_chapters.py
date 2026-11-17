#!/usr/bin/env python3
"""Package reviewed chapter masters and inventory all 73 canonical chapters."""
import hashlib
import json
import re
import shutil
from pathlib import Path
from PIL import Image, ImageOps, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
UNITS = json.loads((ROOT / 'content/units.json').read_text())
LESSONS = json.loads((ROOT / 'content/lessons_v2.json').read_text())
ORIGINALS = ROOT / 'art/generated/chapters'
DEST = ROOT / 'assets/art/chapters'
SPECS = {
    'portrait': ('portrait.webp', (1080, 1920), 86),
    'landscape': ('landscape.webp', (1280, 720), 86),
    'portraitThumb': ('portrait-thumb.webp', (270, 480), 80),
    'subjectThumb': ('subject-thumb.webp', (256, 256), 80),
}

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def master(folder, name):
    """A chapter's original: HolyHim keeps Gemini's photographs as JPEG."""
    for ext in ('jpg', 'jpeg', 'png'):
        if (folder / f'{name}.{ext}').is_file():
            return folder / f'{name}.{ext}'
    return folder / f'{name}.jpg'

def package(source, target, size, quality, centering=(.5, .5)):
    with Image.open(source) as original:
        image = ImageOps.fit(original.convert('RGB'), size,
            method=Image.Resampling.LANCZOS, centering=centering)
    target.parent.mkdir(parents=True, exist_ok=True)
    image.save(target, 'WEBP', quality=quality, method=6)
    with Image.open(target) as check:
        assert check.size == size and check.format == 'WEBP'
    return {'path': str(target.relative_to(ROOT)), 'width': size[0],
            'height': size[1], 'sha256': digest(target), 'bytes': target.stat().st_size}

def main():
    assert len(UNITS) == 73 and len(LESSONS) == 365
    review_file = ROOT / 'art/chapter-visual-review.json'
    visual_reviews = json.loads(review_file.read_text()).get('chapters', {}) if review_file.is_file() else {}
    rows = []
    for unit in UNITS:
        folder = unit['id']
        first, last = unit['firstDay'], unit['lastDay']
        chapter_lessons = LESSONS[first - 1:last]
        assert len(chapter_lessons) == 5 and [x['day'] for x in chapter_lessons] == list(range(first, last + 1))
        originals = ORIGINALS / folder
        portrait, landscape = master(originals, 'portrait'), master(originals, 'landscape')
        row = {'id': folder, 'title': unit['title'], 'firstDay': first,
               'lastDay': last, 'lessonTitles': [x['title'] for x in chapter_lessons],
               'focalPoints': {'portrait': [.5, .70], 'landscape': [.5, .5]},
               'status': 'pending originals', 'visualReview': 'pending',
               'masters': {}, 'assets': {}}
        if portrait.is_file() and landscape.is_file():
            for key, source in [('portrait', portrait), ('landscape', landscape)]:
                row['masters'][key] = {'path': str(source.relative_to(ROOT)),
                                       'sha256': digest(source)}
            reviewed = visual_reviews.get(folder, {})
            if (reviewed.get('portraitSha256') == row['masters']['portrait']['sha256']
                    and reviewed.get('landscapeSha256') == row['masters']['landscape']['sha256']):
                row['visualReview'] = 'passed'
                row['status'] = 'packaged; visual review passed; device review pending'
            else:
                row['visualReview'] = 'stale' if reviewed else 'pending'
                row['status'] = 'packaged; visual and device review pending'
            folder_out = DEST / folder
            row['assets']['portrait'] = package(portrait, folder_out / SPECS['portrait'][0], SPECS['portrait'][1], SPECS['portrait'][2], (.5, .65))
            row['assets']['landscape'] = package(landscape, folder_out / SPECS['landscape'][0], SPECS['landscape'][1], SPECS['landscape'][2])
            row['assets']['portraitThumb'] = package(portrait, folder_out / SPECS['portraitThumb'][0], SPECS['portraitThumb'][1], SPECS['portraitThumb'][2], (.5, .65))
            row['assets']['subjectThumb'] = package(portrait, folder_out / SPECS['subjectThumb'][0], SPECS['subjectThumb'][1], SPECS['subjectThumb'][2], (.5, .8))
            widget_thumb = ROOT / 'ios/HolyHimWidget/Art' / f'{folder}-thumb.jpg'
            widget_thumb.parent.mkdir(parents=True, exist_ok=True)
            with Image.open(ROOT / row['assets']['portraitThumb']['path']) as image:
                image.convert('RGB').save(widget_thumb, 'JPEG', quality=83, optimize=True)
            row['widgetAsset'] = {'path': str(widget_thumb.relative_to(ROOT)),
                                  'sha256': digest(widget_thumb),
                                  'bytes': widget_thumb.stat().st_size}
        rows.append(row)
    total = sum(asset['bytes'] for row in rows for asset in row['assets'].values())
    manifest = {'version': 1, 'source': 'content/units.json', 'chapters': rows,
                'packagedAssets': sum(len(row['assets']) for row in rows),
                'assetBytes': total, 'targetAssetBytes': 45 * 1024 * 1024}
    (ROOT / 'art/chapter-manifest.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + '\n')
    ready = [row for row in rows if row['assets']]
    artwork_revision = hashlib.sha256(''.join(
        asset['sha256'] for row in ready for asset in row['assets'].values()
    ).encode()).hexdigest()[:12]
    catalog = '''// Generated by tool/art/package_chapters.py from content/units.json and packaged assets.
class ChapterArt {
  const ChapterArt(this.id, this.title, this.firstDay, this.lastDay, this.hasAssets);
  final String id;
  final String title;
  final int firstDay;
  final int lastDay;
  final bool hasAssets;
}

abstract final class ChapterCatalog {
  static const artworkRevision = 'ARTWORK_REVISION';
  static const chapters = <ChapterArt>[
'''.replace('ARTWORK_REVISION', artwork_revision)
    for row in rows:
        catalog += (f"    ChapterArt({json.dumps(row['id'])}, {json.dumps(row['title'], ensure_ascii=False)}, "
                    f"{row['firstDay']}, {row['lastDay']}, {'true' if row['assets'] else 'false'}),\n")
    catalog += '''  ];
  static ChapterArt? forDay(int day) => day >= 1 && day <= 365
      ? chapters[(day - 1) ~/ 5]
      : null;
}
'''
    (ROOT / 'lib/design/chapter_catalog.g.dart').write_text(catalog)
    pubspec = ROOT / 'pubspec.yaml'
    source = pubspec.read_text()
    chapter_lines = ''.join(f"    - assets/art/chapters/{row['id']}/\n" for row in ready)
    lines = source.splitlines(keepends=True)
    lines = [line for line in lines if not re.fullmatch(r'    - assets/art/chapters/unit-\d\d/\n', line)]
    anchor = '    - assets/art/library/\n'
    assert lines.count(anchor) == 1
    lines.insert(lines.index(anchor) + 1, chapter_lines)
    pubspec.write_text(''.join(lines))
    site_rows = []
    site_images = ROOT / 'public/images'
    for row in rows:
        landscape_url = None
        if row['assets']:
            number = row['id'].split('-')[1]
            image_name = f'chapter-{number}-landscape.webp'
            shutil.copyfile(ROOT / row['assets']['landscape']['path'],
                            site_images / image_name)
            landscape_url = f'/images/{image_name}'
        site_rows.append({'id': row['id'], 'title': row['title'],
                          'firstDay': row['firstDay'], 'lastDay': row['lastDay'],
                          'landscape': landscape_url})
    (ROOT / 'public/chapters.json').write_text(json.dumps(
        {'version': 1, 'chapters': site_rows}, ensure_ascii=False,
        separators=(',', ':')) + '\n')
    if ready:
        width, height = 270, 480
        columns = min(8, len(ready))
        sheet = Image.new('RGB', (columns * width,
                                  ((len(ready) + columns - 1) // columns) * (height + 38)), '#0e1217')
        draw = ImageDraw.Draw(sheet)
        for index, row in enumerate(ready):
            x, y = (index % columns) * width, (index // columns) * (height + 38)
            with Image.open(ROOT / row['assets']['portraitThumb']['path']) as image:
                sheet.paste(image.convert('RGB'), (x, y))
            draw.text((x + 8, y + height + 10), row['id'], fill='#49353e')
        sheet.save(ROOT / 'store/redesign-v3/chapter-contact-sheet.jpg', quality=88)
    print(f"{len(ready)}/73 chapter sets packaged; {manifest['packagedAssets']}/292 assets; {total / 1024 / 1024:.2f} MiB")

if __name__ == '__main__':
    main()
