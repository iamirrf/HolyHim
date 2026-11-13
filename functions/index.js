'use strict';
const {onCall, onRequest, HttpsError} = require('firebase-functions/v2/https');
const {initializeApp} = require('firebase-admin/app');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');
const {getAuth} = require('firebase-admin/auth');
const {getStorage} = require('firebase-admin/storage');
const {onDocumentUpdated} = require('firebase-functions/v2/firestore');
const {defineSecret} = require('firebase-functions/params');
const {createBilling} = require('./billing');
const {createHandlers} = require('./handlers');
initializeApp();
const handlers = createHandlers({db: getFirestore(), auth: getAuth(), HttpsError, FieldValue, Timestamp, storage: {deleteFiles: options => getStorage().bucket().deleteFiles(options)}});
const options = {region: 'us-central1', invoker: 'public', maxInstances: 3,
  serviceAccount: 'holyhim-runtime@holyhim-app-production.iam.gserviceaccount.com'};

exports.deleteAccount = onCall(options, handlers.deleteAccount);
exports.supportRequest = onRequest({...options,
  cors: ['https://holyhim-app-production.web.app', 'https://holyhim-app-production.firebaseapp.com'],
  timeoutSeconds: 20,
}, handlers.supportRequest);

const rcKey = defineSecret('REVENUECAT_SECRET_API_KEY');
const webhookSecret = defineSecret('REVENUECAT_WEBHOOK_SECRET');
const billing = createBilling({db: getFirestore(), auth: getAuth(), HttpsError, FieldValue, Timestamp,
  apiKey: () => rcKey.value(), webhookSecret: () => webhookSecret.value()});
exports.getAccessStatus = onCall(options, billing.getAccessStatus);
exports.syncAccess = onCall({...options, secrets: [rcKey]}, billing.syncAccess);
exports.revenuecatWebhook = onRequest({...options, secrets: [rcKey, webhookSecret]}, billing.revenuecatWebhook);
const {createAvatarCleanup} = require('./avatar');
const cleanupAvatar = createAvatarCleanup({deleteObject: path => getStorage().bucket().file(path).delete({ignoreNotFound:true})});
exports.cleanupReplacedAvatar = onDocumentUpdated({region: options.region, maxInstances: 3, retry:true, serviceAccount: options.serviceAccount, document: 'users/{uid}'}, event => cleanupAvatar({
  uid:event.params.uid, before:event.data?.before.data()?.avatarUrl, after:event.data?.after.data()?.avatarUrl,
}));
