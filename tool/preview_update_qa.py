"""Isolated local service-worker revision server; never deploy this helper."""
import http.server
from preview_public import Handler,ROOT
class UpdateHandler(Handler):
 revision=1
 def do_GET(self):
  if self.path=='/qa/revision/2':
   type(self).revision=2
   self.send_response(204);self.end_headers();return
  if self.path.split('?')[0]=='/app/holyher-sw.js':
   raw=(ROOT/'public/app/holyher-sw.js').read_text().replace("const VERSION='holyher-shell-",f"const VERSION='holyher-shell-update-qa-{type(self).revision}-")
   raw=raw.encode()
   self.send_response(200);self.send_header('Content-Type','text/javascript');self.send_header('Cache-Control','no-store');self.send_header('Content-Length',str(len(raw)));self.end_headers();self.wfile.write(raw);return
  return super().do_GET()
print('Isolated update QA server: http://127.0.0.1:4184',flush=True)
http.server.ThreadingHTTPServer(('127.0.0.1',4184),UpdateHandler).serve_forever()
