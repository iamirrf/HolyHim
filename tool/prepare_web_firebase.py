"""Vendor the exact FlutterFire-supported public SDK for reliable offline starts.

Only public JavaScript is fetched. Firebase account data and credentials are never
part of this bundle. Upstream license notices are preserved in every source.
"""
import hashlib,json,re,urllib.parse,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
config=json.loads((ROOT/'.dart_tool/package_config.json').read_text())
package=next(p for p in config['packages'] if p['name']=='firebase_core_web')
base=urllib.parse.urljoin((ROOT/'.dart_tool/package_config.json').as_uri(),package['rootUri'])
source=Path(urllib.parse.unquote(urllib.parse.urlparse(base).path))/'lib/src/firebase_sdk_version.dart'
version=re.search(r"supportedFirebaseJsSdkVersion\s*=\s*'([^']+)'",source.read_text())[1]
folder=ROOT/'web/vendor/firebase'/version
folder.mkdir(parents=True,exist_ok=True)
manifest_file=folder/'manifest.json'
if manifest_file.exists():
 manifest=json.loads(manifest_file.read_text())
 for name,item in manifest['files'].items():
  if hashlib.sha256((folder/name).read_bytes()).hexdigest()!=item['localSha256']:
   raise RuntimeError(f'Vendored SDK checksum mismatch: {name}')
 print(f'Verified public Firebase SDK {version} ({len(manifest["files"])} modules).')
else:
 prefix=f'https://www.gstatic.com/firebasejs/{version}/'
 pending=['firebase-app.js','firebase-auth.js','firebase-firestore-pipelines.js','firebase-functions.js']
 files={}
 while pending:
  name=pending.pop(0)
  if name in files:continue
  with urllib.request.urlopen(prefix+name,timeout=45) as response:raw=response.read()
  text=raw.decode()
  refs=set(re.findall(re.escape(prefix)+r'([a-zA-Z0-9_.-]+\.js)',text))
  pending.extend(refs-set(files))
  local=text.replace(prefix,'./')
  # Source maps are not needed for the production runtime.
  local=re.sub(r'\n?//# sourceMappingURL=.*','',local)
  (folder/name).write_text(local)
  files[name]={'source':prefix+name,'sourceSha256':hashlib.sha256(raw).hexdigest(),'localSha256':hashlib.sha256(local.encode()).hexdigest()}
 manifest={'version':version,'license':'Apache-2.0; upstream notices retained','transformation':'Same-version absolute module imports changed to relative paths; source map comment removed.','files':files}
 manifest_file.write_text(json.dumps(manifest,indent=2)+'\n')
 print(f'Prepared public Firebase SDK {version} ({len(files)} modules).')
loader=f'''// Public SDK modules only. No account data is included here.
try {{
  window.firebase_core = await import('./vendor/firebase/{version}/firebase-app.js');
  const [auth, firestore, functions] = await Promise.all([
    import('./vendor/firebase/{version}/firebase-auth.js'),
    import('./vendor/firebase/{version}/firebase-firestore-pipelines.js'),
    import('./vendor/firebase/{version}/firebase-functions.js')
  ]);
  window.firebase_auth = auth;
  window.firebase_firestore = firestore;
  window.firebase_functions = functions;
  const bootstrap = document.createElement('script');
  bootstrap.src = '/app/flutter_bootstrap.js';
  bootstrap.onerror = () => window.dispatchEvent(new Event('error'));
  document.body.append(bootstrap);
}} catch (_) {{
  window.dispatchEvent(new Event('error'));
}}
'''
(ROOT/'web/firebase-loader.js').write_text(loader)
