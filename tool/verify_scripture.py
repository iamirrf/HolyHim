"""Fetch public-domain KJV evidence for build-time auditing, never app runtime."""
import json
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import urlopen

REFERENCES = [
    'Deuteronomy 31:6', 'Isaiah 41:10', 'Psalm 46:1', 'Romans 8:31',
    'Jeremiah 29:11', 'John 14:27', 'Isaiah 40:31', 'Psalm 139:13-14',
    'Psalm 119:105', 'Matthew 11:28',
]

class Verses(HTMLParser):
    def __init__(self):
        super().__init__()
        self.spans = []
        self.sup = 0
        self.parts = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'sup':
            self.sup += 1
        if tag == 'span':
            classes = attrs.get('class', '').split()
            capture, suppress, upper = self.spans[-1] if self.spans else (False, False, False)
            if 'text' in classes and attrs.get('id', '').startswith('en-KJV-'):
                capture = True
                self.parts.append(' ')
            self.spans.append((capture, suppress or 'chapternum' in classes,
                               upper or 'small-caps' in classes))

    def handle_endtag(self, tag):
        if tag == 'sup':
            self.sup = max(0, self.sup - 1)
        if tag == 'span' and self.spans:
            self.spans.pop()

    def handle_data(self, data):
        if self.spans:
            capture, suppress, upper = self.spans[-1]
            if capture and not suppress and not self.sup:
                self.parts.append(data.upper() if upper else data)

results = []
for day, reference in enumerate(REFERENCES, 1):
    source = 'https://www.biblegateway.com/passage/?' + urlencode({'search': reference, 'version': 'KJV'})
    parser = Verses()
    with urlopen(source, timeout=30) as response:
        parser.feed(response.read().decode('utf-8'))
    text = ' '.join(''.join(parser.parts).split())
    if not text:
        raise ValueError('No verse text for ' + reference)
    results.append({'day': day, 'reference': reference, 'translation': 'KJV',
                    'source': source, 'text': text})
    print(f'Day {day}: {reference}: {text}')
Path('test/fixtures/scripture.json').write_text(json.dumps(results, indent=2) + '\n')
