'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {lifetimeActive, customerIds, createBilling} = require('../billing');
const entitlement = {entitlement_id: process.env.REVENUECAT_ENTITLEMENT_ID || 'holyhim_lifetime_entitlement', expires_at: null};
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
function fixture({retained=true,active=false,deleting=false,refund=false}={}){
 const rows=new Map([
  ['users/alice/private/editionAccess',{edition:'holyhim365',retained}],
  ['users/alice/private/entitlement',{active}],['deletionGuards/alice',{deleting}],
 ]);
 const doc=path=>({path,async get(){return {exists:rows.has(path),data:()=>rows.get(path)};},async set(value,options){rows.set(path,options?.merge?{...rows.get(path),...value}:value);}});
 const db={doc,async runTransaction(fn){return fn({get:r=>r.get(),set:(r,v,o)=>r.set(v,o)});}};
 return {rows,...createBilling({db,auth:{async getUser(){return {uid:'alice'};}},HttpsError,
  FieldValue:{serverTimestamp:()=>0},Timestamp:{fromMillis:v=>v},apiKey:()=>'<test>',webhookSecret:()=>'<test>',
  fetcher:async()=>({ok:true,status:200,json:async()=>({object:'list',items:refund?[]:[entitlement]})})})};
}
test('retained access remains independent of verified purchase ownership',async()=>{
 const api=fixture();assert.deepEqual(await api.getAccessStatus({auth:{uid:'alice'}}),
  {edition:'holyhim365',retained:true,retainedGrant:true,genuinePurchase:false,eligible:true});
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
