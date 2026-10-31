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
exports.startJourney=onCall(options,async request=>{
  const uid=uidOf(request); const zone=request.data?.timeZone;
  if(!validTimeZone(zone)) throw new HttpsError('invalid-argument','Please choose a valid time zone.');
  const ref=privateDoc(uid,'journey');
  await db.runTransaction(async tx=>{
    const account=await tx.get(accountStateRef(uid));
    const access=await tx.get(privateDoc(uid,'entitlement'));
    const journey=await tx.get(ref);
    if(account.data()?.deleting===true||access.data()?.active!==true) throw new HttpsError('permission-denied','Please restore your lifetime purchase.');
    if(journey.exists)return;
    tx.create(ref,{startedAt:FieldValue.serverTimestamp(),startDate:dateKey(new Date(),zone),timeZone:zone,completedDays:[],updatedAt:FieldValue.serverTimestamp()});
  });
  return journeyPayload((await ref.get()).data());
});
function journeyPayload(data) {
  if(!data) return {started:false};
  return {started:true,startDate:data.startDate,timeZone:data.timeZone,completedDays:data.completedDays||[],unlockedThrough:unlockedThrough(data.startDate,dateKey(new Date(),data.timeZone)),serverDate:dateKey(new Date(),data.timeZone)};
}
exports.getJourney=onCall(options,async request=>journeyPayload((await privateDoc(uidOf(request),'journey').get()).data()));
exports.completeLesson=onCall(options,async request=>{
  const uid=uidOf(request); const day=request.data?.day;
  const ref=privateDoc(uid,'journey');
  return db.runTransaction(async tx=>{
    const account=await tx.get(accountStateRef(uid));
    const access=await tx.get(privateDoc(uid,'entitlement'));
    if(account.data()?.deleting===true||access.data()?.active!==true)throw new HttpsError('permission-denied','Your lifetime access needs to be restored.');
    const data=(await tx.get(ref)).data();
    if(!data)throw new HttpsError('failed-precondition','Your journey has not started yet.');
    const today=dateKey(new Date(),data.timeZone);
    let completedDays;
    try { completedDays=mergeCompletion(data,day,today); } catch {throw new HttpsError('invalid-argument','This lesson is not available yet.');}
    tx.update(ref,{completedDays,updatedAt:FieldValue.serverTimestamp()});
    return {...journeyPayload(data),completedDays};
  });
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
if(!baseOnly)exports.deleteAccount=onCall({...options,secrets:[rcKey]},async request=>{
  const uid=uidOf(request);
  if(Date.now()/1000-(request.auth.token.auth_time||0)>300)throw new HttpsError('unauthenticated','Please sign in again before deleting your account.');
  const response=await fetch(rcCustomerUrl(uid),{method:'DELETE',headers:{Authorization:`Bearer ${rcKey.value()}`},signal:AbortSignal.timeout(12000)});
  if(!response.ok&&response.status!==404)throw new HttpsError('unavailable','Account deletion could not finish. Please try again shortly.');
  // The marker contains no profile/email data and blocks delayed reconciles or
  // activity writes while the third-party deletion is processed asynchronously.
  await accountStateRef(uid).set({deleting:true,createdAt:FieldValue.serverTimestamp()});
  await db.recursiveDelete(db.doc(`users/${uid}`));
  try {await getAuth().deleteUser(uid);} catch(error) {if(error.code!=='auth/user-not-found')throw error;}
  return {deleted:true};
});

exports.supportRequest=onRequest({...options,cors:['https://holyher-app-production.web.app','https://holyher-app-production.firebaseapp.com'],timeoutSeconds:20},async(req,res)=>{
  if(req.method!=='POST'){res.status(405).json({error:'Please send the support form.'});return;}
  const {email,message,website}=req.body||{};
  if(website){res.status(200).json({received:true});return;}
  if(typeof email!=='string'||email.length>254||!/^\S+@\S+\.\S+$/.test(email)||typeof message!=='string'||message.trim().length<10||message.length>5000){res.status(400).json({error:'Please enter your email and a message between 10 and 5,000 characters.'});return;}
  const hour=Math.floor(Date.now()/3600000);
  const rateId=crypto.createHash('sha256').update(`${req.ip}|${hour}|holyher-support`).digest('hex');
  try{
    await db.runTransaction(async tx=>{
      const rate=db.doc(`supportRateLimits/${rateId}`),old=(await tx.get(rate)).data();
      if((old?.count||0)>=3)throw new Error('rate');
      tx.set(rate,{count:(old?.count||0)+1,expiresAt:Timestamp.fromMillis(Date.now()+86400000)});
      tx.create(db.collection('supportRequests').doc(),{email:email.trim(),message:message.trim(),createdAt:FieldValue.serverTimestamp(),status:'new'});
    });
    res.status(200).json({received:true});
  }catch(e){res.status(e.message==='rate'?429:503).json({error:e.message==='rate'?'Please wait a little before sending another message.':'Your message could not be sent. Please try again shortly.'});}
});
