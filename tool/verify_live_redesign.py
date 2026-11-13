"""Verify deployed rules/functions using only a new disposable QA account.

Creates no real-user content. Credentials remain in memory. The account and its
photos are removed through the deployed account-deletion function in finally.
"""
from __future__ import annotations
import datetime as dt
import json
import plistlib
import secrets
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from zoneinfo import ZoneInfo
ROOT=Path(__file__).resolve().parents[1]
PROJECT='holyhim-app-production'
BUCKET=PROJECT+'.firebasestorage.app'
BASE=f'https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents'
AUTH='https://identitytoolkit.googleapis.com/v1'
CALL=f'https://us-central1-{PROJECT}.cloudfunctions.net/'
class CheckError(Exception):pass

def field(v):
 if v is None:return {'nullValue':None}
 if isinstance(v,bool):return {'booleanValue':v}
 if isinstance(v,int):return {'integerValue':str(v)}
 if isinstance(v,float):return {'doubleValue':v}
 if isinstance(v,dt.datetime):return {'timestampValue':v.isoformat().replace('+00:00','Z')}
 if isinstance(v,dict):return {'mapValue':{'fields':{k:field(x) for k,x in v.items()}}}
 if isinstance(v,list):return {'arrayValue':{'values':[field(x) for x in v]}}
 return {'stringValue':v}

class LiveCheck:
 def __init__(self):
  self.key=plistlib.load((ROOT/'ios/Runner/GoogleService-Info.plist').open('rb'))['API_KEY']
  self.token=None;self.uid=None;self.checks=[]
  self.report={'date':dt.datetime.now(dt.timezone.utc).isoformat(),'project':PROJECT,'temporaryAccount':True,'checks':self.checks,'accountDeleted':False}
 def request(self,url,*,method='GET',data=None,body=None,headers=None,authenticated=True,expected=(200,)):
  h={'Content-Type':'application/json',**(headers or {})}
  if authenticated and self.token:h['Authorization']='Bearer '+self.token
  if data is not None:body=json.dumps(data).encode()
  request=urllib.request.Request(url,method=method,data=body,headers=h)
  try:
   with urllib.request.urlopen(request,timeout=40) as r:
    status=r.status;raw=r.read()
  except urllib.error.HTTPError as e:status=e.code;raw=e.read()
  if status not in expected:
   try:
    error=json.loads(raw).get('error',{});message=str(error.get('message',''))
    if self.token:message=message.replace(self.token,'[redacted]')
    self.report['lastHttpError']={'host':urllib.parse.urlparse(url).hostname,'status':status,'message':message[:500]}
   except (ValueError,AttributeError):pass
   raise CheckError(f'{method} {urllib.parse.urlparse(url).hostname}: HTTP {status}')
  try:return status,json.loads(raw) if raw else {}
  except (ValueError,UnicodeDecodeError):return status,{}
 def record(self,name):
  self.checks.append({'name':name,'passed':True});print('PASS:',name,flush=True)
 def write(self,path,data,mask=()):
  query=urllib.parse.urlencode([('updateMask.fieldPaths',x) for x in mask])
  return self.request(BASE+'/'+path+('?' +query if query else ''),method='PATCH',data={'fields':{k:field(v) for k,v in data.items()}})[1]
 def call(self,name):return self.request(CALL+name,method='POST',data={'data':{}})[1].get('result',{})
 def avatar(self,number):
  path=f'users/{self.uid}/avatars/{time.time_ns()+number}.jpg';boundary='holyhim-redesign-qa'
  image=(ROOT/'ios/HolyHimWidget/Art/cross-hill-thumb.jpg').read_bytes()
  metadata={'name':path,'contentType':'image/jpeg'}
  body=(f'--{boundary}\r\nContent-Type: application/json\r\n\r\n'+json.dumps(metadata)+f'\r\n--{boundary}\r\nContent-Type: image/jpeg\r\n\r\n').encode()+image+f'\r\n--{boundary}--\r\n'.encode()
  url=f'https://firebasestorage.googleapis.com/v0/b/{BUCKET}/o?uploadType=multipart&name='+urllib.parse.quote(path,safe='')
  _,uploaded=self.request(url,method='POST',body=body,headers={'Content-Type':f'multipart/related; boundary={boundary}','X-Goog-Upload-Protocol':'multipart'})
  resource=f'https://firebasestorage.googleapis.com/v0/b/{BUCKET}/o/'+urllib.parse.quote(path,safe='')
  token=uploaded.get('downloadTokens','').split(',')[0]
  if not token:token=self.request(resource)[1].get('downloadTokens','').split(',')[0]
  if not token:raise CheckError('The uploaded photo has no server download token')
  return resource,resource+'?alt=media&token='+token
 def wait_deleted(self,resource):
  deadline=time.monotonic()+75
  while time.monotonic()<deadline:
   status,_=self.request(resource,expected=(200,404))
   if status==404:return
   time.sleep(2)
  raise CheckError('Replaced avatar cleanup did not arrive within 75 seconds')
 def run(self):
  email='holyhim-redesign-qa-'+secrets.token_hex(8)+'@example.invalid'
  _,auth=self.request(AUTH+'/accounts:signUp?key='+self.key,method='POST',data={'email':email,'password':secrets.token_urlsafe(28),'returnSecureToken':True},authenticated=False)
  self.token=auth['idToken'];self.uid=auth['localId'];self.record('temporary authenticated account')
  stamp=dt.datetime.now(dt.timezone.utc);path='users/'+self.uid
  profile={'schema':6,'name':'Redesign QA','username':'QA','birthday':'1998-05-16','avatarUrl':None,'onboardingDraft':{'step':4,'source':'The App Store','familiarity':'Some passages are familiar','needs':'Finding peace'},'hearts':['Peace'],'reminder':{'enabled':False,'minutes':420},'theme':'sage','readingScale':1,'haptics':False,'sounds':False,'promise':{'startedAt':None},'timeZone':'America/New_York','onboardedAt':stamp,'createdAt':stamp,'updatedAt':stamp,'migratedAt':stamp}
  self.write(path,profile);self.record('schema 6 profile accepted by deployed rules')
  self.write(path,{'name':'QA renamed','updatedAt':stamp},['name','updatedAt'])
  stored=self.request(BASE+'/'+path)[1]['fields'];assert stored['name']['stringValue']=='QA renamed' and stored['onboardedAt']['timestampValue'];self.record('name edit preserves completed onboarding')
  self.write(path,{'onboardingDraft':{'step':4,'source':'A friend or family member'},'updatedAt':stamp},['onboardingDraft','updatedAt'])
  stored=self.request(BASE+'/'+path)[1]['fields'];assert 'needs' not in stored['onboardingDraft']['mapValue']['fields'];self.record('rewinding guide answer clears later answers')
  day=dt.datetime.now(ZoneInfo('America/New_York')).date().isoformat()
  self.write(path+'/walk/progress',{'completed':{'1':day}});self.record('lesson progress accepted')
  self.write(path+'/walk/saved',{'verses':{'1':stamp}});self.write(path+'/walk/saved',{'verses':{}},['verses.`1`']);self.record('saved add and remove accepted')
  self.request(BASE+'/'+path,authenticated=False,expected=(403,));self.record('unauthenticated profile read denied')
  access=self.call('getAccessStatus');assert access.get('eligible') is False and access.get('genuinePurchase') is False;self.record('new account receives no fabricated lifetime access')
  ownership=self.call('syncAccess');assert ownership.get('active') is False;self.record('server RevenueCat verification preserves non-ownership')
  self.request(CALL+'revenuecatWebhook',method='POST',data={'event':{}},authenticated=False,expected=(401,));self.record('unsigned webhook denied')
  first,url1=self.avatar(1);self.write(path,{'avatarUrl':url1,'updatedAt':stamp},['avatarUrl','updatedAt']);self.record('owner JPEG avatar upload and profile reference accepted')
  self.request(first,authenticated=False,expected=(403,));self.record('unauthenticated avatar metadata read denied')
  second,url2=self.avatar(2);self.write(path,{'avatarUrl':url2,'updatedAt':stamp},['avatarUrl','updatedAt']);self.wait_deleted(first);self.record('accepted photo replacement cleans old object')
  self.write(path,{'avatarUrl':'','updatedAt':stamp},['avatarUrl','updatedAt']);self.wait_deleted(second);self.record('photo removal cleans object and preserves explicit removal')
  leftover,_=self.avatar(3)
  result=self.call('deleteAccount');assert result.get('deleted') is True;self.report['accountDeleted']=True
  self.request(leftover,expected=(404,));self.request(BASE+'/'+path,expected=(404,));self.record('account deletion purges photos, profile and progress')
  self.report['passed']=True
 def close(self):
  if self.uid and not self.report['accountDeleted']:
   try:self.report['accountDeleted']=self.call('deleteAccount').get('deleted') is True
   except Exception as e:self.report['cleanupError']=type(e).__name__
  (ROOT/'store/redesign-v3/live-backend.json').write_text(json.dumps(self.report,indent=2)+'\n')
if __name__=='__main__':
 check=LiveCheck()
 try:check.run()
 except Exception as e:
  check.report['passed']=False;check.report['error']=str(e) if isinstance(e,CheckError) else type(e).__name__;print('Live verification stopped:',check.report['error'],flush=True)
 finally:check.close()
 if not check.report.get('passed'):raise SystemExit(1)
