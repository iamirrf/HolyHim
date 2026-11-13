'use strict';
const crypto = require('node:crypto');
const PROJECT = 'REPLACE_WITH_HOLYHIM_REVENUECAT_PROJECT';
const ENTITLEMENT = 'REPLACE_WITH_HOLYHIM_REVENUECAT_ENTITLEMENT';
function lifetimeActive(body, now = Date.now()) {
  if (body?.object !== 'list' || !Array.isArray(body.items)) throw new TypeError('Invalid entitlement response');
  return body.items.some(item => item?.entitlement_id === ENTITLEMENT &&
    (item.expires_at === null || (Number.isSafeInteger(item.expires_at) && item.expires_at > now)));
}
function customerIds(event) {
  const fields = ['aliases', 'transferred_from', 'transferred_to'];
  if (fields.some(field => event[field] != null && !Array.isArray(event[field]))) throw new TypeError('Invalid identities');
  return [...new Set([event.app_user_id, event.original_app_user_id, ...fields.flatMap(field => event[field] || [])]
    .filter(id => typeof id === 'string' && id.length > 0 && id.length <= 128 && !id.includes('/') && !id.startsWith('$RCAnonymousID:')))];
}
function createBilling({db, auth, HttpsError, FieldValue, Timestamp, apiKey, webhookSecret,
    fetcher = fetch, now = Date.now}) {
  const identity = request => {
    if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Please sign in.');
    return request.auth.uid;
  };
  const privateDoc = (uid, name) => db.doc(`users/${uid}/private/${name}`);
  async function getAccessStatus(request) {
    const uid = identity(request);
    const [grant, purchase, guard] = await Promise.all([
      privateDoc(uid, 'editionAccess').get(), privateDoc(uid, 'entitlement').get(), db.doc(`deletionGuards/${uid}`).get(),
    ]);
    if (guard.data()?.deleting === true) throw new HttpsError('permission-denied', 'Account deletion is in progress.');
    const retained = grant.data()?.edition === 'holyhim365' && grant.data()?.retained === true;
    const purchased = purchase.data()?.active === true;
    return {edition: 'holyhim365', retained, retainedGrant: retained, genuinePurchase: purchased, eligible: retained || purchased};
  }
  async function reconcile(uid) {
    try { await auth.getUser(uid); }
    catch (error) { if (error.code === 'auth/user-not-found') return false; throw error; }
    const guard = db.doc(`deletionGuards/${uid}`), ref = privateDoc(uid, 'entitlement');
    const revision = crypto.randomUUID();
    const reserved = await db.runTransaction(async tx => {
      if ((await tx.get(guard)).data()?.deleting === true) return false;
      tx.set(ref, {reconciliation: revision}, {merge: true}); return true;
    });
    if (!reserved) return false;
    const endpoint = `https://api.revenuecat.com/v2/projects/${PROJECT}/customers/${encodeURIComponent(uid)}/active_entitlements`;
    let next = endpoint + '?limit=100'; const items = [];
    try {
      for (let page = 0; page < 20; page++) {
        const response = await fetcher(next, {headers: {Authorization: `Bearer ${apiKey()}`}, signal: AbortSignal.timeout(12000)});
        if (response.status === 404 && page === 0) break;
        if (!response.ok) throw new Error('Store unavailable');
        const body = await response.json();
        if (body.object !== 'list' || !Array.isArray(body.items)) throw new Error('Invalid response');
        items.push(...body.items);
        if (!body.next_page) { next = null; break; }
        const url = new URL(body.next_page, endpoint);
        if (url.origin !== 'https://api.revenuecat.com' || url.pathname !== new URL(endpoint).pathname) throw new Error('Invalid pagination');
        next = url.href;
        if (page === 19) throw new Error('Pagination limit');
      }
    } catch (_) { throw new HttpsError('unavailable', 'We could not confirm your purchase. Please try Restore Purchases shortly.'); }
    const active = lifetimeActive({object: 'list', items}, now());
    return db.runTransaction(async tx => {
      const [account, current] = await Promise.all([tx.get(guard), tx.get(ref)]);
      if (account.data()?.deleting === true) return false;
      if (current.data()?.reconciliation !== revision) return current.data()?.active === true;
      tx.set(ref, {active, type: 'lifetime', updatedAt: FieldValue.serverTimestamp()}, {merge: true});
      // A refund changes verified ownership, never a retained free-edition grant.
      return active;
    });
  }
  async function syncAccess(request) { return {active: await reconcile(identity(request))}; }
  async function revenuecatWebhook(req, res) {
    const expected = Buffer.from(`Bearer ${webhookSecret()}`), actual = Buffer.from(req.get('authorization') || '');
    if (req.method !== 'POST' || expected.length !== actual.length || !crypto.timingSafeEqual(expected, actual)) {
      res.status(401).send('Unauthorized'); return;
    }
    const event = req.body?.event;
    if (typeof event?.id !== 'string' || event.id.length < 1 || event.id.length > 150) { res.status(400).send('Invalid event'); return; }
    const record = db.doc(`billingEvents/${crypto.createHash('sha256').update(event.id).digest('hex')}`);
    if ((await record.get()).exists) { res.status(200).send('Already handled'); return; }
    let ids; try { ids = customerIds(event); } catch (_) { res.status(400).send('Invalid identities'); return; }
    try {
      for (const uid of ids) await reconcile(uid);
      await record.set({processedAt: FieldValue.serverTimestamp(), expiresAt: Timestamp.fromMillis(now() + 30 * 86400000)});
      res.status(200).send('OK');
    } catch (_) { res.status(503).send('Please retry'); }
  }
  return {getAccessStatus, syncAccess, revenuecatWebhook};
}
module.exports = {createBilling, lifetimeActive, customerIds};
