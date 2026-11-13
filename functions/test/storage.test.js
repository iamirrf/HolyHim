'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const host = process.env.FIREBASE_STORAGE_EMULATOR_HOST;
const project = 'demo-holyhim';
if (host && (!/^127\.0\.0\.1:\d+$/.test(host) || process.env.GCLOUD_PROJECT !== project)) {
  throw new Error('Storage tests require the local demo-holyhim emulator.');
}
function token(uid) {
  const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  return `${encode({alg:'none',typ:'JWT'})}.${encode({iss:`https://securetoken.google.com/${project}`,aud:project,sub:uid,user_id:uid,iat:now,exp:now+3600,firebase:{sign_in_provider:'custom'}})}.`;
}
async function object(name, {uid, method = 'POST', type = 'image/jpeg', bytes = 128} = {}) {
  const root = `http://${host}/v0/b/${project}.appspot.com/o`;
  const url = method === 'POST' ? `${root}?name=${encodeURIComponent(name)}&uploadType=media` : `${root}/${encodeURIComponent(name)}?alt=media`;
  const boundary = 'holyhim-avatar-test';
  const body = Buffer.concat([Buffer.from(`--${boundary}\r\nContent-Type: application/json\r\n\r\n${JSON.stringify({name,contentType:type})}\r\n--${boundary}\r\nContent-Type: ${type}\r\n\r\n`), Buffer.alloc(bytes), Buffer.from(`\r\n--${boundary}--\r\n`)]);
  return fetch(url, {method, headers:{'Content-Type':`multipart/related; boundary=${boundary}`,'X-Goog-Upload-Protocol':'multipart',...(uid?{Authorization:`Bearer ${token(uid)}`}:{})}, ...(method === 'POST'?{body}:{})});
}
test('avatars enforce owner, JPEG size and path; replaced/deleted photos can be removed', {skip:!host}, async () => {
  const path = 'users/avatar-owner/avatars/123456.jpg';
  assert.equal((await object(path, {uid:'avatar-owner'})).status, 200);
  assert.equal((await object(path, {uid:'avatar-owner',method:'GET'})).status, 200);
  assert.equal((await object(path, {uid:'other',method:'GET'})).status, 403);
  assert.equal((await object(path, {method:'GET'})).status, 403);
  assert.equal((await object(path, {uid:'other'})).status, 403);
  assert.equal((await object('users/avatar-owner/avatars/2.jpg', {uid:'avatar-owner',type:'text/html'})).status, 403);
  assert.equal((await object('users/avatar-owner/avatars/3.jpg', {uid:'avatar-owner',bytes:2*1024*1024})).status, 403);
  assert.equal((await object('users/avatar-owner/avatars/arbitrary.png', {uid:'avatar-owner'})).status, 403);
  assert.equal((await object('users/avatar-owner/unrestricted.jpg', {uid:'avatar-owner'})).status, 403);
  assert.equal((await object(path, {uid:'other',method:'DELETE'})).status, 403);
  assert.equal((await object(path, {uid:'avatar-owner',method:'DELETE'})).status, 204);
});
test('account deletion guard blocks late avatar uploads', {skip:!host}, async () => {
  const firestore = process.env.FIRESTORE_EMULATOR_HOST;
  assert.ok(firestore);
  const response = await fetch(`http://${firestore}/v1/projects/${project}/databases/(default)/documents/deletionGuards/avatar-deleted`, {method:'PATCH',headers:{Authorization:'Bearer owner','Content-Type':'application/json'},body:JSON.stringify({fields:{active:{booleanValue:true}}})});
  assert.equal(response.status, 200);
  assert.equal((await object('users/avatar-deleted/avatars/123.jpg', {uid:'avatar-deleted'})).status, 403);
});
