'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {createHandlers} = require('../handlers');
const NOW = 1804183200000;
class HttpsError extends Error { constructor(code, message) { super(message); this.code = code; } }
function fixture({authFailure, deleteFailure, transactionFailure, photoFailure, photos = false} = {}) {
  const calls = [], rows = new Map();
  const db = {
    doc(path) { return {path, async set(value) { calls.push(['set', path, value]); rows.set(path, value); }}; },
    collection(path) { return {doc() { return {path: `${path}/generated`}; }}; },
    async recursiveDelete(ref) { calls.push(['recursiveDelete', ref.path]); if (deleteFailure) throw deleteFailure; },
    async runTransaction(work) {
      if (transactionFailure) throw transactionFailure;
      const staged = [];
      const tx = {
        async get(ref) { return {data: () => rows.get(ref.path)}; },
        set(ref, data) { staged.push([ref.path, data]); },
        create(ref, data) { staged.push([ref.path, data]); },
      };
      await work(tx);
      for (const [path, data] of staged) { rows.set(path, data); calls.push(['transaction', path, data]); }
    },
  };
  const auth = {async deleteUser(uid) { calls.push(['deleteUser', uid]); if (authFailure) throw authFailure; }};
  return {calls, rows, ...createHandlers({db, auth, HttpsError,
    storage: photos ? {async deleteFiles(options) {calls.push(['deletePhotos', options.prefix]);if(photoFailure)throw photoFailure;}} : undefined,
    FieldValue: {serverTimestamp: () => 'server-time'}, Timestamp: {fromMillis: value => value}, now: () => NOW})};
}
function request(authTime = NOW / 1000) { return {auth: {uid: 'alice', token: {auth_time: authTime}}}; }
function response() { return {statusCode: 0, body: null, status(value) { this.statusCode = value; return this; }, json(value) { this.body = value; return this; }}; }
const supportBody = {email: ' alice@example.com', message: '  I would like help signing in.  ', appVersion: '2.0.0 (5)'};
const validBody = {...supportBody, email: 'alice@example.com'};

test('delete requires a signed-in user with recent authentication', async () => {
  const api = fixture();
  for (const req of [{}, {auth: {uid: 'alice', token: {}}}, request(NOW / 1000 - 301), request(NOW / 1000 + 61)]) {
    await assert.rejects(api.deleteAccount(req), error => error.code === 'unauthenticated');
  }
  assert.deepEqual(api.calls, []);
});

test('delete writes permanent guard before deleting data and auth', async () => {
  const api = fixture();
  assert.deepEqual(await api.deleteAccount(request()), {deleted: true});
  assert.deepEqual(api.calls.map(call => call.slice(0, 2)), [['set', 'deletionGuards/alice'], ['recursiveDelete', 'users/alice'], ['recursiveDelete', 'circle/alice'], ['deleteUser', 'alice']]);
  assert.equal(api.rows.get('deletionGuards/alice').deleting, true);
});

test('delete can be retried after auth is already gone; data failures retain guard', async () => {
  const api = fixture({authFailure: {code: 'auth/user-not-found'}});
  assert.deepEqual(await api.deleteAccount(request()), {deleted: true});
  const failed = fixture({deleteFailure: new Error('Firestore unavailable')});
  await assert.rejects(failed.deleteAccount(request()), /Firestore unavailable/);
  assert.equal(failed.rows.get('deletionGuards/alice').deleting, true);
  assert.equal(failed.calls.some(call => call[0] === 'deleteUser'), false);
  const authFailed = fixture({authFailure: new Error('Auth unavailable')});
  await assert.rejects(authFailed.deleteAccount(request()), /Auth unavailable/);
});

test('support accepts the app/web payload and stores trimmed message plus version', async () => {
  const api = fixture(), res = response();
  await api.supportRequest({method: 'POST', ip: '127.0.0.1', body: validBody}, res);
  assert.equal(res.statusCode, 200);
  assert.deepEqual(res.body, {received: true});
  const stored = api.rows.get('supportRequests/generated');
  assert.equal(stored.email, 'alice@example.com');
  assert.equal(stored.message, 'I would like help signing in.');
  assert.equal(stored.appVersion, '2.0.0 (5)');
  assert.equal(stored.status, 'new');
  assert.equal(stored.purpose, 'support');
});

test('support validates fields, method and honeypot without recording invalid data', async () => {
  for (const body of [{...validBody, email: 'not-email'}, {...validBody, message: 'short'}, {...validBody, message: 'x'.repeat(5001)}, {...validBody, purpose: 'other'}, {...validBody, appVersion: 'x'.repeat(81)}]) {
    const api = fixture(), res = response();
    await api.supportRequest({method: 'POST', body}, res);
    assert.equal(res.statusCode, 400);
    assert.equal(api.calls.length, 0);
  }
  const api = fixture(), get = response(), bot = response();
  await api.supportRequest({method: 'GET'}, get);
  await api.supportRequest({method: 'POST', body: {website: 'spam'}}, bot);
  assert.equal(get.statusCode, 405);
  assert.equal(bot.statusCode, 200);
  assert.equal(api.calls.length, 0);
});

test('account deletion removes photos before account data and retries a photo failure', async () => {
 const success=fixture({photos:true});await success.deleteAccount(request());
 assert.deepEqual(success.calls.map(call=>call.slice(0,2)),[['set','deletionGuards/alice'],['deletePhotos','users/alice/avatars/'],['recursiveDelete','users/alice'],['recursiveDelete','circle/alice'],['deleteUser','alice']]);
 const failed=fixture({photos:true,photoFailure:new Error('offline')});
 await assert.rejects(failed.deleteAccount(request()));
 assert.equal(failed.calls.some(call=>call[0]==='deleteUser'),false);
 assert.equal(failed.calls.some(call=>call[0]==='recursiveDelete'),false);
 assert.ok(failed.rows.has('deletionGuards/alice'));
});

test('support permits three submissions per IP/hour then returns 429; storage errors return 503', async () => {
  const api = fixture();
  for (let i = 0; i < 4; i++) {
    const res = response();
    await api.supportRequest({method: 'POST', ip: '127.0.0.1', body: validBody}, res);
    assert.equal(res.statusCode, i < 3 ? 200 : 429);
  }
  const failed = fixture({transactionFailure: new Error('offline')}), res = response();
  await failed.supportRequest({method: 'POST', body: validBody}, res);
  assert.equal(res.statusCode, 503);
});

test('production entry point includes reviewed billing and avatar cleanup endpoints', () => {
  assert.deepEqual(Object.keys(require('../index')).sort(), ['circleProfile', 'circleProgress', 'cleanupReplacedAvatar', 'deleteAccount', 'getAccessStatus', 'reportMember', 'revenuecatWebhook', 'sendAmen', 'supportRequest', 'syncAccess']);
});
