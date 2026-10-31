"""Configure HolyHer's own Firebase project using the active gcloud login."""
import subprocess, json, urllib.request, urllib.error, plistlib
from pathlib import Path
cloud=json.loads(Path('config/cloud.json').read_text())
PROJECT=cloud['projectId']
account=cloud['account']
config=plistlib.loads(Path('ios/Runner/GoogleService-Info.plist').read_bytes())
assert config['PROJECT_ID']==PROJECT, 'Refresh the Firebase app configuration first.'
assert config['BUNDLE_ID']=='com.holyher.app'
token=subprocess.check_output(['gcloud','auth','print-access-token','--account='+account],text=True).strip()
def request(method,url,body=None):
 req=urllib.request.Request(url,data=None if body is None else json.dumps(body).encode(),method=method,headers={'Authorization':'Bearer '+token,'Content-Type':'application/json','x-goog-user-project':PROJECT})
 try:
  with urllib.request.urlopen(req,timeout=45) as r:return json.load(r)
 except urllib.error.HTTPError as e:
  text=e.read().decode()
  print(method,url,e.code,text[:600]);raise
base='https://identitytoolkit.googleapis.com'
try: request('GET',base+'/admin/v2/projects/'+PROJECT+'/config')
except urllib.error.HTTPError as e:
 if e.code not in (400,404):raise
 request('POST',base+'/v2/projects/'+PROJECT+'/identityPlatform:initializeAuth',{})
request('PATCH',base+'/admin/v2/projects/'+PROJECT+'/config?updateMask=signIn.email.enabled,signIn.email.passwordRequired,authorizedDomains',{'signIn':{'email':{'enabled':True,'passwordRequired':True}},'authorizedDomains':[PROJECT+'.firebaseapp.com',PROJECT+'.web.app','localhost']})
print('Email authentication and authorized domains configured.')
p=plistlib.loads(Path('ios/Runner/GoogleService-Info.plist').read_bytes())
# Firebase configuration is public app identity, not a server credential.
Path('lib/firebase_options.dart').write_text("import 'package:firebase_core/firebase_core.dart';\nabstract final class HolyHerFirebaseOptions {\n static const googleClientId = "+json.dumps(p.get('CLIENT_ID',''))+";\n static const ios = FirebaseOptions(\n"+''.join('  '+k+': '+json.dumps(v)+',\n' for k,v in {'apiKey':p['API_KEY'],'appId':p['GOOGLE_APP_ID'],'messagingSenderId':p['GCM_SENDER_ID'],'projectId':p['PROJECT_ID'],'storageBucket':p['STORAGE_BUCKET'],'iosBundleId':p['BUNDLE_ID']}.items())+');\n}\n')

if p.get('REVERSED_CLIENT_ID'):
    info_path=Path('ios/Runner/Info.plist')
    info=plistlib.loads(info_path.read_bytes())
    scheme=p['REVERSED_CLIENT_ID']
    types=info.get('CFBundleURLTypes',[])
    if not any(scheme in row.get('CFBundleURLSchemes',[]) for row in types):
        types.append({'CFBundleURLSchemes':[scheme]})
    info['CFBundleURLTypes']=types
    info['GIDClientID']=p['CLIENT_ID']
    info_path.write_bytes(plistlib.dumps(info))
    print('Native Google sign-in client and callback scheme configured.')
