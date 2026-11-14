'use strict';
const {onCall, onRequest, HttpsError} = require('firebase-functions/v2/https');
const {initializeApp} = require('firebase-admin/app');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');
const {getAuth} = require('firebase-admin/auth');
const {getStorage} = require('firebase-admin/storage');
const {onDocumentUpdated, onDocumentWritten} = require('firebase-functions/v2/firestore');
const {defineSecret} = require('firebase-functions/params');
const {createBilling} = require('./billing');
const {createHandlers} = require('./handlers');
const {createCommunity} = require('./community');
initializeApp();
const community = createCommunity({db: getFirestore(), HttpsError, FieldValue});
const handlers = createHandlers({db: getFirestore(), auth: getAuth(), HttpsError, FieldValue, Timestamp,
  storage: {deleteFiles: options => getStorage().bucket().deleteFiles(options)},
  purgeCommunity: uid => community.purge(uid)});
// Launch-day headroom: each instance serves many concurrent requests.
const options = {region: 'us-central1', invoker: 'public', maxInstances: 40,
  serviceAccount: 'holyhim-runtime@holyhim-app-production.iam.gserviceaccount.com'};
// App Check starts in monitor mode. Set ENFORCE_APP_CHECK=true in
// functions/.env and redeploy once metrics show real traffic passing.
const callable = {...options, enforceAppCheck: process.env.ENFORCE_APP_CHECK === 'true'};

exports.deleteAccount = onCall(callable, handlers.deleteAccount);
exports.supportRequest = onRequest({...options,
  cors: ['https://holyhim-app-production.web.app', 'https://holyhim-app-production.firebaseapp.com'],
  timeoutSeconds: 20,
}, handlers.supportRequest);

const rcKey = defineSecret('REVENUECAT_SECRET_API_KEY');
const webhookSecret = defineSecret('REVENUECAT_WEBHOOK_SECRET');
const billing = createBilling({db: getFirestore(), auth: getAuth(), HttpsError, FieldValue, Timestamp,
  apiKey: () => rcKey.value(), webhookSecret: () => webhookSecret.value()});
exports.getAccessStatus = onCall(callable, billing.getAccessStatus);
exports.syncAccess = onCall({...callable, secrets: [rcKey]}, billing.syncAccess);
exports.revenuecatWebhook = onRequest({...options, secrets: [rcKey, webhookSecret]}, billing.revenuecatWebhook);
const {createAvatarCleanup} = require('./avatar');
const cleanupAvatar = createAvatarCleanup({deleteObject: path => getStorage().bucket().file(path).delete({ignoreNotFound:true})});
exports.cleanupReplacedAvatar = onDocumentUpdated({region: options.region, maxInstances: 3, retry:true, serviceAccount: options.serviceAccount, document: 'users/{uid}'}, event => cleanupAvatar({
  uid:event.params.uid, before:event.data?.before.data()?.avatarUrl, after:event.data?.after.data()?.avatarUrl,
}));

// The brothers: posts, replies and reports pass through moderation here.
exports.communityPost = onCall(callable, community.post);
exports.communityEdit = onCall(callable, community.edit);
exports.communityComment = onCall(callable, community.comment);
exports.communityDelete = onCall(callable, community.remove);
exports.communityReport = onCall(callable, community.report);
exports.communityLeave = onCall(callable, community.leave);
exports.moderateMember = onDocumentWritten({region: options.region, maxInstances: 3, serviceAccount: options.serviceAccount,
  document: 'members/{uid}'}, community.moderateMember);
