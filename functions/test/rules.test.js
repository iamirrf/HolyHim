'use strict';
// A demo-only REST rules client: never accepts a production project or host.
const {test} = require('node:test');
const assert = require('node:assert/strict');
const project = 'demo-holyhim';
const host = process.env.FIRESTORE_EMULATOR_HOST;
const enabled = Boolean(host);
if (enabled && (!/^127\.0\.0\.1:\d+$/.test(host) || process.env.GCLOUD_PROJECT !== project)) {
  throw new Error('Rules tests require a local emulator and --project demo-holyhim.');
}
const base = `http://${host}/v1/projects/${project}/databases/(default)/documents`;
function token(uid) {
  const now = Math.floor(Date.now() / 1000);
  const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  return `${encode({alg: 'none', typ: 'JWT'})}.${encode({iss: `https://securetoken.google.com/${project}`, aud: project, sub: uid, user_id: uid, iat: now, exp: now + 3600, auth_time: now, firebase: {sign_in_provider: 'custom'}})}.`;
}
function field(value) {
  if (value instanceof Date) return {timestampValue: value.toISOString()};
  if (value === null) return {nullValue: null};
  if (Array.isArray(value)) return {arrayValue: {values: value.map(field)}};
  if (typeof value === 'object') return {mapValue: {fields: fields(value)}};
  if (typeof value === 'boolean') return {booleanValue: value};
  if (typeof value === 'number') return Number.isInteger(value) ? {integerValue: String(value)} : {doubleValue: value};
  return {stringValue: value};
}
function fields(data) { return Object.fromEntries(Object.entries(data).map(([key, value]) => [key, field(value)])); }
async function request(path, {uid, admin = false, data, method = data ? 'PATCH' : 'GET', mask = []} = {}) {
  const query = new URLSearchParams();
  for (const key of mask) query.append('updateMask.fieldPaths', key);
  const response = await fetch(`${base}/${path}${query.size ? `?${query}` : ''}`, {
    method, headers: {'Content-Type': 'application/json', ...(admin || uid ? {Authorization: `Bearer ${admin ? 'owner' : token(uid)}`} : {})},
    ...(data ? {body: JSON.stringify({fields: fields(data)})} : {}),
  });
  return {status: response.status, body: await response.json()};
}
const stamp = new Date('2026-11-03T12:00:00Z');
const profile = {schema: 5, name: 'Alice', hearts: ['Peace', 'Rest'], reminder: {enabled: true, minutes: 420}, theme: 'blush', readingScale: 1, haptics: true, sounds: true, promise: {startedAt: stamp}, timeZone: 'America/New_York', onboardedAt: stamp, createdAt: stamp, updatedAt: stamp};
const rulesTest = (name, fn) => test(name, {skip: !enabled}, fn);

rulesTest('v5 profile accepts exact client payload, field merges and future theme strings', async () => {
  assert.equal((await request('users/profile-reader', {uid: 'profile-reader', data: profile})).status, 200);
  assert.equal((await request('users/profile-reader', {uid: 'profile-reader', data: {theme: 'future-theme', updatedAt: stamp}, mask: ['theme', 'updatedAt']})).status, 200);
  assert.equal((await request('users/profile-reader', {uid: 'profile-reader'})).status, 200);
  assert.equal((await request('users/new-reader', {uid: 'new-reader', data: {...profile, name: '', hearts: [], promise: {startedAt: null}, onboardedAt: null}})).status, 200);
  assert.equal((await request('users/profile-reader', {uid: 'profile-reader', data: {...profile, migratedAt: stamp}})).status, 200);
});

rulesTest('profile rejects wrong owner, anonymous, extra keys, invalid types and oversize fields', async () => {
  assert.equal((await request('users/profile-reader', {uid: 'other'})).status, 403);
  assert.equal((await request('users/profile-reader')).status, 403);
  assert.equal((await request('users/profile-reader', {uid: 'other', data: profile})).status, 403);
  for (const change of [{schema: 4}, {name: 'x'.repeat(81)}, {hearts: ['a', 'b', 'c', 'd']}, {hearts: ['x'.repeat(21)]}, {hearts: [1]}, {reminder: {enabled: 'yes', minutes: 420}}, {reminder: {enabled: true, minutes: 1440}}, {theme: 'x'.repeat(41)}, {readingScale: 2.01}, {readingScale: 0.99}, {haptics: 'yes'}, {createdAt: '2026-11-03'}, {promise: {startedAt: 'today'}}, {admin: true}]) {
    assert.equal((await request('users/profile-reader', {uid: 'profile-reader', data: {...profile, ...change}})).status, 403, JSON.stringify(change));
  }
  assert.equal((await request('users/profile-reader', {uid: 'profile-reader', method: 'DELETE'})).status, 403);
});

rulesTest('engine profile fields validate, and there is no Circle to read or write', async () => {
  // The shared engine saves these three fields with every profile; HolyHim
  // accepts them only well formed. Brothers keeps its own block list.
  assert.equal((await request('users/circle-reader', {uid: 'circle-reader', data: {...profile, circle: false, circleAvatar: '', blocked: []}})).status, 200);
  for (const change of [{circle: 'yes'}, {circleAvatar: '../x'}, {circleAvatar: 'A'}, {blocked: 'someone'}, {blocked: Array.from({length: 201}, (_, i) => `u${i}`)}]) {
    assert.equal((await request('users/circle-reader', {uid: 'circle-reader', data: {...profile, ...change}})).status, 403, JSON.stringify(change));
  }
  assert.equal((await request('circle/circle-reader', {uid: 'circle-reader', data: {name: 'Me', walk: 999}})).status, 403);
  assert.equal((await request('circle/anyone', {uid: 'circle-reader'})).status, 403);
  assert.equal((await request('circle/anyone')).status, 403);
  assert.equal((await request('circle/anyone/amens/x', {uid: 'circle-reader'})).status, 403);
  assert.equal((await request('circleReports/x', {uid: 'circle-reader', data: {reason: 'spam'}})).status, 403);
  assert.equal((await request('circleSuspended/circle-reader', {uid: 'circle-reader'})).status, 403);
});

rulesTest('completion map accepts all 365 days and merges remain valid at end of journey', async () => {
  const completed = Object.fromEntries(Array.from({length: 365}, (_, i) => [i + 1, '2026-11-03']));
  assert.equal((await request('users/full-reader/walk/progress', {uid: 'full-reader', data: {completed}})).status, 200);
  assert.equal((await request('users/full-reader/walk/progress', {uid: 'full-reader', data: {completed: {'365': '2026-11-04'}}, mask: ['completed.`365`']})).status, 200);
  assert.equal((await request('users/empty-reader/walk/progress', {uid: 'empty-reader', data: {completed: {}}})).status, 200);
});

rulesTest('completion map rejects invalid keys, dates, non-string values and delimiter attacks', async () => {
  const invalidMaps = [{'0': '2026-11-03'}, {'366': '2026-11-03'}, {'01': '2026-11-03'}, {'1': 20261103}, {'1': null}, {'1': true}, {'1': ['2026-11-03']}, {'1': {date: '2026-11-03'}}, {'1': '2026-13-03'}, {'1': '2026-11-00'}, {'1': '2026-1-3'}, {'1': '2026-11-03|2026-11-03'}, {'1': '2026-11-03|2026-11-03', '2': ''}];
  for (const completed of invalidMaps) {
    assert.equal((await request('users/invalid-reader/walk/progress', {uid: 'invalid-reader', data: {completed}})).status, 403, JSON.stringify(completed));
  }
  assert.equal((await request('users/full-reader/walk/progress', {uid: 'other', data: {completed: {'1': '2026-11-03'}}})).status, 403);
  assert.equal((await request('users/full-reader/walk/progress')).status, 403);
  assert.equal((await request('users/extra-reader/walk/progress', {uid: 'extra-reader', data: {completed: {}, extra: true}})).status, 403);
});

rulesTest('saved maps migrate in fixed day blocks and support single-field add/remove across all 365 days', async () => {
  const path = 'users/saved-reader/walk/saved', uid = 'saved-reader';
  assert.equal((await request(path, {uid, data: {verses: {}}})).status, 200);
  for (let start = 1; start <= 365; start += 20) {
    const verses = Object.fromEntries(Array.from({length: Math.min(20, 366 - start)}, (_, i) => [start + i, stamp]));
    const mask = Object.keys(verses).map(day => `verses.\`${day}\``);
    assert.equal((await request(path, {uid, data: {verses}, mask})).status, 200, `block ${start}`);
  }
  assert.equal((await request(path, {uid, data: {verses: {'365': new Date('2026-11-04T00:00:00Z')}}, mask: ['verses.`365`']})).status, 200);
  assert.equal((await request(path, {uid, data: {verses: {}}, mask: ['verses.`365`']})).status, 200);
  const result = await request(path, {uid});
  assert.equal(Object.keys(result.body.fields.verses.mapValue.fields).length, 364);
});

rulesTest('saved maps reject invalid member types, keys, extra fields and writes spanning blocks', async () => {
  for (const verses of [{'0': stamp}, {'366': stamp}, {'01': stamp}, {'1': '2026-11-03'}, {'1': null}, {'1': 12}, {'1': {}}, {'1': []}, {'1': stamp, '21': stamp}]) {
    assert.equal((await request('users/bad-saved/walk/saved', {uid: 'bad-saved', data: {verses}})).status, 403);
  }
  assert.equal((await request('users/saved-reader/walk/saved', {uid: 'other'})).status, 403);
  assert.equal((await request('users/saved-reader/walk/saved', {uid: 'other', data: {verses: {}}})).status, 403);
  assert.equal((await request('users/bad-saved/walk/saved', {uid: 'bad-saved', data: {verses: {}, extra: true}})).status, 403);
});

rulesTest('migration and retained access can read owner-only legacy records without allowing client writes', async () => {
  for (const name of ['journey', 'savedCatalog', 'editionAccess', 'entitlement']) {
    const path = `users/legacy-reader/private/${name}`;
    assert.equal((await request(path, {admin: true, data: {value: 'legacy'}})).status, 200);
    assert.equal((await request(path, {uid: 'legacy-reader'})).status, 200);
    assert.equal((await request(path, {uid: 'other'})).status, 403);
    assert.equal((await request(path, {uid: 'legacy-reader', data: {value: 'changed'}})).status, 403);
  }
  for (const path of ['private/unknown', 'walk/unrecognized']) {
    assert.equal((await request(`users/legacy-reader/${path}`, {uid: 'legacy-reader'})).status, 403);
  }
});

rulesTest('permanent deletion guard rejects profile, progress and saved recreation', async () => {
  const uid = 'deleted-reader';
  assert.equal((await request(`deletionGuards/${uid}`, {admin: true, data: {deleting: true}})).status, 200);
  for (const [suffix, data] of [['', profile], ['/walk/progress', {completed: {'1': '2026-11-03'}}], ['/walk/saved', {verses: {'1': stamp}}]]) {
    assert.equal((await request(`users/${uid}${suffix}`, {uid, data})).status, 403);
  }
  assert.equal((await request(`deletionGuards/${uid}`, {uid})).status, 403);
  assert.equal((await request(`deletionGuards/${uid}`, {uid, data: {deleting: false}})).status, 403);
});

rulesTest('v6 onboarding/profile edits and legacy migration preserve owner access without client entitlements', async () => {
  const uid='redesign-reader';
  const v6={...profile,schema:6,username:'Mira',birthday:'1995-06-15',avatarUrl:null,
    onboardingDraft:{step:8,firstName:'Mira',lastName:'Rose',lifeSeason:'A time of change',faithRoutine:'I’m new to Scripture',source:'The App Store',familiarity:'Some passages are familiar',needs:'Finding peace',pace:'One minute',reminder:'No reminders',intention:'A steady moment of prayer',termsAccepted:true}};
  const nextFlow={...v6,onboardingDraft:{...v6.onboardingDraft,step:4,stepId:'guideObstacle',flowVersion:2,obstacle:'My days are full'}};
  assert.equal((await request('users/redesign-reader',{uid:'redesign-reader',data:nextFlow})).status,200);
  for(const invalid of [{stepId:'unknown'},{flowVersion:99},{obstacle:'made up'}]) {
    assert.equal((await request('users/redesign-reader',{uid:'redesign-reader',data:{...nextFlow,onboardingDraft:{...nextFlow.onboardingDraft,...invalid}}})).status,403);
  }
  assert.equal((await request(`users/${uid}`,{uid,data:v6})).status,200);
  assert.equal((await request(`users/${uid}`,{uid,data:{name:'Amelia',updatedAt:stamp},mask:['name','updatedAt']})).status,200);
  for(const patch of [{lifetime:true},{onboardingDraft:{step:11}},{onboardingDraft:{firstName:'x'.repeat(81)}},{onboardingDraft:{source:123}},{birthday:'not-a-date'},{avatarUrl:'http://evil.example/photo.jpg'}]){
    assert.equal((await request(`users/${uid}`,{uid,data:{...v6,...patch}})).status,403);
  }
  assert.equal((await request(`users/${uid}`,{uid,data:{avatarUrl:'',updatedAt:stamp},mask:['avatarUrl','updatedAt']})).status,200);
  assert.equal((await request(`users/${uid}`,{uid,data:{onboardingDraft:{step:4,source:'A friend or family member'},updatedAt:stamp},mask:['onboardingDraft','updatedAt']})).status,200);
  const cleared=await request(`users/${uid}`,{uid});
  assert.equal(cleared.body.fields.onboardingDraft.mapValue.fields.needs,undefined);
  // Version 3 onboarding stores stable IDs; older drafts above stay valid.
  const v3={...v6,hearts:['peace','hope'],onboardingDraft:{step:5,stepId:'reminder',flowVersion:3,firstName:'Mira',lifeSeason:'change',familiarity:'returning',obstacle:'understanding',reminder:'07:00'}};
  assert.equal((await request(`users/${uid}`,{uid,data:v3})).status,200);
  for(const stepId of ['heart','season','familiarity','obstacle','reminder','birthday','building','letter','offer','complete']){
    assert.equal((await request(`users/${uid}`,{uid,data:{...v3,onboardingDraft:{...v3.onboardingDraft,stepId}}})).status,200,stepId);
  }
  for(const invalid of [{flowVersion:4},{stepId:'paywall'},{obstacle:'tired'},{reminder:'x'.repeat(121)},{unexpected:true}]){
    assert.equal((await request(`users/${uid}`,{uid,data:{...v3,onboardingDraft:{...v3.onboardingDraft,...invalid}}})).status,403,JSON.stringify(invalid));
  }
  const legacy={name:'Legacy',familiarity:'returning',focus:'peace',obstacle:'busy',reminderMinutes:null,onboardingComplete:true,haptics:true,onboardingStep:3,onboardingVersion:4};
  const old='legacy-redesign-reader';
  assert.equal((await request(`users/${old}`,{uid:old,data:legacy})).status,200);
  assert.equal((await request(`users/${old}`,{uid:old,data:{...legacy,...v6}})).status,200);
  await request(`users/${uid}/private/editionAccess`,{admin:true,data:{edition:'holyhim365',retained:true}});
  assert.equal((await request(`users/${uid}/private/editionAccess`,{uid})).status,200);
  assert.equal((await request(`users/${uid}/private/editionAccess`,{uid,data:{edition:'holyhim365',retained:true}})).status,403);
});

rulesTest('brothers: own card only, Amen toggles only, posts server-written, block list private', async () => {
  const card = {name: 'Daniel', metal: 'brass', photo: '', streak: 3, best: 5, days: 9, medal: 'days-7', agreedAt: stamp, joinedAt: stamp, updatedAt: stamp};
  assert.equal((await request('members/bro-a', {uid: 'bro-a', data: card})).status, 200);
  assert.equal((await request('members/bro-a', {uid: 'bro-b', data: card})).status, 403);
  for (const bad of [{name: 'D'}, {name: 'x'.repeat(25)}, {metal: 'gold'}, {streak: 9}, {days: -1}, {medal: 'admin'},
    {photo: 'https://evil.example/x.jpg'}, {verified: true}]) {
    assert.equal((await request('members/bro-a', {uid: 'bro-a', data: {...card, ...bad}})).status, 403, JSON.stringify(bad));
  }
  assert.equal((await request('members/bro-a', {uid: 'bro-a', data: {...card, joinedAt: new Date('2020-01-01T00:00:00Z')}})).status, 403);
  assert.equal((await request('members/bro-a', {uid: 'bro-a', data: {streak: 4, best: 5, updatedAt: stamp}, mask: ['streak', 'best', 'updatedAt']})).status, 200);
  assert.equal((await request('members/bro-a', {uid: 'bro-c'})).status, 200);
  assert.equal((await request('members/bro-a', {})).status, 403);
  await request('bans/bro-banned', {admin: true, data: {reason: 'test'}});
  assert.equal((await request('members/bro-banned', {uid: 'bro-banned', data: card})).status, 403);

  const post = {authorId: 'bro-z', authorName: 'Z', text: 'Pray for me', kind: 'prayer', amens: 0, amenBy: [], comments: 0, reports: 0, hidden: false, createdAt: stamp};
  assert.equal((await request('posts/p-new', {uid: 'bro-a', data: post})).status, 403);
  await request('posts/p1', {admin: true, data: post});
  assert.equal((await request('posts/p1', {uid: 'bro-a', data: {amens: 1, amenBy: ['bro-a']}, mask: ['amens', 'amenBy']})).status, 200);
  assert.equal((await request('posts/p1', {uid: 'bro-a', data: {amens: 3, amenBy: ['bro-a', 'bro-x']}, mask: ['amens', 'amenBy']})).status, 403);
  assert.equal((await request('posts/p1', {uid: 'bro-a', data: {text: 'hacked'}, mask: ['text']})).status, 403);
  assert.equal((await request('posts/p1', {uid: 'bro-a', data: {amens: 0, amenBy: []}, mask: ['amens', 'amenBy']})).status, 200);
  assert.equal((await request('posts/p1', {uid: 'not-a-member', data: {amens: 1, amenBy: ['not-a-member']}, mask: ['amens', 'amenBy']})).status, 403);
  assert.equal((await request('posts/p1', {uid: 'bro-a', method: 'DELETE'})).status, 403);

  assert.equal((await request('users/bro-a/social/hidden', {uid: 'bro-a', data: {users: ['bro-z'], posts: ['p1']}})).status, 200);
  assert.equal((await request('users/bro-a/social/hidden', {uid: 'bro-b'})).status, 403);
  assert.equal((await request('users/bro-a/social/other', {uid: 'bro-a', data: {users: []}})).status, 403);
  assert.equal((await request('reports/r1', {uid: 'bro-a', data: {reason: 'spam'}})).status, 403);
});
