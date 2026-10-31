const test=require('node:test'),assert=require('node:assert/strict');
const {dateKey,unlockedThrough,mergeCompletion,mergeActivityDays,lifetimeAccess,validTimeZone,webhookCustomerIds,LIFETIME_ENTITLEMENT_ID}=require('../domain');
test('calendar unlocking accumulates missed dates and caps at 365',()=>{
 assert.equal(unlockedThrough('2026-10-29','2026-10-29'),1);
 assert.equal(unlockedThrough('2026-10-29','2026-11-05'),8);
 assert.equal(unlockedThrough('2026-10-29','2028-01-01'),365);
 assert.equal(unlockedThrough('2026-10-29','2026-10-28'),1);
});
test('DST and leap days use calendar dates rather than elapsed hours',()=>{
 assert.equal(dateKey(new Date('2026-11-01T04:30:00Z'),'America/New_York'),'2026-11-01');
 assert.equal(dateKey(new Date('2026-11-02T04:30:00Z'),'America/New_York'),'2026-11-01');
 assert.equal(unlockedThrough('2028-02-28','2028-03-01'),3);
 assert.equal(validTimeZone('Invalid/Zone'),false);
});
test('completion is idempotent and future days are rejected',()=>{
 const journey={startDate:'2026-10-29',completedDays:[1,2]};
 assert.deepEqual(mergeCompletion(journey,2,'2026-10-31'),[1,2]);
 assert.deepEqual(mergeCompletion(journey,3,'2026-10-31'),[1,2,3]);
 for(const day of [0,-1,4,1.5,'3',366])assert.throws(()=>mergeCompletion(journey,day,'2026-10-31'));
});
test('V2 lifetime entitlement uses the internal ID and a null expiry',()=>{
 const page={object:'list',items:[{entitlement_id:LIFETIME_ENTITLEMENT_ID,expires_at:null}]};
 assert.equal(lifetimeAccess(page),true);
 assert.equal(lifetimeAccess({object:'list',items:[]}),false);
 assert.equal(lifetimeAccess({object:'list',items:[{entitlement_id:'lifetime',expires_at:null}]}),false);
 assert.equal(lifetimeAccess({object:'list',items:[{entitlement_id:'another',expires_at:null}]}),false);
});
test('V2 refunds and revocations remove active access; repurchase restores it',()=>{
 const purchased={object:'list',items:[{entitlement_id:LIFETIME_ENTITLEMENT_ID,expires_at:null}]};
 const revoked={object:'list',items:[]};
 assert.equal(lifetimeAccess(purchased),true);
 assert.equal(lifetimeAccess(revoked),false);
 assert.equal(lifetimeAccess(purchased),true);
});
test('finite V2 entitlements use millisecond expiry and reject malformed responses',()=>{
 const now=Date.parse('2026-11-15T11:00:00Z');
 const page=expires_at=>({object:'list',items:[{entitlement_id:LIFETIME_ENTITLEMENT_ID,expires_at}]});
 assert.equal(lifetimeAccess(page(now+1000),now),true);
 assert.equal(lifetimeAccess(page(now),now),false);
 assert.equal(lifetimeAccess(page(now-1000),new Date(now)),false);
 for(const invalid of [undefined,'2027-01-01',NaN,Infinity])assert.throws(()=>lifetimeAccess(page(invalid),now));
 for(const invalid of [null,{},[],{items:[]},{object:'list',items:{}}])assert.throws(()=>lifetimeAccess(invalid,now));
});
test('webhooks reconcile custom aliases and both sides of transfers',()=>{
 const ids=webhookCustomerIds({app_user_id:'alice',original_app_user_id:'alice-old',aliases:['alice','beth','$RCAnonymousID:123'],transferred_from:['previous'],transferred_to:['beth','current']});
 assert.deepEqual(ids,['alice','alice-old','beth','previous','current']);
 assert.deepEqual(webhookCustomerIds({transferred_from:['from'],transferred_to:['to']}),['from','to']);
});
test('invalid webhook identity types cannot inject document paths',()=>{
 assert.deepEqual(webhookCustomerIds({app_user_id:'',aliases:['../../users/other',null,7,'a'.repeat(129),'valid']}),['valid']);
 assert.throws(()=>webhookCustomerIds({aliases:'not-an-array'}));
 assert.throws(()=>webhookCustomerIds({transferred_from:{}}));
});

// Exercise the real callable handlers without network or Firebase credentials.
// Transactions serialize in memory, while RevenueCat responses can be delayed
// independently to reproduce the production races at the HTTP boundary.
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
function backendHarness({baseOnly=false}={}) {
 const documents=new Map(),users=new Set(['alice']),requests=[],secretNames=[];
 let transactionTail=Promise.resolve();
 const harness={documents,users,requests,secretNames,beforeTransaction:null,onFetch:async()=>({status:200,body:{object:'list',items:[]}})};
 const snapshot=ref=>({exists:documents.has(ref.path),data:()=>documents.get(ref.path)});
 const write=(ref,data,options)=>documents.set(ref.path,options?.merge?{...documents.get(ref.path),...data}:data);
 const doc=docPath=>({path:docPath,get:async()=>snapshot({path:docPath}),set:async(data,options)=>write({path:docPath},data,options)});
 const database={
  doc,
  collection:name=>({doc:id=>doc(`${name}/${id||'generated'}`)}),
  recursiveDelete:async ref=>{for(const key of documents.keys())if(key===ref.path||key.startsWith(`${ref.path}/`))documents.delete(key);},
  runTransaction:action=>{
   const result=transactionTail.then(async()=>{
    if(harness.beforeTransaction){const hook=harness.beforeTransaction;harness.beforeTransaction=null;hook();}
    const pending=[];
    const tx={get:async ref=>snapshot(ref),set:(ref,data,options)=>pending.push(()=>write(ref,data,options)),create:(ref,data)=>pending.push(()=>{assert.equal(documents.has(ref.path),false);write(ref,data);}),update:(ref,data)=>pending.push(()=>write(ref,data,{merge:true}))};
    const value=await action(tx);for(const commit of pending)commit();return value;
   });
   transactionTail=result.catch(()=>{});return result;
  },
 };
 class CallableError extends Error {constructor(code,message){super(message);this.code=code;}}
 const auth={getUser:async uid=>{if(!users.has(uid))throw Object.assign(new Error('Missing user'),{code:'auth/user-not-found'});return {uid};},deleteUser:async uid=>{users.delete(uid);}};
 const exports={};
 const context={exports,Buffer,URL,Date,AbortSignal,process:{env:baseOnly?{HOLYHER_BASE_ONLY:'1'}:{}},require:name=>{
  if(name==='firebase-functions/v2/https')return {onCall:(_,handler)=>handler,onRequest:(_,handler)=>handler,HttpsError:CallableError};
  if(name==='firebase-functions/params')return {defineSecret:name=>{secretNames.push(name);return {value:()=> 'test-secret'};}};
  if(name==='firebase-admin/app')return {initializeApp:()=>{}};
  if(name==='firebase-admin/firestore')return {getFirestore:()=>database,FieldValue:{serverTimestamp:()=>Date.now()},Timestamp:{fromMillis:value=>value}};
  if(name==='firebase-admin/auth')return {getAuth:()=>auth};
  if(name==='./domain')return require('../domain');
  if(name==='node:crypto')return require('node:crypto');
  throw new Error(`Unexpected dependency: ${name}`);
 },fetch:async(url,options)=>{
  requests.push({url,method:options?.method||'GET'});
  const response=await harness.onFetch(url,options);
  return {status:response.status,ok:response.status>=200&&response.status<300,json:async()=>response.body};
 }};
 vm.runInNewContext(fs.readFileSync(path.join(__dirname,'../index.js'),'utf8'),context);
 harness.api=exports;
 return harness;
}
const nextTurn=()=>new Promise(resolve=>setImmediate(resolve));
const purchasedPage=()=>({object:'list',items:[{entitlement_id:LIFETIME_ENTITLEMENT_ID,expires_at:null}]});

test('a slow pre-refund reconciliation cannot overwrite or return stale active access',async()=>{
 const h=backendHarness();let finishFirst;
 const firstResponse=new Promise(resolve=>{finishFirst=resolve;});let calls=0;
 h.onFetch=async()=>++calls===1?firstResponse:{status:200,body:{object:'list',items:[]}};
 const old=h.api.syncAccess({auth:{uid:'alice'}});
 await nextTurn();assert.equal(calls,1);
 const revoked=await h.api.syncAccess({auth:{uid:'alice'}});
 assert.equal(revoked.active,false);
 finishFirst({status:200,body:purchasedPage()});
 assert.equal((await old).active,false);
 assert.equal(h.documents.get('users/alice/private/entitlement').active,false);
});

test('deletion blocks in-flight and delayed webhook writes from recreating user data',async()=>{
 const h=backendHarness();let finishRead;
 const response=new Promise(resolve=>{finishRead=resolve;});
 h.onFetch=async(_,options)=>options?.method==='DELETE'?{status:200}:response;
 const old=h.api.syncAccess({auth:{uid:'alice'}});
 await nextTurn();
 await h.api.deleteAccount({auth:{uid:'alice',token:{auth_time:Date.now()/1000}}});
 assert.equal(h.users.has('alice'),false);
 finishRead({status:200,body:purchasedPage()});
 assert.equal((await old).active,false);
 assert.equal([...h.documents.keys()].some(key=>key.startsWith('users/alice')),false);
 assert.equal([...h.documents.entries()].some(([key,value])=>key.startsWith('accountStates/')&&value.deleting),true);
 const before=h.requests.length;let status;
 const reply={status:code=>{status=code;return reply;},send:()=>{}};
 await h.api.revenuecatWebhook({method:'POST',get:()=> 'Bearer test-secret',body:{event:{id:'late-refund',app_user_id:'alice'}}},reply);
 assert.equal(status,200);assert.equal(h.requests.length,before);
 assert.equal([...h.documents.keys()].some(key=>key.startsWith('users/alice')),false);
 assert.equal(h.requests.find(request=>request.method==='DELETE').url.includes('/v2/projects/proj802af471/customers/alice'),true);
});

test('journey creation rechecks entitlement inside its transaction',async()=>{
 const h=backendHarness(),key='users/alice/private/entitlement';
 h.documents.set(key,{active:true});
 h.beforeTransaction=()=>h.documents.set(key,{active:false});
 await assert.rejects(h.api.startJourney({auth:{uid:'alice'},data:{timeZone:'UTC'}}),error=>error.code==='permission-denied');
 assert.equal(h.documents.has('users/alice/private/journey'),false);
});

test('V2 pagination reaches the target entitlement without leaking authorization',async()=>{
 const h=backendHarness();
 h.onFetch=async url=>url.includes('starting_after')?{status:200,body:purchasedPage()}:{status:200,body:{object:'list',items:[],next_page:'/v2/projects/proj802af471/customers/alice/active_entitlements?starting_after=other'}};
 assert.equal((await h.api.syncAccess({auth:{uid:'alice'}})).active,true);
 assert.equal(h.requests.length,2);
 const hostile=backendHarness();
 hostile.onFetch=async()=>({status:200,body:{object:'list',items:[],next_page:'https://attacker.invalid/collect'}});
 await assert.rejects(hostile.api.syncAccess({auth:{uid:'alice'}}),error=>error.code==='unavailable');
 assert.equal(hostile.requests.length,1);
});

test('an unknown V2 customer is an explicit inactive result, not a new customer',async()=>{
 const h=backendHarness();h.onFetch=async()=>({status:404});
 h.documents.set('users/alice/private/entitlement',{active:true});
 assert.equal((await h.api.syncAccess({auth:{uid:'alice'}})).active,false);
 assert.equal(h.requests.length,1);
 assert.equal(h.requests[0].method,'GET');
 assert.equal(h.requests[0].url.endsWith('/active_entitlements?limit=100'),true);
});


test('base-only analysis exports all five independent endpoints without secret params',async()=>{
 const h=backendHarness({baseOnly:true});
 assert.deepEqual(Object.keys(h.api).sort(),['completeLesson','getJourney','markActive','startJourney','supportRequest']);
 assert.deepEqual(h.secretNames,[]);
 assert.equal((await h.api.getJourney({auth:{uid:'alice'}})).started,false);
 let status,body;
 const reply={status:code=>{status=code;return reply;},json:value=>{body=value;}};
 await h.api.supportRequest({method:'POST',ip:'127.0.0.1',body:{email:'qa@example.invalid',message:'An isolated automated support-form test.'}},reply);
 assert.equal(status,200);assert.equal(body.received,true);
 assert.equal(h.documents.get('supportRequests/generated').message,'An isolated automated support-form test.');
 assert.equal(h.requests.length,0);
});
test('default deployment analysis retains billing exports and secret requirements',()=>{
 const h=backendHarness();
 assert.equal(Object.keys(h.api).length,8);
 assert.equal(typeof h.api.syncAccess,'function');
 assert.equal(typeof h.api.revenuecatWebhook,'function');
 assert.equal(typeof h.api.deleteAccount,'function');
 assert.deepEqual(h.secretNames,['REVENUECAT_SECRET_API_KEY','REVENUECAT_WEBHOOK_SECRET']);
});


test('activity merging retains offline dates only within the journey calendar',()=>{
 const journey={startDate:'2026-10-29'};
 const merged=mergeActivityDays(journey,['2026-10-28','2026-10-29'],['2026-10-29','2026-10-30','2026-11-02'],'2026-10-31');
 assert.deepEqual(merged,['2026-10-29','2026-10-30','2026-10-31']);
 assert.deepEqual(mergeActivityDays(journey,merged,['2026-10-30'],'2026-10-31'),merged);
 for(const invalid of ['not-an-array',Array(367).fill('2026-10-29'),['2026-02-30'],[9]])assert.throws(()=>mergeActivityDays(journey,[],invalid,'2026-10-31'));
});
test('concurrent activity uploads merge both devices idempotently',async()=>{
 const h=backendHarness(),zone='America/New_York',today=dateKey(new Date(),zone);
 const offset=days=>new Date(Date.parse(`${today}T00:00:00Z`)+days*86400000).toISOString().slice(0,10);
 h.documents.set('users/alice/private/journey',{startDate:offset(-3),timeZone:zone,completedDays:[]});
 await Promise.all([
  h.api.markActive({auth:{uid:'alice'},data:{days:[offset(-1)]}}),
  h.api.markActive({auth:{uid:'alice'},data:{days:[offset(-2)]}}),
 ]);
 const expected=[offset(-2),offset(-1),today];
 assert.deepEqual(Array.from(h.documents.get('users/alice/private/activity').activeDays),expected);
 const result=await h.api.markActive({auth:{uid:'alice'},data:{days:[offset(-2),offset(1),offset(-5)]}});
 assert.deepEqual(Array.from(result.activeDays),expected);
});
