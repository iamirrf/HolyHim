> **Deployed and verified November 5, 2026, after explicit user approval.** All six named functions are ACTIVE. Deployed rule sources match the prepared files. All previous function endpoints remain. Fifteen live checks passed using a disposable account, including avatar replacement/removal and full account/photo deletion. The QA account was deleted. See `deployment-verification.json` and `live-backend.json`.
>
> Setup completed the default `holyhim-app-production.firebasestorage.app` bucket in US-CENTRAL1, the Storage service agent’s Firestore Rules role, runtime access to avatar objects, Eventarc receipt, and invocation restricted to the runtime service account on the cleanup service. Hosting and hard-paywall activation remain unchanged.

# Backend deployment record

The following section records the prepared scope before approval. Production now uses these compatible rules and named functions. The read-only audit found the deployed v4 rules incompatible with the current profile and `/walk` payloads. Local persistence protects UI state, but successful live synchronization cannot be claimed until the compatible backend is deployed and tested on an account.

Prepared files:

- `firestore.rules`: compatible legacy and schema 5/6 profile shapes; birthday, username, avatar and bounded onboarding fields; `/walk/progress` and `/walk/saved`; owner-only legacy/access reads; no client entitlement writes; deletion guard protection.
- `storage.rules`: owner-only JPEG avatars below 2 MiB, constrained paths, deletion-guard checks and owner removal.
- `functions/handlers.js`: account deletion removes uploaded avatars before deleting account records and authentication.
- `functions/billing.js`: authenticated retained-access reads, server-verified RevenueCat lifetime reconciliation, guarded/idempotent webhook processing and retained-grant preservation.
- `functions/avatar.js`: owner/path-constrained cleanup of replaced or removed photos. The trigger retries transient deletion failures.
- `functions/index.js`: exports the compatible account/support handlers, billing endpoints and photo-cleanup trigger. Existing function removals are not authorized by this plan.

Local demo-only Firestore/Storage and function suite: 25 tests passing. No production project is accepted by the emulator test guards.

Proposed approved deployment scope is Firestore rules, Storage rules and these named functions: `deleteAccount`, `supportRequest`, `getAccessStatus`, `syncAccess`, `revenuecatWebhook`, `cleanupReplacedAvatar`. Use an explicit functions list; do not use a blanket deployment that could delete legacy functions. Firestore indexes and Hosting are outside this proposed action.

Before live verification, confirm the existing RevenueCat secret bindings, function service-account access to the avatar bucket, and the Storage Rules service agent's Firestore access for cross-service deletion-guard checks. Configure/verify the RevenueCat webhook URL and authorization against the deployed endpoint; do not expose secret values in logs or repository files. Preserve existing retained grants and purchase records.

After approval/deployment: verify authenticated profile create/edit/ack/retry, draft rewinding, offline restart, progress/save merge, photo replacement/removal/deletion, access ownership/restore and webhook behavior. Keep `HOLYHIM_TESTING_PAYWALL_EXIT` enabled. Sandbox StoreKit purchase/restore remains a separate real-device verification step.

The project AGENTS.md states: “Do not push, deploy Firebase, or upload to the App Store without the user’s explicit approval.” Implementation authorization does not authorize this deployment.
