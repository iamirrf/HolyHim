"""Idempotently register the HolyHim web app; retain public Firebase identity."""
import json,subprocess,urllib.request,time
from pathlib import Path
PROJECT='holyhim-app-production'
token=subprocess.run(['gcloud','auth','print-access-token','--account=iamirrf1@gmail.com','--verbosity=error'],check=True,capture_output=True,text=True).stdout.strip()
def call(method,path,data=None):
 r=urllib.request.Request('https://firebase.googleapis.com/v1beta1/'+path,method=method,headers={'Authorization':'Bearer '+token,'Content-Type':'application/json','x-goog-user-project':PROJECT},data=None if data is None else json.dumps(data).encode())
 with urllib.request.urlopen(r,timeout=40) as result:return json.load(result)
base='projects/'+PROJECT
apps=call('GET',base+'/webApps').get('apps',[])
app=next((a for a in apps if a.get('displayName')=='HolyHim Web'),None)
if app is None:
 op=call('POST',base+'/webApps',{'displayName':'HolyHim Web'})
 while not op.get('done'):
  time.sleep(1);op=call('GET',op['name'])
 app=op['response']
config=call('GET',base+'/webApps/'+app['appId']+'/config')
config['authDomain']=PROJECT+'.web.app'
Path('config/firebase-web.json').write_text(json.dumps(config,indent=2)+'\n')
p=Path('lib/firebase_options.dart');s=p.read_text();s=s[:s.rfind('}')]+"  static const web = FirebaseOptions(\n"+''.join('    '+k+': '+json.dumps(config[k])+',\n' for k in ['apiKey','appId','messagingSenderId','projectId','storageBucket','authDomain'])+'  );\n}\n';p.write_text(s)
print('HolyHim Web registration and same-origin auth domain prepared.')
