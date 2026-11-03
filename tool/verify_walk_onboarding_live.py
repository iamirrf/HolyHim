"""Verify accepted schemas on the retained onboarding QA account; restore its draft."""
import datetime,json,plistlib,urllib.request,urllib.error
from pathlib import Path
from prepare_review_accounts import read_secret,http,AUTH
ROOT=Path(__file__).resolve().parents[1]
PROJECT='holyher-app-production'
_,credential=read_secret('onboarding')
native=plistlib.loads((ROOT/'ios/Runner/GoogleService-Info.plist').read_bytes())
signed=http('POST',AUTH+'accounts:signInWithPassword?key='+native['API_KEY'],{'email':credential['email'],'password':credential['password'],'returnSecureToken':True})
assert signed['localId']==credential['uid']
url=f'https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents/users/'+credential['uid']
def req(method,body=None,expected=200):
 request=urllib.request.Request(url,method=method,headers={'Content-Type':'application/json','Authorization':'Bearer '+signed['idToken']},data=None if body is None else json.dumps(body).encode())
 try:
  with urllib.request.urlopen(request,timeout=30) as r:status,raw=r.status,r.read()
 except urllib.error.HTTPError as e:status,raw=e.code,e.read()
 assert status==expected,f'QA profile returned HTTP {status}, expected {expected}'
 return json.loads(raw)
def field(v):
 if v is None:return {'nullValue':None}
 if isinstance(v,bool):return {'booleanValue':v}
 if isinstance(v,int):return {'integerValue':str(v)}
 if isinstance(v,list):return {'arrayValue':{'values':[field(x) for x in v]}}
 return {'stringValue':v}
initial=req('GET',expected=404)
original=initial.get('fields')
base={'name':'Onboarding QA','familiarity':'new','focus':'peace','obstacle':'busy','reminderMinutes':None,'onboardingComplete':False,'haptics':True,'onboardingVersion':2,'onboardingStepId':'day-one','onboardingStep':9}
checks=[]
try:
 for version,change in [(2,{}),(3,{'onboardingStepId':'arrival','onboardingStep':11,'onboardingAnswered':['name','focus'],'suggestedReminderMinutes':480,'reminderDecision':'denied','guidedExampleRevealed':False}),(4,{'onboardingStepId':'day-one','onboardingStep':3,'theme':'midnight','readingScale':1,'focus':'courage'})]:
  data={**base,**change,'onboardingVersion':version}
  req('PATCH',{'fields':{k:field(v) for k,v in data.items()}})
  checks.append({'schema':version,'accepted':True})
  print(f'PASS: production accepts version {version} onboarding')
 req('PATCH',{'fields':{k:field(v) for k,v in {**base,'onboardingVersion':99}.items()}},expected=403)
 checks.append({'unknownSchemaRejected':True})
finally:
 if original is not None:
  req('PATCH',{'fields':original})
  assert req('GET')['fields']==original
 else:
  import subprocess
  admin=subprocess.run(['gcloud','auth','print-access-token','--account=iamirrf1@gmail.com','--verbosity=error'],capture_output=True,text=True,check=True).stdout.strip()
  http('DELETE',url,token=admin)
  req('GET',expected=404)
(ROOT/'store/walk-onboarding-live.json').write_text(json.dumps({'verifiedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'project':PROJECT,'checks':checks,'qaDraftRestored':True,'customerAccountsModified':False},indent=2)+'\n')
print('PASS: QA draft restored exactly')
