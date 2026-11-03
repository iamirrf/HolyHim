"""Local Firebase-style static preview. Preserves support and /app routes."""
import argparse,http.server,os,urllib.parse
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
class Handler(http.server.SimpleHTTPRequestHandler):
 def __init__(self,*args,**kwargs):super().__init__(*args,directory=str(ROOT/'public'),**kwargs)
 def do_GET(self):
  path=urllib.parse.urlsplit(self.path).path
  if path.startswith('/app/') and not (ROOT/'public'/path.lstrip('/')).exists():self.path='/app/index.html'
  elif path in ['/privacy','/terms','/support']:self.path=path+'.html'
  return super().do_GET()
 def log_message(self,format,*args):pass
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--port',type=int,default=4173);args=parser.parse_args()
 print(f'Local preview: http://127.0.0.1:{args.port}',flush=True)
 http.server.ThreadingHTTPServer(('127.0.0.1',args.port),Handler).serve_forever()
