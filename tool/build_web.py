"""Build the shared Flutter app under /app/ while retaining Firebase public routes."""
import hashlib,json,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
if '--package-only' not in sys.argv:
 subprocess.run(['python3','tool/prepare_web_firebase.py'],cwd=ROOT,check=True)
 subprocess.run(['flutter','build','web','--release','--base-href','/app/','--no-web-resources-cdn','--pwa-strategy=none'],cwd=ROOT,check=True)
source=ROOT/'build/web';target=ROOT/'public/app'
if target.exists():shutil.rmtree(target)
shutil.copytree(source,target)
worker=target/'holyhim-sw.js'
digest=hashlib.sha256()
generated_files=sorted(p for p in source.rglob('*') if p.is_file())
for path in generated_files:
 digest.update(str(path.relative_to(source)).encode());digest.update(path.read_bytes())
revision=digest.hexdigest()[:16]
worker.write_text(worker.read_text().replace('holyhim-shell-v2','holyhim-shell-'+revision))
(ROOT/'store/v2-web-build.json').write_text(json.dumps({'basePath':'/app/','source':'web/','output':'public/app/','shellVersion':revision,'hashScope':'all generated application files','files':len(generated_files),'productionDeployed':False},indent=2)+'\n')
print('Prepared public/app/. Support, legal and marketing routes are retained. No deployment performed.')
