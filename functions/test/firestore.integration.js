// Runs only against a local emulator and a demo project. No production credentials.
const {test} = require('node:test');
const assert = require('node:assert/strict');
const project = 'demo-holyher';
const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host || !/^127\.0\.0\.1:\d+$/.test(host) || process.env.GCLOUD_PROJECT !== project) {
  throw new Error('Use the documented local demo-holyher emulator command.');
}
const base = `http://${host}/v1/projects/${project}/databases/(default)/documents`;
function token(uid) {
  const now = Math.floor(Date.now() / 1000);
  const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  return `${encode({alg:'none',typ:'JWT'})}.${encode({iss:`https://securetoken.google.com/${project}`,aud:project,sub:uid,user_id:uid,iat:now,exp:now+3600,auth_time:now,firebase:{sign_in_provider:'custom'}})}.`;
}
function field(value) {
  if (Array.isArray(value)) return {arrayValue:{values:value.map(field)}};
  return value === null ? {nullValue:null} : typeof value === 'boolean' ? {booleanValue:value} : typeof value === 'number' ? Number.isInteger(value) ? {integerValue:String(value)} : {doubleValue:value} : {stringValue:value};
}
function fields(data) {
  return Object.fromEntries(Object.entries(data).map(([key,value]) => [key, field(value)]));
}
async function request(path, {uid, admin=false, data, method=data?'PATCH':'GET'}={}) {
  const response = await fetch(`${base}/${path}`, {
    method, headers: {'Content-Type':'application/json', ...(admin || uid ? {Authorization:`Bearer ${admin?'owner':token(uid)}`} : {})},
    ...(data ? {body:JSON.stringify({fields:fields(data)})} : {})
  });
  return {status:response.status, body:await response.json()};
}
const profile = {name:'Alice',familiarity:'new',focus:'peace',obstacle:'busy',reminderMinutes:null,onboardingComplete:false,haptics:true,onboardingStep:0};

test('profile rules preserve legacy compatibility and enforce owner, field and value checks',async()=>{
  assert.equal((await request('users/alice',{uid:'alice',data:profile})).status,200);
  assert.equal((await request('users/alice',{uid:'alice'})).status,200);
  assert.equal((await request('users/alice',{uid:'bob'})).status,403);
  assert.equal((await request('users/alice')).status,403);
  assert.equal((await request('users/alice',{uid:'bob',data:profile})).status,403);
  for (const change of [{admin:true},{name:'x'.repeat(81)},{focus:'invalid'},{reminderMinutes:1440},{haptics:'yes'},{onboardingStep:10},{onboardingStepId:'invalid'},{onboardingVersion:99}]) {
    assert.equal((await request('users/alice',{uid:'alice',data:{...profile,...change}})).status,403,JSON.stringify(change));
  }
  assert.equal((await request('users/alice',{uid:'alice',data:{...profile,sounds:true,tips:true,largerText:false,onboardingVersion:2,onboardingStepId:'summary'}})).status,200);
});

test('version 3 checkpoints retain semantic stages and keep suggestions separate from enabled reminders',async()=>{
  const draft={...profile,onboardingVersion:3,onboardingStep:11,onboardingStepId:'arrival',onboardingAnswered:['name','moment','starting-point','guided-example'],suggestedReminderMinutes:480,reminderDecision:'denied',guidedExampleAnswer:'day-001-q1-b',guidedExampleRevealed:true};
  assert.equal((await request('users/v3-reader',{uid:'v3-reader',data:draft})).status,200);
  const restored=await request('users/v3-reader',{uid:'v3-reader'});
  assert.equal(restored.body.fields.reminderMinutes.nullValue,null);
  assert.equal(restored.body.fields.suggestedReminderMinutes.integerValue,'480');
  for(const change of [{onboardingStep:12},{onboardingAnswered:['unrelated']},{suggestedReminderMinutes:1440},{reminderDecision:'pretend'},{guidedExampleAnswer:'invented'}]){
    assert.equal((await request('users/v3-reader',{uid:'v3-reader',data:{...draft,...change}})).status,403,JSON.stringify(change));
  }
});

test('server-owned data is readable only by its owner and never client writable',async()=>{
  for (const path of ['private/journey','private/editionAccess','private/savedCatalog','attempts/attempt-1','resumes/day-1','saved/day-1']) {
    const document = `users/alice/${path}`;
    assert.equal((await request(document,{admin:true,data:{value:'server'}})).status,200);
    assert.equal((await request(document,{uid:'alice'})).status,200);
    assert.equal((await request(document,{uid:'bob'})).status,403);
    assert.equal((await request(document)).status,403);
    assert.equal((await request(document,{uid:'alice',data:{value:'client'}})).status,403);
  }
});

test('deletion guard rejects a delayed profile write and cannot be changed by clients',async()=>{
  const guarded = 'users/deleting';
  assert.equal((await request(guarded,{uid:'deleting',data:profile})).status,200);
  assert.equal((await request('deletionGuards/deleting',{admin:true,data:{deleting:true}})).status,200);
  assert.equal((await request(guarded,{admin:true,method:'DELETE'})).status,200);
  assert.equal((await request(guarded,{uid:'deleting',data:profile})).status,403);
  for (const path of ['deletionGuards/deleting','accountStates/hashed-uid','legacyBillingCleanup/hashed-uid','users/alice/resetOperations/operation-1','users/alice/savedOperations/operation-1']) {
    assert.equal((await request(path,{uid:'deleting'})).status,403);
    assert.equal((await request(path,{uid:'deleting',data:{deleting:false}})).status,403);
  }
});

// These call the exported handler with an authenticated request and use actual
// Admin SDK / Firestore emulator transactions. Callable HTTP transport and
// provider authentication remain separate native/integration gates.
test('real Firestore transactions retain free access and make reset and bookmark retries idempotent',async()=>{
  process.env.HOLYHER_BASE_ONLY = '1';
  const api = require('../index');
  const catalog = require('../teaching.json');
  const uid = 'transaction-account';
  const auth = data => ({auth:{uid,token:{auth_time:Date.now()/1000}},data});
  const starts = await Promise.all([
    api.startJourney.run(auth({timeZone:'UTC'})),
    api.startJourney.run(auth({timeZone:'America/New_York'}))
  ]);
  assert.equal(starts[0].startDate,starts[1].startDate);
  assert.equal(starts[0].timeZone,starts[1].timeZone);
  const access = await api.getAccessStatus.run(auth({}));
  assert.equal(access.retainedGrant,true);
  assert.equal(access.genuinePurchase,false);
  const request = {attemptId:'emulator-attempt-000001',day:1,contentVersion:catalog.version,journeyRevision:1,
    selectedOptionIds:Object.fromEntries(catalog.lessons[0].questions.map(q=>[q.id,q.correctOptionId]))};
  await api.completeLessonAttempt.run(auth(request));
  const reset = await api.resetLearningProgress.run(auth({operationId:'emulator-reset-000001'}));
  assert.equal(reset.revision,2);
  await api.completeLessonAttempt.run(auth({...request,attemptId:'emulator-attempt-000002',journeyRevision:2}));
  const retried = await api.resetLearningProgress.run(auth({operationId:'emulator-reset-000001'}));
  assert.equal(retried.revision,2);
  const current = await api.getJourney.run(auth({}));
  assert.equal(current.completedDays.includes(1),true);
  assert.equal(current.startDate,starts[0].startDate);
  await assert.rejects(api.completeLessonAttempt.run(auth(request)),e=>e.code==='failed-precondition');
  const resume = {stepId:'question-1',renderedPart:0,checkpointId:'emulator-checkpoint-000001',attempt:{...request,attemptId:'emulator-practice-000003',journeyRevision:2,
    optionOrder:Object.fromEntries(catalog.lessons[0].questions.map(q=>[q.id,q.options.map(o=>o.id)]))}};
  const checkpoints = await Promise.all([
    api.saveLessonResume.run(auth({expectedRevision:1,resume})),
    api.saveLessonResume.run(auth({expectedRevision:1,resume:{...resume,checkpointId:'emulator-checkpoint-000002',stepId:'hope'}}))
  ]);
  assert.equal(checkpoints.filter(result=>result.accepted).length,1);
  assert.equal(checkpoints.filter(result=>result.reason==='conflict').length,1);
  const save = {day:1,saved:true,operationId:'emulator-save-000001'};
  const receipt = await api.setSavedLesson.run(auth(save));
  await api.setSavedLesson.run(auth({day:1,saved:false,operationId:'emulator-save-000002'}));
  assert.equal((await api.setSavedLesson.run(auth(save))).savedAt,receipt.savedAt);
  const saved = await requestDocument(`users/${uid}/private/savedCatalog`);
  assert.equal(saved.fields.days.mapValue.fields['1'].nullValue,null);
});

async function requestDocument(path) {
  return (await request(path,{admin:true})).body;
}

test('five-card reading transactions support offline dates, rereads, retries, conflicts and permanent awards',async()=>{
  process.env.HOLYHER_BASE_ONLY='1';
  const api=require('../index');
  const {getFirestore}=require('firebase-admin/firestore');
  const db=getFirestore(),uid='reading-account';
  const auth=data=>({auth:{uid,token:{auth_time:Date.now()/1000}},data});
  const started=await api.startJourney.run(auth({timeZone:'UTC'}));
  const today=new Date().toISOString().slice(0,10),yesterday=new Date(Date.now()-86400000).toISOString().slice(0,10);
  await db.doc(`users/${uid}/private/journey`).update({startDate:yesterday,completedDays:[1],completionDates:{1:yesterday},earnedBadges:[1],readingDates:[yesterday]});
  const body={operationId:'reading-operation-000001',sessionId:'reading-session-0000001',day:1,contentVersion:'walk-v1',journeyRevision:1,visited:[0,1,2,3,4],readDate:today};
  await assert.rejects(api.completeReading.run(auth({...body,visited:[0,1,2,3]})),e=>e.code==='invalid-argument');
  await assert.rejects(api.completeReading.run({data:body}),e=>e.code==='unauthenticated');
  await assert.rejects(api.completeReading.run(auth({...body,day:3})),e=>e.code==='invalid-argument');
  const [first,retry]=await Promise.all([api.completeReading.run(auth(body)),api.completeReading.run(auth(body))]);
  assert.deepEqual(first,retry);
  assert.deepEqual(first.completedDays,[1]);
  assert.deepEqual(first.readingDates,[yesterday,today]);
  assert.equal(first.completionDates['1'],yesterday);
  assert.deepEqual(first.earnedBadges,[1]);
  await assert.rejects(api.completeReading.run(auth({...body,day:2})),e=>e.code==='already-exists');
  const checkpoint={version:'walk-v1',day:2,journeyRevision:1,sessionId:'reading-session-0000002',checkpointId:'reading-checkpoint-000001',cardIndex:2,visited:[0,1,2]};
  const results=await Promise.all([api.saveReadingCheckpoint.run(auth({expectedRevision:0,checkpoint})),api.saveReadingCheckpoint.run(auth({expectedRevision:0,checkpoint:{...checkpoint,checkpointId:'reading-checkpoint-000002'}}))]);
  assert.equal(results.filter(r=>r.accepted).length,1);
  assert.equal(results.filter(r=>r.reason==='conflict').length,1);
  await api.resetLearningProgress.run(auth({operationId:'reading-reset-operation-001'}));
  await assert.rejects(api.completeReading.run(auth(body)),e=>e.code==='failed-precondition');
  const reset=await api.getJourney.run(auth({}));
  assert.deepEqual(reset.completedDays,[]);
  assert.deepEqual(reset.earnedBadges,[1]);
  await request('deletionGuards/reading-account',{admin:true,data:{deleting:true}});
  // The hashed account guard used by functions is independently exercised.
  const crypto=require('node:crypto');
  await db.doc('accountStates/'+crypto.createHash('sha256').update(uid).digest('hex')).set({deleting:true});
  await assert.rejects(api.completeReading.run(auth({...body,journeyRevision:2,operationId:'reading-operation-000003'})),e=>e.code==='permission-denied');
});

test('v4 profiles add theme and reading size while v2 and v3 remain accepted',async()=>{
  const draft={...profile,onboardingVersion:4,onboardingStep:3,onboardingStepId:'day-one',theme:'midnight',readingScale:2,focus:'courage'};
  assert.equal((await request('users/v4-reader',{uid:'v4-reader',data:draft})).status,200);
  for(const change of [{onboardingStep:4},{theme:'invalid'},{readingScale:2.1},{readingScale:0.8}])assert.equal((await request('users/v4-reader',{uid:'v4-reader',data:{...draft,...change}})).status,403);
});
