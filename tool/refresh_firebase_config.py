"""Fetch public Firebase iOS configuration with the explicitly selected Firebase login."""
import json, plistlib, subprocess, tempfile
from pathlib import Path
cloud=json.loads(Path('config/cloud.json').read_text())
project=cloud['projectId'];account=cloud['account'];app=cloud['firebaseIosAppId']
with tempfile.TemporaryDirectory(prefix='holyhim-firebase-') as directory:
    target=Path(directory)/'GoogleService-Info.plist'
    result=subprocess.run(['firebase','apps:sdkconfig','ios',app,'--project',project,'--account',account,'--out',str(target)],capture_output=True,text=True)
    if result.returncode:
        lines=[line for line in (result.stdout+'\n'+result.stderr).splitlines() if line.startswith('Error:')]
        raise SystemExit('Firebase configuration could not be fetched. '+(' '.join(lines) or 'Check the Firebase CLI login for '+account))
    raw=target.read_bytes()
config=plistlib.loads(raw)
assert config['PROJECT_ID']==project,'Wrong Firebase project returned'
assert config['BUNDLE_ID']=='com.holyhim.app','Wrong native app returned'
Path('ios/Runner/GoogleService-Info.plist').write_bytes(raw)
print('Verified Firebase iOS configuration:',project,'Google client configured:',bool(config.get('CLIENT_ID')))
