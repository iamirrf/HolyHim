"""Keep complete offline policy text aligned with prepared hosted documents."""
import argparse,json,subprocess
from html.parser import HTMLParser
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
class Extract(HTMLParser):
 def __init__(self):super().__init__();self.article=False;self.tag=None;self.buffer='';self.rows=[]
 def handle_starttag(self,tag,attrs):
  if tag=='article':self.article=True
  if self.article and tag in ('h2','p'):self.tag=tag;self.buffer=''
 def handle_data(self,text):
  if self.tag:self.buffer+=text
 def handle_endtag(self,tag):
  if tag==self.tag:self.rows.append((tag,self.buffer));self.tag=None
  if tag=='article':self.article=False
p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');args=p.parse_args()
lines=['// Generated from public/privacy.html and public/terms.html.','const legalDocuments = <String,List<(String,String)>>{']
for name in ('privacy','terms'):
 parser=Extract();parser.feed((ROOT/f'public/{name}.html').read_text());rows=[]
 for tag,text in parser.rows:
  if tag=='h2':rows.append([text,''])
  elif not rows:rows.append(['About this document',text])
  else:rows[-1][1]+=('\n\n' if rows[-1][1] else '')+text
 lines.append(json.dumps(name)+': [')
 # A Dart string reads $ as the start of an interpolation, as in "$1.99".
 dart=lambda s:json.dumps(s,ensure_ascii=False).replace('$','\\$')
 lines.extend('('+dart(title)+','+dart(text)+'),' for title,text in rows)
 lines.append('],')
lines.append('};')
text=subprocess.run(['dart','format','--output=show','--summary=none'],input='\n'.join(lines)+'\n',text=True,capture_output=True,check=True).stdout
path=ROOT/'lib/data/legal_documents.dart'
if args.check:assert path.read_text()==text,'Prepared hosted and offline policies differ'
else:path.write_text(text)
print('Prepared hosted and complete offline policy text match.')
