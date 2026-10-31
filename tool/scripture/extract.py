"""Extract scripture text from the pinned, unmodified eBible USFX corpus."""
import xml.etree.ElementTree as ET
from pathlib import Path
import json, hashlib
ROOT = Path(__file__).parent
names = {b.attrib['code']: b.attrib['short'] for b in ET.parse(ROOT/'book_names.xml').getroot()}
names['PSA'] = 'Psalm'
verses = {}
for book in ET.parse(ROOT/'web.xml').getroot().findall('book'):
    code=book.attrib.get('id'); chapter=None; active=None
    if code not in names: continue
    def walk(node):
        global chapter, active
        if node.tag in {'f','x','fig','rem'}: return
        if node.tag == 'c': chapter=node.attrib['id']; active=None
        elif node.tag == 'v':
            verse=node.attrib['id']
            active=f'{names[code]} {chapter}:{verse}'
            verses[active]=[]
        elif node.tag == 've': active=None
        if active and node.text: verses[active].append(node.text)
        for child in node:
            walk(child)
            if active and child.tail: verses[active].append(child.tail)
        if active and node.tag in {'p','q','d'}: verses[active].append(' ')
    walk(book)
result={k:' '.join(''.join(v).split()) for k,v in verses.items()}
(ROOT/'verses.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
provenance=json.loads((ROOT/'provenance.json').read_text()); provenance['textSha256']=hashlib.sha256((ROOT/'web.xml').read_bytes()).hexdigest(); (ROOT/'provenance.json').write_text(json.dumps(provenance,indent=2)+'\n')
print(len(result),'verses')
for key in ['Deuteronomy 31:6','Isaiah 41:10','Psalm 46:1','Romans 8:31','Jeremiah 29:11','John 14:27','Galatians 6:9']:
 print(key,result[key])
