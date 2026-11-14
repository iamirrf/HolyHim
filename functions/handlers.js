'use strict';
const crypto = require('node:crypto');

// Injection keeps these handlers verifiable without network credentials.
function createHandlers({db, auth, HttpsError, FieldValue, Timestamp, storage, purgeCommunity, now = Date.now}) {
  function requireIdentity(request) {
    if (!request.auth || typeof request.auth.uid !== 'string' || !request.auth.uid) {
      throw new HttpsError('unauthenticated', 'Please sign in.');
    }
    return request.auth.uid;
  }
  async function deleteAccount(request) {
    const uid = requireIdentity(request);
    const authenticatedAt = request.auth.token?.auth_time;
    if (!Number.isFinite(authenticatedAt) || now() / 1000 - authenticatedAt > 300 || authenticatedAt > now() / 1000 + 60) {
      throw new HttpsError('unauthenticated', 'Please sign in again to continue.');
    }
    // This guard survives deletion and rejects another device's offline writes.
    await db.doc(`deletionGuards/${uid}`).set({deleting: true, createdAt: FieldValue.serverTimestamp()});
    if (storage) await storage.deleteFiles({prefix: `users/${uid}/avatars/`});
    // Posts, replies, Amens and the public card go with the account.
    if (purgeCommunity) await purgeCommunity(uid);
    await db.recursiveDelete(db.doc(`users/${uid}`));
    try {
      await auth.deleteUser(uid);
    } catch (error) {
      if (error.code !== 'auth/user-not-found') throw error;
    }
    return {deleted: true};
  }
  async function supportRequest(req, res) {
    if (req.method !== 'POST') {
      res.status(405).json({error: 'Please send the support form.'});
      return;
    }
    const {email, message, website, purpose = 'support', appVersion} = req.body || {};
    if (!['support', 'feedback'].includes(purpose) || (appVersion != null && (typeof appVersion !== 'string' || appVersion.length > 80))) {
      res.status(400).json({error: 'Please choose support or feedback.'});
      return;
    }
    if (website) {
      res.status(200).json({received: true});
      return;
    }
    if (typeof email !== 'string' || email.length > 254 || !/^\S+@\S+\.\S+$/.test(email) || typeof message !== 'string' || message.trim().length < 10 || message.length > 5000) {
      res.status(400).json({error: 'Please enter your email and a message between 10 and 5,000 characters.'});
      return;
    }
    const hour = Math.floor(now() / 3600000);
    const rateId = crypto.createHash('sha256').update(`${req.ip}|${hour}|holyhim-support`).digest('hex');
    try {
      await db.runTransaction(async tx => {
        const rate = db.doc(`supportRateLimits/${rateId}`);
        const old = (await tx.get(rate)).data();
        if ((old?.count || 0) >= 3) throw new Error('rate');
        tx.set(rate, {count: (old?.count || 0) + 1, expiresAt: Timestamp.fromMillis(now() + 86400000)});
        tx.create(db.collection('supportRequests').doc(), {
          email: email.trim(), message: message.trim(), purpose,
          ...(appVersion ? {appVersion} : {}), createdAt: FieldValue.serverTimestamp(), status: 'new',
        });
      });
      res.status(200).json({received: true});
    } catch (error) {
      res.status(error.message === 'rate' ? 429 : 503).json({
        error: error.message === 'rate' ? 'Please wait a little before sending another message.' : 'Your message could not be sent. Please try again shortly.',
      });
    }
  }
  return {deleteAccount, supportRequest};
}
module.exports = {createHandlers};
