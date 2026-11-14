'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {textProblem, createCommunity} = require('../community');

test('moderation refuses slurs, explicit words, threats and links, and folds look-alikes', () => {
  for (const bad of ['this is shit', 'sh1t', 'F U C K'.replace(/ /g, ''), 'you whore', 'kys', 'kill yourself',
    'go to www.site.com', 'https://x.io', 'send nudes', 'onlyfans link']) {
    assert.ok(textProblem(bad), bad);
  }
  for (const fine of ['Praying for you, brother.', 'Suspicious of spicy food', 'Peacock and Hancock',
    'Assassin was a hard word to spell', 'God is good. Hell is real.']) {
    assert.equal(textProblem(fine), null, fine);
  }
  assert.ok(textProblem('a'));
  assert.ok(textProblem('x'.repeat(601)));
  assert.equal(textProblem('x'.repeat(24) + ' ok', 600), null);
});

test('the app and the server share one pattern list', () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const dart = fs.readFileSync(path.join(__dirname, '../../lib/services/community.dart'), 'utf8');
  const listed = [...dart.matchAll(/^  r'(.+)',$/gm)].map(m => m[1]);
  assert.deepEqual(listed, require('../moderation.json').patterns);
});

function fakeDb(docs = {}) {
  const store = new Map(Object.entries(docs));
  const ref = path => ({
    path, id: path.split('/').pop(),
    get: async () => snapshot(path),
    set: async data => { store.set(path, {...data}); },
    update: async data => { store.set(path, {...store.get(path), ...data}); },
    delete: async () => { store.delete(path); },
    collection: name => collection(`${path}/${name}`),
  });
  const snapshot = path => ({exists: store.has(path), data: () => store.get(path), ref: ref(path), id: path.split('/').pop()});
  let n = 0;
  const collection = path => ({
    doc: id => ref(`${path}/${id ?? `auto${++n}`}`),
    where: (field, op, value) => ({get: async () => ({docs: [...store.keys()]
      .filter(k => k.startsWith(`${path}/`) && k.split('/').length === path.split('/').length + 1)
      .filter(k => op === '==' ? store.get(k)[field] === value : (store.get(k)[field] || []).includes(value))
      .map(snapshot)})}),
    get: async () => ({docs: [...store.keys()].filter(k => k.startsWith(`${path}/`) && k.split('/').length === path.split('/').length + 1).map(snapshot)}),
  });
  return {
    store,
    doc: ref,
    collection,
    recursiveDelete: async r => { for (const k of [...store.keys()]) if (k === r.path || k.startsWith(`${r.path}/`)) store.delete(k); },
    runTransaction: async fn => fn({
      get: r => r.get(),
      set: (r, data, opts) => store.set(r.path, opts?.merge ? {...store.get(r.path), ...data} : {...data}),
      update: (r, data) => store.set(r.path, {...store.get(r.path), ...data}),
      delete: r => store.delete(r.path),
    }),
  };
}
class HttpsError extends Error { constructor(code, message) { super(message); this.code = code; } }
const FieldValue = {
  serverTimestamp: () => 'now', increment: n => ({inc: n}), arrayRemove: v => ({remove: v}),
};

test('posting needs membership, keeps the author card and rejects unclean text', async () => {
  const db = fakeDb({'members/u1': {name: 'Dan', metal: 'silver', photo: '', medal: 'days-7', streak: 4}});
  const c = createCommunity({db, HttpsError, FieldValue, now: () => 1e12});
  await assert.rejects(c.post({auth: {uid: 'u2'}, data: {text: 'Hello brothers'}}), /Join the brothers/);
  await assert.rejects(c.post({auth: {uid: 'u1'}, data: {text: 'sh1t'}}), /Keep it clean/);
  const {id} = await c.post({auth: {uid: 'u1'}, data: {text: 'Praying for you all.', kind: 'prayer'}});
  const post = db.store.get(`posts/${id}`);
  assert.equal(post.authorName, 'Dan');
  assert.equal(post.authorMetal, 'silver');
  assert.equal(post.kind, 'prayer');
  assert.equal(post.hidden, false);
});

test('three reports hide a post for everyone, and each brother reports once', async () => {
  const db = fakeDb({'posts/p1': {authorId: 'a', authorName: 'A', text: 'x', reports: 0, hidden: false}});
  const c = createCommunity({db, HttpsError, FieldValue, now: () => 1e12});
  await c.report({auth: {uid: 'r1'}, data: {postId: 'p1', reason: 'spam'}});
  await c.report({auth: {uid: 'r1'}, data: {postId: 'p1', reason: 'spam'}});
  assert.equal(db.store.get('posts/p1').reports, 1);
  await c.report({auth: {uid: 'r2'}, data: {postId: 'p1', reason: 'hate'}});
  await c.report({auth: {uid: 'r3'}, data: {postId: 'p1', reason: 'other'}});
  assert.equal(db.store.get('posts/p1').hidden, true);
  await assert.rejects(c.report({auth: {uid: 'r4'}, data: {postId: 'p1', reason: 'nope'}}), /reason/);
});

test('only the author deletes a post, and leaving removes card and posts', async () => {
  const db = fakeDb({
    'members/a': {name: 'A'}, 'posts/p1': {authorId: 'a', text: 'x'}, 'posts/p1/comments/c1': {authorId: 'b'},
    'posts/p2': {authorId: 'b', text: 'y', amenBy: ['a'], amens: 1},
  });
  const c = createCommunity({db, HttpsError, FieldValue, now: () => 1e12});
  await assert.rejects(c.remove({auth: {uid: 'b'}, data: {postId: 'p1'}}), /your own posts/);
  await c.leave({auth: {uid: 'a'}});
  assert.equal(db.store.has('members/a'), false);
  assert.equal(db.store.has('posts/p1'), false);
  assert.equal(db.store.has('posts/p1/comments/c1'), false);
  assert.deepEqual(db.store.get('posts/p2').amenBy, {remove: 'a'});
});
