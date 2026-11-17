'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {lifetimeActive, accessFrom, customerIds, createBilling} = require('../billing');
const entitlement = {entitlement_id: 'entld8cfd982e8', expires_at: null};
test('only the verified lifetime entitlement activates ownership; a refund removes it', () => {
  assert.equal(lifetimeActive({object:'list',items:[entitlement]}),true);
  assert.equal(lifetimeActive({object:'list',items:[]}),false);
  assert.equal(lifetimeActive({object:'list',items:[{...entitlement,expires_at:100}]},200),false);
  assert.equal(lifetimeActive({object:'list',items:[{...entitlement,entitlement_id:'other'}]}),false);
  assert.throws(()=>lifetimeActive({items:[entitlement]}));
});
test('webhook identities exclude anonymous aliases and path injection',()=>{
  assert.deepEqual(customerIds({app_user_id:'alice',aliases:['alice','bob','$RCAnonymousID:x','users/evil']}),['alice','bob']);
  assert.throws(()=>customerIds({aliases:'alice'}));
});
class HttpsError extends Error { constructor(code,message){super(message);this.code=code;} }
function fixture({retained=true,active=false,deleting=false,refund=false,items=null,clock=()=>Date.now()}={}){
 const rows=new Map([
  ['users/alice/private/editionAccess',{edition:'holyhim365',retained}],
  ['users/alice/private/entitlement',{active}],['deletionGuards/alice',{deleting}],
 ]);
 const doc=path=>({path,async get(){return {exists:rows.has(path),data:()=>rows.get(path)};},async set(value,options){rows.set(path,options?.merge?{...rows.get(path),...value}:value);}});
 const db={doc,async runTransaction(fn){return fn({get:r=>r.get(),set:(r,v,o)=>r.set(v,o)});}};
 return {rows,...createBilling({db,auth:{async getUser(){return {uid:'alice'};}},HttpsError,
  FieldValue:{serverTimestamp:()=>0},Timestamp:{fromMillis:v=>v},apiKey:()=>'<test>',webhookSecret:()=>'<test>',
  now:clock,memberEntitlementId:'entlmember',
  fetcher:async()=>({ok:true,status:200,json:async()=>({object:'list',items:items??(refund?[]:[entitlement])})})})};
}
test('retained access remains independent of verified purchase ownership',async()=>{
 const api=fixture();assert.deepEqual(await api.getAccessStatus({auth:{uid:'alice'}}),
  {edition:'holyhim365',retained:true,retainedGrant:true,genuinePurchase:false,kind:'lifetime',eligible:true});
 assert.deepEqual(await api.syncAccess({auth:{uid:'alice'}}),{active:true});
 assert.equal(api.rows.get('users/alice/private/editionAccess').retained,true);
 const refunded=fixture({active:true,refund:true});
 assert.deepEqual(await refunded.syncAccess({auth:{uid:'alice'}}),{active:false});
 assert.equal((await refunded.getAccessStatus({auth:{uid:'alice'}})).eligible,true);
});
test('deleted accounts cannot be reactivated and unsigned access reads fail',async()=>{
 const api=fixture({deleting:true});
 await assert.rejects(api.getAccessStatus({}),e=>e.code==='unauthenticated');
 await assert.rejects(api.getAccessStatus({auth:{uid:'alice'}}),e=>e.code==='permission-denied');
 assert.deepEqual(await api.syncAccess({auth:{uid:'alice'}}),{active:false});
});

const member = {entitlement_id: 'entlmember', expires_at: 5000};
test('a membership opens access until its period ends; lifetime outranks it', () => {
  assert.deepEqual(accessFrom({object:'list',items:[member]},1000,'entlmember'),{active:true,kind:'member',expiresAt:5000});
  assert.deepEqual(accessFrom({object:'list',items:[member]},6000,'entlmember'),{active:false,kind:null,expiresAt:null});
  assert.equal(accessFrom({object:'list',items:[member,entitlement]},1000,'entlmember').kind,'lifetime');
  // Until RevenueCat's membership id is known, a membership is not counted here.
  assert.equal(accessFrom({object:'list',items:[member]},1000,null).active,false);
  assert.equal(lifetimeActive({object:'list',items:[member]},1000),false);
});
test('a verified membership is reported as one and lapses at its end date', async () => {
  let t = 1000;
  const api = fixture({retained:false, items:[member], clock:()=>t});
  assert.deepEqual(await api.syncAccess({auth:{uid:'alice'}}),{active:true});
  const record = api.rows.get('users/alice/private/entitlement');
  assert.equal(record.type,'member');
  assert.equal(record.expiresAt,5000);
  const open = await api.getAccessStatus({auth:{uid:'alice'}});
  assert.equal(open.genuinePurchase,true);
  assert.equal(open.kind,'member');
  t = 6000;
  const lapsed = await api.getAccessStatus({auth:{uid:'alice'}});
  assert.equal(lapsed.genuinePurchase,false);
  assert.equal(lapsed.eligible,false);
});
