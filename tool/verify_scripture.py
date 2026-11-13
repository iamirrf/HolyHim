"""Read-only verification of all 365 quotations against pinned eBible USFX XML.

This never refreshes or rewrites evidence. After intentional editorial changes,
rebuild with python3 tool/build_lessons.py and rerun this independent comparison.
"""
from __future__ import annotations
import sys
import xml.etree.ElementTree as ET
import zipfile
from build_lessons import ROOT, SCRIPTURE, artifacts, load_content, passage, read_json, sha256, verse_keys


def xml_tokens(node):
    # Separate token-stream implementation from extract.py's mutable accumulator.
    # Footnote/cross-reference content is excluded; its tail remains verse text.
    if node.tag in {'f', 'x', 'fig', 'rem'}:
        return
    if node.tag == 'c':
        yield 'chapter', node.attrib['id']
    elif node.tag == 'v':
        yield 'verse', node.attrib['id']
    elif node.tag == 've':
        yield 'end', ''
    if node.tag in {'p', 'q', 'd'}:
        yield 'text', ' '
    if node.text:
        yield 'text', node.text
    for child in node:
        yield from xml_tokens(child)
        if child.tail:
            yield 'text', child.tail
    if node.tag in {'p', 'q', 'd'}:
        yield 'text', ' '


def parse_pinned_xml() -> dict[str, str]:
    names = {book.attrib['code']: book.attrib['short'] for book in ET.parse(SCRIPTURE / 'book_names.xml').getroot()}
    names['PSA'] = 'Psalm'
    result = {}
    for book in ET.parse(SCRIPTURE / 'web.xml').getroot().findall('book'):
        code = book.attrib['id']
        if code not in names:
            continue
        chapter = active = None
        parts = []
        for kind, text in xml_tokens(book):
            if kind in {'chapter', 'verse', 'end'}:
                if active:
                    result[active] = ' '.join(''.join(parts).split())
                active, parts = None, []
                if kind == 'chapter':
                    chapter = text
                elif kind == 'verse':
                    active = f'{names[code]} {chapter}:{text}'
                    if active in result:
                        raise ValueError(f'Duplicate XML verse marker: {active}')
            elif active:
                parts.append(text)
        if active:
            result[active] = ' '.join(''.join(parts).split())
    return result


def main() -> int:
    provenance = read_json(SCRIPTURE / 'provenance.json')
    archive_bytes = (SCRIPTURE / 'web.zip').read_bytes()
    xml_bytes = (SCRIPTURE / 'web.xml').read_bytes()
    if sha256(archive_bytes) != provenance['archiveSha256']:
        raise ValueError('Pinned archive SHA-256 mismatch')
    if sha256(xml_bytes) != provenance['textSha256']:
        raise ValueError('Pinned XML SHA-256 mismatch')
    with zipfile.ZipFile(SCRIPTURE / 'web.zip') as archive:
        if archive.read('engwebp_usfx.xml') != xml_bytes:
            raise ValueError('Pinned XML differs from its original archive entry')
        if archive.read('BookNames.xml') != (SCRIPTURE / 'book_names.xml').read_bytes():
            raise ValueError('Book-name metadata differs from the pinned archive')
    independently_parsed = parse_pinned_xml()
    cached = read_json(SCRIPTURE / 'verses.json')
    if independently_parsed != cached:
        mismatches = [key for key in set(cached) | set(independently_parsed) if cached.get(key) != independently_parsed.get(key)]
        raise ValueError('Verse cache differs from independently parsed XML: ' + ', '.join(sorted(mismatches)[:8]))
    lessons = load_content()
    fixture = read_json(ROOT / 'test/fixtures/scripture.json')
    if len(fixture) != 365:
        raise ValueError('Provenance fixture must cover all 365 lessons')
    for lesson, source in zip(lessons, fixture):
        exact_text = passage(lesson['reference'], independently_parsed)
        if source['day'] != lesson['day'] or source['reference'] != lesson['reference']:
            raise ValueError(f"Day {lesson['day']}: evidence order or reference mismatch")
        if source['text'] != exact_text or source['verseSha256'] != sha256(exact_text.encode('utf-8')):
            raise ValueError(f"Day {lesson['day']}: quotation differs from pinned XML")
        if source['verseKeys'] != verse_keys(lesson['reference']):
            raise ValueError(f"Day {lesson['day']}: verse-range evidence mismatch")
    for path, expected in artifacts().items():
        if not path.exists() or path.read_text(encoding='utf-8') != expected:
            raise ValueError(f'Stale or edited generated artifact: {path.relative_to(ROOT)}')
    quoted_count = len({key for lesson in lessons for key in verse_keys(lesson['reference'])})
    print(f'365 lessons verified: {quoted_count} quoted verses; all {len(cached):,} cached verses match independently parsed pinned XML.')
    print('Archive/XML hashes and original archive entries verified; v2 source, Dart catalog and provenance fixture match. No files rewritten.')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (KeyError, ValueError, OSError, zipfile.BadZipFile) as error:
        print(f'Scripture verification failed: {error}', file=sys.stderr)
        raise SystemExit(1)
