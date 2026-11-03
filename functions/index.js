'use strict';
const {onCall,onRequest,HttpsError}=require('firebase-functions/v2/https');
const {defineSecret}=require('firebase-functions/params');
const {initializeApp}=require('firebase-admin/app');
const {getFirestore,FieldValue,Timestamp}=require('firebase-admin/firestore');
const {getAuth}=require('firebase-admin/auth');
const crypto=require('node:crypto');
const {dateKey,validTimeZone,unlockedThrough,mergeCompletion,mergeActivityDays,lifetimeAccess,webhookCustomerIds,REVENUECAT_PROJECT_ID}=require('./domain');
initializeApp();
const db=getFirestore();
// Deployment analysis can publish independent Google-hosted endpoints before
// billing credentials exist. Production/default discovery always exports all.
const baseOnly=process.env.HOLYHER_BASE_ONLY==='1';
const rcKey=baseOnly?null:defineSecret('REVENUECAT_SECRET_API_KEY');
const webhookSecret=baseOnly?null:defineSecret('REVENUECAT_WEBHOOK_SECRET');
// Mobile clients reach the callable transport without Google Cloud IAM tokens.
// Each protected handler still verifies Firebase Auth or the webhook secret.
const options={region:'us-central1',invoker:'public',maxInstances:3,serviceAccount:'holyher-runtime@holyher-app-production.iam.gserviceaccount.com'};
function uidOf(request) { if(!request.auth) throw new HttpsError('unauthenticated','Please sign in.'); return request.auth.uid; }
const privateDoc=(uid,name)=>db.doc(`users/${uid}/private/${name}`);
const accountStateRef=uid=>db.doc(`accountStates/${crypto.createHash('sha256').update(uid).digest('hex')}`);
const rcCustomerUrl=uid=>`https://api.revenuecat.com/v2/projects/${REVENUECAT_PROJECT_ID}/customers/${encodeURIComponent(uid)}`;
async function rcActiveEntitlements(uid) {
  const endpoint=`${rcCustomerUrl(uid)}/active_entitlements`;
  let next=`${endpoint}?limit=100`;
  const items=[];
  try {
    for(let page=0;page<20;page++) {
      const response=await fetch(next,{headers:{Authorization:`Bearer ${rcKey.value()}`},signal:AbortSignal.timeout(12000)});
      if(response.status===404 && page===0)return {object:'list',items:[]};
      if(!response.ok)throw new Error('RevenueCat unavailable');
      const body=await response.json();
      if(body.object!=='list'||!Array.isArray(body.items))throw new Error('Invalid RevenueCat response');
      items.push(...body.items);
      if(body.next_page==null)return {object:'list',items};
      const url=new URL(body.next_page,'https://api.revenuecat.com');
      if(url.origin!=='https://api.revenuecat.com'||url.pathname!==new URL(endpoint).pathname)throw new Error('Invalid RevenueCat pagination');
      next=url.href;
    }
    throw new Error('RevenueCat pagination exceeded');
  }catch {
    throw new HttpsError('unavailable','We could not confirm your purchase. Please try Restore Purchases shortly.');
  }
}
async function reconcile(uid) {
  // Ignore deleted/unknown aliases; a delayed billing webhook must not recreate
  // customer records or personal Firestore documents after account deletion.
  try { await getAuth().getUser(uid); }
  catch(error) { if(error.code==='auth/user-not-found')return false; throw error; }
  const ref=privateDoc(uid,'entitlement'),guard=accountStateRef(uid),revision=crypto.randomUUID();
  const reserved=await db.runTransaction(async tx=>{
    if((await tx.get(guard)).data()?.deleting===true)return false;
    tx.set(ref,{reconciliation:revision},{merge:true});
    return true;
  });
  if(!reserved)return false;
  let active;
  try { active=lifetimeAccess(await rcActiveEntitlements(uid)); }
  catch(error) {
    const [account,current]=await Promise.all([guard.get(),ref.get()]);
    if(account.data()?.deleting===true)return false;
    if(current.data()?.reconciliation!==revision)return current.data()?.active===true;
    throw error;
  }
  return db.runTransaction(async tx=>{
    const account=await tx.get(guard),current=await tx.get(ref);
    if(account.data()?.deleting===true)return false;
    // A newer request wins. Return the persisted decision, never the old HTTP
    // result, when another reconciliation or refund superseded this request.
    if(current.data()?.reconciliation!==revision)return current.data()?.active===true;
    tx.set(ref,{active,type:'lifetime',updatedAt:FieldValue.serverTimestamp()},{merge:true});
    return active;
  });
}
if(!baseOnly)exports.syncAccess=onCall({...options,secrets:[rcKey]},async request=>({active:await reconcile(uidOf(request))}));
// Free enrollment is a server policy, separate from verified purchase ownership.
// Changing this policy later cannot invalidate an edition grant already earned.
const FREE_ENROLLMENT_OPEN = true;
const EDITION = 'holyher365';
async function editionAccess(tx, uid, {grant = false} = {}) {
  const ref = privateDoc(uid, 'editionAccess');
  const existing = (await tx.get(ref)).data();
  const purchase = (await tx.get(privateDoc(uid, 'entitlement'))).data();
  const retainedGrant = existing?.edition === EDITION && existing?.retained === true;
  return {ref, retainedGrant, genuinePurchase: purchase?.active === true,
    eligible: FREE_ENROLLMENT_OPEN || retainedGrant || purchase?.active === true,
    createGrant: grant && FREE_ENROLLMENT_OPEN && !retainedGrant};
}
function writeGrant(tx, access) {
  if (access.createGrant) tx.set(access.ref, {edition: EDITION, retained: true,
    source: 'free-enrollment', grantedAt: FieldValue.serverTimestamp()});
}
exports.getAccessStatus=onCall(options,async request=>{
  const uid=uidOf(request);
  return db.runTransaction(async tx=>{
    const account=await tx.get(accountStateRef(uid));
    const journey=await tx.get(privateDoc(uid,'journey'));
    const access=await editionAccess(tx,uid,{grant:journey.exists});
    if(account.data()?.deleting===true)throw new HttpsError('permission-denied','Account deletion is in progress.');
    writeGrant(tx,access);
    return {edition:EDITION,eligible:access.eligible,retainedGrant:access.retainedGrant||access.createGrant,genuinePurchase:access.genuinePurchase};
  });
});
exports.startJourney=onCall(options,async request=>{
  const uid=uidOf(request),zone=request.data?.timeZone;
  if(!validTimeZone(zone))throw new HttpsError('invalid-argument','Please choose a valid time zone.');
  const ref=privateDoc(uid,'journey');
  await db.runTransaction(async tx=>{
    const account=await tx.get(accountStateRef(uid));
    const journey=await tx.get(ref);
    const access=await editionAccess(tx,uid,{grant:true});
    if(account.data()?.deleting===true||!access.eligible)throw new HttpsError('permission-denied','This edition is not available for enrollment.');
    writeGrant(tx,access);
    if(!journey.exists)tx.create(ref,{revision:1,startedAt:FieldValue.serverTimestamp(),startDate:dateKey(new Date(),zone),timeZone:zone,completedDays:[],updatedAt:FieldValue.serverTimestamp()});
  });
  return journeyPayload((await ref.get()).data());
});
function journeyPayload(data) {
  if(!data)return {started:false};
  return {started:true,revision:data.revision||1,startDate:data.startDate,timeZone:data.timeZone,completedDays:data.completedDays||[],completionDates:data.completionDates||{},readingDates:data.readingDates||Object.values(data.completionDates||{}),earnedBadges:[...new Set([...(data.earnedBadges||[]),...[1,7,30,90,180,365].filter(n=>(data.completedDays||[]).length>=n)])].sort((a,b)=>a-b),unlockedThrough:unlockedThrough(data.startDate,dateKey(new Date(),data.timeZone)),serverDate:dateKey(new Date(),data.timeZone)};
}
exports.getJourney=onCall(options,async request=>{
  const uid=uidOf(request),ref=privateDoc(uid,'journey');
  return db.runTransaction(async tx=>{
    const account=await tx.get(accountStateRef(uid)),journey=await tx.get(ref);
    const access=await editionAccess(tx,uid,{grant:journey.exists});
    if(account.data()?.deleting===true)throw new HttpsError('permission-denied','Account deletion is in progress.');
    writeGrant(tx,access);
    const data=journey.data(),result=journeyPayload(data);
    if(data && (!Array.isArray(data.readingDates)||JSON.stringify(data.earnedBadges||[])!==JSON.stringify(result.earnedBadges)))
      tx.update(ref,{readingDates:result.readingDates,earnedBadges:result.earnedBadges});
    return result;
  });
});
// Compatibility endpoint for build 1 and its durable outbox. After a reset,
// revision-less writes are rejected so an old device cannot restore erased data.
exports.completeLesson=onCall(options,async request=>{
  const uid=uidOf(request),day=request.data?.day,ref=privateDoc(uid,'journey');
  return db.runTransaction(async tx=>{
    const account=await tx.get(accountStateRef(uid));
    const data=(await tx.get(ref)).data();
    const access=await editionAccess(tx,uid,{grant:!!data});
    if(account.data()?.deleting===true||!access.eligible)throw new HttpsError('permission-denied','This edition is unavailable.');
    if(!data)throw new HttpsError('failed-precondition','Your journey has not started yet.');
    if((request.data?.journeyRevision??1)!==(data.revision||1))throw new HttpsError('failed-precondition','Your learning progress was reset. Reopen this lesson.');
    let completedDays;
    try{completedDays=mergeCompletion(data,day,dateKey(new Date(),data.timeZone));}
    catch{throw new HttpsError('invalid-argument','This lesson is not available yet.');}
    writeGrant(tx,access);
    const completionDates={...(data.completionDates||{}),...(!(data.completedDays||[]).includes(day)?{[day]:dateKey(new Date(),data.timeZone)}:{})};
    const readingDates=[...new Set([...(data.readingDates||Object.values(data.completionDates||{})),dateKey(new Date(),data.timeZone)])].sort();
    const earnedBadges=journeyPayload({...data,completedDays}).earnedBadges;
    tx.update(ref,{completedDays,completionDates,readingDates,earnedBadges,updatedAt:FieldValue.serverTimestamp()});
    return {...journeyPayload(data),completedDays,completionDates,readingDates,earnedBadges};
  });
});

// Reading-only v1. Legacy quiz and completion callables remain deployable.
const READING_VERSION='walk-v1';
const BADGE_DAYS=[1,7,30,90,180,365];
function validateReading(body) {
  if(!Number.isInteger(body.day)||body.day<1||body.day>365||body.contentVersion!==READING_VERSION||!Number.isInteger(body.journeyRevision)
    ||typeof body.operationId!=='string'||!/^[a-zA-Z0-9-]{16,100}$/.test(body.operationId)
    ||!Array.isArray(body.visited)||body.visited.length!==5||![0,1,2,3,4].every(i=>body.visited.includes(i)))
    throw new HttpsError('invalid-argument','Visit all five reading cards before finishing.');
}
exports.completeReading=onCall(options,async request=>{
  const uid=uidOf(request),body=request.data||{};
  validateReading(body);
  const ref=privateDoc(uid,'journey'),operation=db.doc(`users/${uid}/readingOperations/${body.operationId}`);
  return db.runTransaction(async tx=>{
    const guard=await tx.get(accountStateRef(uid)),journey=(await tx.get(ref)).data();
    const previous=(await tx.get(operation)).data();
    const resumeRef=db.doc(`users/${uid}/readingResumes/day-${body.day}`),resume=(await tx.get(resumeRef)).data();
    const access=await editionAccess(tx,uid,{grant:!!journey});
    if(guard.data()?.deleting===true||!access.eligible)throw new HttpsError('permission-denied','This account is unavailable.');
    if(!journey||body.journeyRevision!==(journey.revision||1))throw new HttpsError('failed-precondition','Your journey changed. Reopen the reading.');
    if(previous){
      if(previous.day!==body.day||previous.readDate!==body.readDate||previous.contentVersion!==body.contentVersion)throw new HttpsError('already-exists','This reading identity has already been used.');
      return previous.result;
    }
    const today=dateKey(new Date(),journey.timeZone),readDate=body.readDate;
    let completedDays;
    try {
      if(typeof readDate!=='string'||readDate<journey.startDate||readDate>today)throw Error();
      // Validates both the date and eligibility on the actual offline reading day.
      completedDays=mergeCompletion(journey,body.day,readDate);
    }catch{throw new HttpsError('invalid-argument','This reading is not available on that date.');}
    const completionDates={...(journey.completionDates||{}),...(!(journey.completedDays||[]).includes(body.day)?{[body.day]:readDate}:{})};
    const readingDates=[...new Set([...(journey.readingDates||Object.values(journey.completionDates||{})),readDate])].sort();
    const earnedBadges=[...new Set([...(journey.earnedBadges||[]),...BADGE_DAYS.filter(n=>completedDays.length>=n)])].sort((a,b)=>a-b);
    const result={...journeyPayload(journey),completedDays,completionDates,readingDates,earnedBadges,operationId:body.operationId};
    writeGrant(tx,access);
    tx.update(ref,{completedDays,completionDates,readingDates,earnedBadges,updatedAt:FieldValue.serverTimestamp()});
    tx.create(operation,{day:body.day,contentVersion:body.contentVersion,readDate,journeyRevision:body.journeyRevision,result,createdAt:FieldValue.serverTimestamp()});
    // A delayed completion must not erase another reading session's checkpoint.
    if(resume?.checkpoint?.sessionId===body.sessionId)
      tx.set(resumeRef,{cleared:true,checkpointRevision:(resume.checkpointRevision||0)+1,journeyRevision:body.journeyRevision,updatedAt:FieldValue.serverTimestamp()});
    return result;
  });
});
exports.saveReadingCheckpoint=onCall(options,async request=>{
  const uid=uidOf(request),body=request.data||{},checkpoint=body.checkpoint;
  if(!checkpoint||checkpoint.version!==READING_VERSION||!Number.isInteger(checkpoint.day)||checkpoint.day<1||checkpoint.day>365
    ||!Number.isInteger(checkpoint.cardIndex)||checkpoint.cardIndex<0||checkpoint.cardIndex>4
    ||!Array.isArray(checkpoint.visited)||checkpoint.visited.length>5||checkpoint.visited.some(i=>!Number.isInteger(i)||i<0||i>4)
    ||!Number.isInteger(body.expectedRevision)||body.expectedRevision<0||typeof checkpoint.sessionId!=='string'||!/^[a-zA-Z0-9-]{16,100}$/.test(checkpoint.sessionId)
    ||typeof checkpoint.checkpointId!=='string'||!/^[a-zA-Z0-9-]{16,100}$/.test(checkpoint.checkpointId)||JSON.stringify(checkpoint).length>3000)
    throw new HttpsError('invalid-argument','Invalid reading checkpoint.');
  const ref=db.doc(`users/${uid}/readingResumes/day-${checkpoint.day}`);
  return db.runTransaction(async tx=>{
    const guard=await tx.get(accountStateRef(uid)),journey=(await tx.get(privateDoc(uid,'journey'))).data(),prior=(await tx.get(ref)).data();
    if(guard.data()?.deleting===true||!journey||checkpoint.journeyRevision!==(journey.revision||1))return {accepted:false,reason:'revision'};
    try{mergeCompletion(journey,checkpoint.day,dateKey(new Date(),journey.timeZone));}catch{throw new HttpsError('permission-denied','This reading is still ahead.');}
    if(prior?.checkpoint?.checkpointId===checkpoint.checkpointId)return {accepted:true,checkpointRevision:prior.checkpointRevision};
    if((prior?.checkpointRevision||0)!==body.expectedRevision)return {accepted:false,reason:'conflict',current:prior||null};
    const checkpointRevision=body.expectedRevision+1;
    tx.set(ref,{checkpoint,checkpointRevision,journeyRevision:checkpoint.journeyRevision,cleared:false,updatedAt:FieldValue.serverTimestamp()});
    return {accepted:true,checkpointRevision};
  });
});

function requireRecentAuth(request) {
  if(Date.now()/1000-(request.auth.token.auth_time||0)>300)throw new HttpsError('unauthenticated','Please sign in again to continue.');
}
exports.resetLearningProgress=onCall(options,async request=>{
  const uid=uidOf(request);requireRecentAuth(request);
  const operationId=request.data?.operationId;
  if(typeof operationId!=='string'||!/^[a-zA-Z0-9-]{16,100}$/.test(operationId))throw new HttpsError('invalid-argument','A reset operation ID is required.');
  const operationRef=db.doc(`users/${uid}/resetOperations/${operationId}`);
  const result=await db.runTransaction(async tx=>{
    const guard=await tx.get(accountStateRef(uid)),ref=privateDoc(uid,'journey');
    const data=(await tx.get(ref)).data();
    const previous=(await tx.get(operationRef)).data();
    if(guard.data()?.deleting===true||!data)throw new HttpsError('failed-precondition','Your journey is unavailable.');
    if(previous)return previous.result;
    const reset={...data,earnedBadges:journeyPayload(data).earnedBadges,completedDays:[],completionDates:{},revision:(data.revision||1)+1};
    tx.update(ref,{earnedBadges:reset.earnedBadges,completedDays:[],completionDates:{},revision:reset.revision,updatedAt:FieldValue.serverTimestamp()});
    // Commit the receipt with the revision; an uncertain response can be retried.
    tx.create(operationRef,{result:journeyPayload(reset),createdAt:FieldValue.serverTimestamp()});
    return journeyPayload(reset);
  });
  // Clean old records only; a new attempt created during reset is preserved.
  for(const collection of ['attempts','resumes','readingResumes']) {
    const records=await db.collection(`users/${uid}/${collection}`).get();
    for(const row of records.docs)await db.runTransaction(async tx=>{
      const current=(await tx.get(row.ref)).data();
      const revision=current?.journeyRevision??current?.attempt?.journeyRevision??1;
      if(current&&revision<result.revision)tx.delete(row.ref);
    });
  }
  return result;
});
exports.completeLessonAttempt=onCall(options,async request=>{
  const uid=uidOf(request),body=request.data||{},ref=privateDoc(uid,'journey');
  if(!Number.isInteger(body.day)||body.day<1||body.day>365||typeof body.attemptId!=='string'||!/^[a-zA-Z0-9-]{16,100}$/.test(body.attemptId))throw new HttpsError('invalid-argument','Invalid attempt ID.');
  const attemptRef=db.doc(`users/${uid}/attempts/${body.attemptId}`);
  return db.runTransaction(async tx=>{
    const account=await tx.get(accountStateRef(uid));
    const journey=(await tx.get(ref)).data();
    const previous=(await tx.get(attemptRef)).data();
    const resumeRef=db.doc(`users/${uid}/resumes/day-${body.day}`);
    const checkpoint=(await tx.get(resumeRef)).data();
    const access=await editionAccess(tx,uid,{grant:!!journey});
    if(account.data()?.deleting===true||!access.eligible)throw new HttpsError('permission-denied','This edition is unavailable.');
    if(!journey)throw new HttpsError('failed-precondition','Start your journey first.');
    if(body.journeyRevision!==(journey.revision||1))throw new HttpsError('failed-precondition','Your learning progress was reset. Reopen the lesson.');
    if(previous) {
      if(previous.day!==body.day||previous.contentVersion!==body.contentVersion)throw new HttpsError('already-exists','This attempt ID belongs to another lesson.');
      return previous.result;
    }
    let grade,completedDays;
    try {
      grade=require('./domain').gradeAttempt(require('./teaching.json'),body,journey.revision||1);
      completedDays=mergeCompletion(journey,body.day,dateKey(new Date(),journey.timeZone));
    }catch(error){throw new HttpsError('invalid-argument',`Cannot accept this attempt: ${error.message}`);}
    const completionDates={...(journey.completionDates||{}),...(!(journey.completedDays||[]).includes(body.day)?{[body.day]:dateKey(new Date(),journey.timeZone)}:{})};
    const readingDates=[...new Set([...(journey.readingDates||Object.values(journey.completionDates||{})),dateKey(new Date(),journey.timeZone)])].sort();
    const earnedBadges=journeyPayload({...journey,completedDays}).earnedBadges;
    const result={...grade,...journeyPayload(journey),completedDays,completionDates,readingDates,earnedBadges,attemptId:body.attemptId};
    writeGrant(tx,access);
    // An older offline completion must not clear a different active practice.
    if(!checkpoint||checkpoint.cleared===true||checkpoint.attempt?.attemptId===body.attemptId)
      tx.set(resumeRef,{cleared:true,checkpointRevision:(checkpoint?.checkpointRevision||0)+1,journeyRevision:body.journeyRevision,completedAttemptId:body.attemptId,updatedAt:FieldValue.serverTimestamp()});
    tx.create(attemptRef,{day:body.day,contentVersion:body.contentVersion,journeyRevision:body.journeyRevision,result,createdAt:FieldValue.serverTimestamp()});
    tx.update(ref,{completedDays,completionDates,readingDates,earnedBadges,updatedAt:FieldValue.serverTimestamp()});
    return result;
  });
});
exports.saveLessonResume=onCall(options,async request=>{
  const uid=uidOf(request),body=request.data||{},resume=body.resume;
  if(!Number.isInteger(body.expectedRevision)||body.expectedRevision<0||typeof resume?.checkpointId!=='string'||!/^[a-zA-Z0-9-]{16,100}$/.test(resume.checkpointId))throw new HttpsError('invalid-argument','A checkpoint identity and base revision are required.');
  const steps=['opening','verse','understand','question-1','confidence','hope','question-2','carry','closing'];
  if(!resume||!steps.includes(resume.stepId)||!Number.isInteger(resume.renderedPart)||resume.renderedPart<0||resume.renderedPart>100||JSON.stringify(resume).length>16000)throw new HttpsError('invalid-argument','Invalid checkpoint.');
  if(resume.readingOffset!=null&&(!Number.isInteger(resume.readingOffset)||resume.readingOffset<0||resume.readingOffset>20000))throw new HttpsError('invalid-argument','Invalid reading position.');
  const attempt=resume.attempt,catalog=require('./teaching.json');
  const lesson=catalog.lessons.find(l=>l.day===attempt?.day);
  if(!lesson||attempt.contentVersion!==catalog.version||typeof attempt.attemptId!=='string'||!/^[a-zA-Z0-9-]{16,100}$/.test(attempt.attemptId))throw new HttpsError('invalid-argument','Invalid attempt.');
  if(!attempt.selectedOptionIds||!attempt.optionOrder||Object.keys(attempt.selectedOptionIds).some(id=>!lesson.questions.some(q=>q.id===id)))throw new HttpsError('invalid-argument','Invalid answers.');
  for(const q of lesson.questions) {
    const order=attempt.optionOrder[q.id];
    if(!Array.isArray(order)||order.length!==4||new Set(order).size!==4||!order.every(id=>q.options.some(o=>o.id===id))||(attempt.selectedOptionIds[q.id]!=null&&!q.options.some(o=>o.id===attempt.selectedOptionIds[q.id])))throw new HttpsError('invalid-argument','Invalid option ordering.');
  }
  return db.runTransaction(async tx=>{
    const account=await tx.get(accountStateRef(uid)),journey=(await tx.get(privateDoc(uid,'journey'))).data();
    const completed=await tx.get(db.doc(`users/${uid}/attempts/${attempt.attemptId}`));
    const checkpointRef=db.doc(`users/${uid}/resumes/day-${attempt.day}`),previous=(await tx.get(checkpointRef)).data();
    const checkpointRevision=previous?.checkpointRevision||0;
    if(account.data()?.deleting===true||!journey||attempt.journeyRevision!==(journey.revision||1)||completed.exists)return {accepted:false};
    if(attempt.day>unlockedThrough(journey.startDate,dateKey(new Date(),journey.timeZone)))throw new HttpsError('permission-denied','This lesson is not available yet.');
    if(previous?.checkpointId===resume.checkpointId)return {accepted:true,checkpointRevision};
    if(body.expectedRevision!==checkpointRevision)return {accepted:false,reason:'conflict',checkpointRevision};
    const revision=checkpointRevision+1;
    tx.set(checkpointRef,{...resume,pending:false,checkpointRevision:revision,updatedAt:FieldValue.serverTimestamp()});
    return {accepted:true,checkpointRevision:revision};
  });
});
exports.setSavedLesson=onCall(options,async request=>{
  const uid=uidOf(request),{day,saved,operationId}=request.data||{};
  if(!Number.isInteger(day)||day<1||day>365||typeof saved!=='boolean'||(operationId!=null&&(typeof operationId!=='string'||!/^[a-zA-Z0-9-]{16,100}$/.test(operationId))))throw new HttpsError('invalid-argument','Invalid saved lesson.');
  return db.runTransaction(async tx=>{
    const account=await tx.get(accountStateRef(uid));
    const operationRef=operationId?db.doc(`users/${uid}/savedOperations/${operationId}`):null;
    const previous=operationRef?(await tx.get(operationRef)).data():null;
    const ref=privateDoc(uid,'savedCatalog'),catalog=(await tx.get(ref)).data()?.days||{};
    if(account.data()?.deleting===true)throw new HttpsError('permission-denied','Account deletion is in progress.');
    if(previous){
      if(previous.day!==day||previous.saved!==saved)throw new HttpsError('already-exists','This operation ID belongs to another change.');
      return previous;
    }
    // Server transaction order resolves competing devices. Retrying an old
    // operation returns its receipt without resurrecting a subsequent removal.
    const savedAt=saved?Date.now():null;
    const result={day,saved,savedAt,...(operationId?{operationId}:{})};
    tx.set(ref,{days:{...catalog,[day]:savedAt},updatedAt:FieldValue.serverTimestamp()});
    if(operationRef)tx.create(operationRef,result);
    return result;
  });
});
exports.exportAccountData=onCall(options,async request=>{
  const uid=uidOf(request),root=db.doc(`users/${uid}`);
  const account=await accountStateRef(uid).get();
  if(account.data()?.deleting===true)throw new HttpsError('permission-denied','Account deletion is in progress.');
  const [profile,journey,activity,access,saved,attempts,resumes,readingOperations,readingResumes]=await Promise.all([
    root.get(),privateDoc(uid,'journey').get(),privateDoc(uid,'activity').get(),privateDoc(uid,'editionAccess').get(),privateDoc(uid,'savedCatalog').get(),root.collection('attempts').get(),root.collection('resumes').get(),root.collection('readingOperations').get(),root.collection('readingResumes').get()]);
  return {edition:EDITION,exportedAt:new Date().toISOString(),profile:profile.data()||{},journey:journey.data()||{},activity:activity.data()||{},editionAccess:access.data()||{},saved:saved.data()||{},attempts:attempts.docs.map(d=>({id:d.id,...d.data()})),resumes:resumes.docs.map(d=>({id:d.id,...d.data()})),readingOperations:readingOperations.docs.map(d=>({id:d.id,...d.data()})),readingResumes:readingResumes.docs.map(d=>({id:d.id,...d.data()}))};
});
exports.markActive=onCall(options,async request=>{
  const uid=uidOf(request),ref=privateDoc(uid,'activity');
  return db.runTransaction(async tx=>{
    const account=await tx.get(accountStateRef(uid));
    const journey=(await tx.get(privateDoc(uid,'journey'))).data();
    const previous=(await tx.get(ref)).data()?.activeDays||[];
    if(account.data()?.deleting===true||!journey)return {activeDays:[]};
    let activeDays;
    try {activeDays=mergeActivityDays(journey,previous,request.data?.days??[],dateKey(new Date(),journey.timeZone));}
    catch {throw new HttpsError('invalid-argument','Please send valid activity dates.');}
    tx.set(ref,{activeDays,updatedAt:FieldValue.serverTimestamp()},{merge:true});
    return {activeDays};
  });
});
if(!baseOnly)exports.revenuecatWebhook=onRequest({...options,secrets:[rcKey,webhookSecret]},async(req,res)=>{
  const expected=Buffer.from(`Bearer ${webhookSecret.value()}`),actual=Buffer.from(req.get('authorization')||'');
  if(req.method!=='POST'||expected.length!==actual.length||!crypto.timingSafeEqual(expected,actual)){res.status(401).send('Unauthorized');return;}
  const event=req.body?.event;
  if(!event?.id||typeof event.id!=='string'||event.id.length>150){res.status(400).send('Invalid event');return;}
  const eventRef=db.collection('billingEvents').doc(crypto.createHash('sha256').update(event.id).digest('hex'));
  if((await eventRef.get()).exists){res.status(200).send('Already handled');return;}
  let ids;
  try { ids=webhookCustomerIds(event); } catch {res.status(400).send('Invalid identities');return;}
  try{
    for(const uid of new Set(ids))await reconcile(uid);
    await eventRef.set({processedAt:FieldValue.serverTimestamp(),expiresAt:Timestamp.fromMillis(Date.now()+30*86400000)});
    res.status(200).send('OK');
  }catch {res.status(503).send('Please retry');}
});
exports.deleteAccount=onCall(options,async request=>{
  const uid=uidOf(request);requireRecentAuth(request);
  // Capture legacy billing cleanup privately before deleting personal data.
  // A billing provider outage never blocks deletion from HolyHer.
  await db.runTransaction(async tx=>{
    const entitlement=await tx.get(privateDoc(uid,'entitlement'));
    tx.set(accountStateRef(uid),{deleting:true,createdAt:FieldValue.serverTimestamp()});
    // Rules cannot hash a UID. Keep a second server-owned guard at an
    // address rules can evaluate, outside the recursively deleted user tree.
    tx.set(db.doc(`deletionGuards/${uid}`),{deleting:true,createdAt:FieldValue.serverTimestamp()});
    if(entitlement.exists)tx.set(db.doc(`legacyBillingCleanup/${crypto.createHash('sha256').update(uid).digest('hex')}`),
      {uid,status:'pending',createdAt:FieldValue.serverTimestamp()});
  });
  await db.recursiveDelete(db.doc(`users/${uid}`));
  try{await getAuth().deleteUser(uid);}catch(error){if(error.code!=='auth/user-not-found')throw error;}
  return {deleted:true};
});

if(!baseOnly) {
  const {onSchedule}=require('firebase-functions/v2/scheduler');
  exports.retryLegacyBillingCleanup=onSchedule({...options,schedule:'every 24 hours',secrets:[rcKey],timeoutSeconds:300},async()=>{
    const pending=await db.collection('legacyBillingCleanup').where('status','==','pending').limit(20).get();
    for(const row of pending.docs) {
      try {
        const response=await fetch(rcCustomerUrl(row.data().uid),{method:'DELETE',headers:{Authorization:`Bearer ${rcKey.value()}`},signal:AbortSignal.timeout(12000)});
        if(response.ok||response.status===404)await row.ref.delete();
        else await row.ref.set({lastAttemptAt:FieldValue.serverTimestamp(),attempts:FieldValue.increment(1)},{merge:true});
      }catch(_){await row.ref.set({lastAttemptAt:FieldValue.serverTimestamp(),attempts:FieldValue.increment(1)},{merge:true});}
    }
  });
}

exports.supportRequest=onRequest({...options,cors:['https://holyher-app-production.web.app','https://holyher-app-production.firebaseapp.com'],timeoutSeconds:20},async(req,res)=>{
  if(req.method!=='POST'){res.status(405).json({error:'Please send the support form.'});return;}
  const {email,message,website,purpose='support',appVersion}=req.body||{};
  if(!['support','feedback'].includes(purpose)|| (appVersion!=null&&(typeof appVersion!=='string'||appVersion.length>80))){res.status(400).json({error:'Please choose support or feedback.'});return;}
  if(website){res.status(200).json({received:true});return;}
  if(typeof email!=='string'||email.length>254||!/^\S+@\S+\.\S+$/.test(email)||typeof message!=='string'||message.trim().length<10||message.length>5000){res.status(400).json({error:'Please enter your email and a message between 10 and 5,000 characters.'});return;}
  const hour=Math.floor(Date.now()/3600000);
  const rateId=crypto.createHash('sha256').update(`${req.ip}|${hour}|holyher-support`).digest('hex');
  try{
    await db.runTransaction(async tx=>{
      const rate=db.doc(`supportRateLimits/${rateId}`),old=(await tx.get(rate)).data();
      if((old?.count||0)>=3)throw new Error('rate');
      tx.set(rate,{count:(old?.count||0)+1,expiresAt:Timestamp.fromMillis(Date.now()+86400000)});
      tx.create(db.collection('supportRequests').doc(),{email:email.trim(),message:message.trim(),purpose,...(appVersion?{appVersion}:{}),createdAt:FieldValue.serverTimestamp(),status:'new'});
    });
    res.status(200).json({received:true});
  }catch(e){res.status(e.message==='rate'?429:503).json({error:e.message==='rate'?'Please wait a little before sending another message.':'Your message could not be sent. Please try again shortly.'});}
});
