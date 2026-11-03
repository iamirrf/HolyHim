'use strict';
// Read-only inventory by default. --backfill explicitly writes retained grants.
// Run from this directory with trusted Admin application-default credentials.
const {initializeApp}=require('firebase-admin/app');
const {getFirestore,FieldValue}=require('firebase-admin/firestore');
initializeApp();
(async()=>{
 const db=getFirestore(),write=process.argv.includes('--backfill');
 const snapshot=await db.collectionGroup('private').get();
 let journeys=0,legacyRecords=0,grants=0,created=0;
 for(const doc of snapshot.docs){
  if(!/^users\/[^/]+\/private\/[^/]+$/.test(doc.ref.path))continue;
  if(doc.id==='entitlement')legacyRecords++;
  if(doc.id==='editionAccess'&&doc.data().retained===true)grants++;
  if(doc.id!=='journey')continue;
  journeys++;
  if(write)await db.runTransaction(async tx=>{
   const grant=doc.ref.parent.doc('editionAccess'),guard=db.doc(`accountStates/${require('node:crypto').createHash('sha256').update(doc.ref.parent.parent.id).digest('hex')}`);
   const [state,existing,journey]=await Promise.all([tx.get(guard),tx.get(grant),tx.get(doc.ref)]);
   if(state.data()?.deleting||!journey.exists||existing.data()?.retained)return;
   tx.set(grant,{edition:'holyher365',retained:true,source:'free-enrollment-backfill',grantedAt:FieldValue.serverTimestamp()});created++;
  });
 }
 // No personal identifiers are printed.
 console.log(JSON.stringify({mode:write?'backfill':'read-only',journeys,legacyRecords,grants,created}));
})().catch(()=>{console.error('Inventory failed. Verify trusted project credentials and retry.');process.exitCode=1;});
