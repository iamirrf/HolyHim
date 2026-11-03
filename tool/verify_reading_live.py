"""Exercise only the retained journey QA account against production reading APIs."""
import datetime,json,plistlib,urllib.error,urllib.request,uuid
from pathlib import Path
from prepare_review_accounts import read_secret,http,AUTH
ROOT=Path(__file__).resolve().parents[1];PROJECT='holyher-app-production';BASE=f'https://us-central1-{PROJECT}.cloudfunctions.net/'
_,credential=read_secret('journey');native=plistlib.loads((ROOT/'ios/Runner/GoogleService-Info.plist').read_bytes())
signed=http('POST',AUTH+'accounts:signInWithPassword?key='+native['API_KEY'],{'email':credential['email'],'password':credential['password'],'returnSecureToken':True});assert signed['localId']==credential['uid']
checks=[]
def checked(name,test):
 assert test,name;checks.append(name);print('PASS:',name,flush=True)
def request(method,url,body=None,expected=200,auth=True):
 req=urllib.request.Request(url,method=method,headers={'Content-Type':'application/json',**({'Authorization':'Bearer '+signed['idToken']} if auth else {})},data=None if body is None else json.dumps(body).encode())
 try:
  with urllib.request.urlopen(req,timeout=60) as r:status,raw=r.status,r.read()
 except urllib.error.HTTPError as e:status,raw=e.code,e.read()
 assert status==expected,f'HTTP {status}, expected {expected}'
 return json.loads(raw) if raw else {}
def call(name,data=None,**kwargs):return request('POST',BASE+name,{'data':data or {}},**kwargs).get('result',{})
journey=call('getJourney');checked('retained journey is acknowledged',journey['started'])
again=call('startJourney',{'timeZone':'UTC'});checked('journey creation remains idempotent',all(again[k]==journey[k] for k in ['revision','startDate','timeZone','completedDays']))
uid=credential['uid'];docs=f'https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents/users/{uid}'
resume_url=docs+'/readingResumes/day-1'
try:prior=request('GET',resume_url)
except AssertionError as error:
 if 'HTTP 404' not in str(error):raise
 prior={}
revision=int(prior.get('fields',{}).get('checkpointRevision',{}).get('integerValue',0))
session=str(uuid.uuid4());checkpoint={'version':'walk-v1','day':1,'journeyRevision':journey['revision'],'sessionId':session,'checkpointId':str(uuid.uuid4()),'cardIndex':4,'visited':[0,1,2,3,4]}
saved=call('saveReadingCheckpoint',{'expectedRevision':revision,'checkpoint':checkpoint});checked('new reading checkpoint is accepted',saved['accepted'])
body={'operationId':str(uuid.uuid4()),'sessionId':session,'day':1,'contentVersion':'walk-v1','journeyRevision':journey['revision'],'visited':[0,1,2,3,4],'readDate':journey['serverDate']}
call('completeReading',{**body,'visited':[0,1,2,3]},expected=400);checked('four-card completion is rejected',True)
result=call('completeReading',body);checked('five-card completion is accepted without quiz answers',1 in result['completedDays'])
retry=call('completeReading',body);checked('exact duplicate retry returns the same receipt',retry==result)
checked('distinct progress cannot inflate on reread',set(result['completedDays'])==set(journey['completedDays'])|{1})
checked('reread records a reading day',journey['serverDate'] in result['readingDates'])
checked('first-reading badge is permanent',1 in result['earnedBadges'])
late=call('saveReadingCheckpoint',{'expectedRevision':saved['checkpointRevision'],'checkpoint':{**checkpoint,'checkpointId':str(uuid.uuid4())}});checked('delayed checkpoint cannot undo completion',not late['accepted'])
call('completeReading',body,expected=401,auth=False);checked('unauthenticated completion is denied',True)
request('GET',docs.replace(uid,'not-the-qa-owner')+'/readingResumes/day-1',expected=403);checked('reading checkpoints are account isolated',True)
export=call('exportAccountData');checked('export includes new and legacy account records',all(k in export for k in ['attempts','resumes','readingOperations','readingResumes','journey']))
report={'verifiedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'project':PROJECT,'passed':True,'checks':checks,'customerAccountsModified':False,'qaOnly':True,'credentialsLogged':False}
(ROOT/'store/walk-reading-live.json').write_text(json.dumps(report,indent=2)+'\n')
