# HolyHim free-edition rebuild — development migration

This checkout is an in-progress implementation of the attached full specification. It is not the complete release. On November 1, the compatible free-edition backend functions and Firestore rules were deployed after Node 22 tests, emulator verification, and fresh inventory. Live free enrollment and completion now pass. No backfill was necessary because the pre-rollout inventory had no journeys. No hosted publication, Apple account/product change, App Store upload, submission, or release scheduling was performed.

## Preserved

The 365 original day numbers, titles, message content, and pinned WEB quotations are unchanged. Existing journey start date, timezone, actual activity, and completions remain authoritative. Legacy durable completions still use the compatible `completeLesson` endpoint. The pre-existing archive/IPA and the user's modified `store/VERIFICATION.md` and `store/device-verification.json` have been preserved.

## Access rollout

1. Run existing tests, the five-day content gate, and the independent Scripture verifier.
2. With trusted project Admin credentials, run `node functions/inventory-edition.js` from the project root (or `node inventory-edition.js` from functions). It prints counts only. On October 31, 2026, the read-only inventory succeeded with explicit `GCLOUD_PROJECT=holyhim-app-production`: 0 journeys, 0 legacy entitlement records, 0 retained grants. It performed no writes and did not establish purchase history or a live free-flow test.
3. Review the legacy purchase population. Keep genuine purchase records, RevenueCat configuration, Apple product records, and the webhook unchanged.
4. Deploy compatible backend and owner-only rules before distributing a new app. `getJourney`, `getAccessStatus`, and idempotent `startJourney` lazily grant existing journeys during this free phase. `node functions/inventory-edition.js --backfill` supplies an explicit transactional backfill when authorized for rollout.
5. Verify on a test account with no purchase: server-acknowledged journey → retained edition grant → eligible lesson → completion. Do not infer this live proof from local tests.
6. Only then distribute a verified replacement. Uploaded build 1 still contains a purchase gate and cannot be made free by changing server policy alone.

`FREE_ENROLLMENT_OPEN` is a server constant. Turning it off in a future release must never remove an existing `holyhim365` retained grant. Billing reconciliations write only the separate entitlement record. A free grant has no expiry or billing-event revocation path.

## Schemas and compatibility

- `private/editionAccess`: edition, retained, source, grantedAt. Server writes only.
- `private/journey`: existing fields plus `revision` (legacy documents default to 1).
- `attempts/{attemptId}`: canonical graded result, day/version/revision. Server writes only. Duplicate IDs return the original result.
- `resumes/day-{day}`: semantic step, rendered part, full attempt IDs/order/answers, checkpoint ID, and server-controlled checkpoint revision. Writes require `expectedRevision` compare-and-set; duplicate checkpoint IDs return the existing revision. Completion advances the revision and writes a cleared tombstone. Competing devices resolve at opening: a dirty local checkpoint wins only while its server base remains current; a newer server revision wins otherwise. The active reader stays steady on conflict. Trustworthy local state limits the initial remote wait to 350 ms. Physical/network termination behavior remains to be verified.
- `private/savedCatalog`: bounded 365-day map; server timestamps for saves, null tombstones for removals. `savedOperations/{operationId}` records callable-only receipts, making retries idempotent. Server transaction order resolves competing devices; replaying an older operation returns its receipt without rewriting the current catalog. The client acknowledges the exact operation ID and drains edits added during synchronization. Receipt lifecycle/retention remains an operational review item.
- Profile: optional sounds/tips/largerText; onboarding version 2 and semantic step ID. Legacy seven-step positions map to the ten-step flow.
- SQLite account-scoped local keys (imported lazily from the original UID-scoped preferences): `attempt_outbox`, `saved_lessons`, `lesson_resume_{day}`, `profile_pending`, `profile_finalizing`, and the existing caches/outbox. The legacy completion outbox remains intact and acquires a revision marker.

Reset requires recent authentication and a durable operation ID. `resetOperations/{operationId}` commits the original result with the revision advancement; retries do not perform another reset. Cleanup deletes only obsolete attempts/resumes and can be retried after interruption. The client retains its reset operation until local cleanup succeeds, preserves new-revision attempts, and clears both guided and legacy positions. Reset advances revision before deleting obsolete attempt/resume records. Start date, timezone, calendar availability, saved items, preferences, edition grant, and activity remain. Revision-less build-1 submissions are accepted only for revision 1. After reset, older clients must upgrade rather than repopulate erased progress.

Deletion atomically creates the existing hashed private account marker and a server-owned `deletionGuards/{uid}` marker that rules can evaluate outside the deleted user tree, queues legacy provider cleanup when a legacy entitlement record exists, recursively removes user-owned cloud data, then removes Firebase Auth. The scheduled private worker retries provider cleanup daily. A provider outage never blocks HolyHim deletion. Queue, operation-receipt, and account-marker collections are inaccessible to clients. The local SQLite deletion transaction removes only that account and retains an erase tombstone that blocks delayed writes; legacy preferences are also removed.

## Local persistence and recovery

`holyhim-local-v1.db` uses SQLite schema version 1, account/key primary keys, and synchronous FULL commits. Each missing key is imported in a transaction; the original preferences remain untouched for recovery until account deletion. Failed imports roll back and can retry. Missing keys are recorded explicitly so stale preferences cannot later reappear. Outboxes have independent schema version 2 with legacy readers/migration.

Answers and resume positions share one record. Completion outbox acceptance and resume clearing commit together. Bookmark state, operation IDs, and pending changes share one record. Onboarding profile/draft flags and legacy completion/revision writes use transactions. An unreadable outbox/profile is preserved and blocks edits; unavailable storage is distinguished from ordinary empty state. SQL failure-injection tests establish local rollback, not physical-device termination acceptance.

Attempt queues drain newly added work, retry stable IDs after lost acknowledgments, and preserve permanent rejections for export/support instead of resending indefinitely. Same-revision progress merges monotonically; a higher reset revision clears obsolete progress. A failed progress cache write cannot acknowledge an accepted attempt away. Legacy completions remain separate and never acquire fabricated quiz answers. Versioned exports include account-scoped local records, drafts, and pending work with account checks around asynchronous reads.

## Integration evidence

Four suites in `functions/test/firestore.integration.js` run against the loopback `demo-holyhim` Firestore emulator. They validate real rules and real Admin SDK transactions, including the delayed-profile deletion guard. Callable HTTP/Auth transport and physical devices are still separate gates. See `REBUILD_VERIFICATION.md` for reproduction and exact limits.

## Content completion

`content/teaching.json` is the authored source; `tool/build_teaching.py` emits both the Dart bundle and canonical server JSON. `tool/verify_teaching.py` is an independent full-content gate. Only days 1–5 currently have the new guided format. Do not describe the 730-question requirement as satisfied. The full gate intentionally blocks release.

## Remaining delivery work

Complete days 6–365 and review 720 more questions; finish the matrix's presentation, sharing, roadmap, tutorials, account editor, and sync race gaps; complete the remaining emulator/callable/Auth/deletion scenarios; reconcile production inventory and backfill if necessary; verify the live free flow; finish all state captures and interaction recordings; run VoiceOver/Reduce Motion/Reduce Transparency and performance checks on physical devices; create and verify the final signed distribution artifact. Prepared website/legal/store text is local and must be published only with the corresponding verified app behavior.

`rebuild-acceptance.json` tracks 305 requirements across all 16 gates. `content/editorial-status.json` separately tracks lesson, question, and unit editorial acceptance; automated validation never marks content reviewed. A signed development debug build and iPhone installation now pass; a development-signed AOT build now launches and displays on the iPhone; native login has a reported defect. The verified debug IPA is recorded in REBUILD_VERIFICATION.md. Sustainable build capacity, iPad availability, full native acceptance, all remaining presentation/content work, and the final signed distribution artifact remain open.

## November 1 startup and free-flow repair

Build 3 fixes a Darwin-only initialization error by using `rawQuery` for the result-returning `secure_delete` PRAGMA. The native regression tool reproduces the old failure and validates the fix against the shipped Objective-C driver. Installation preserves local data and the Firebase session; the physical phone now has an initialized, intact database with a signed-in namespace.

The old production `startJourney` returned a purchase-required error to the free client. Compatible functions and matching rules are now deployed. Four real emulator suites, 29 Node 22 tests, 14 live QA flow checks and 11 live callable auth checks pass. The cleanup worker is private, and the existing billing reconciliation/webhook deployment revisions were not changed. Inventory was 0/0 journeys/grants before rollout and 2/2 afterward, with zero legacy entitlement records. No backfill or customer-account reset was performed. `free-rollout-plan.json` and `free-rollout-report.json` under `rebuild-test-results/` record scope and rollback policy; rollback must retain free grants and never restore purchase-required enrollment.

Latest development artifact: `build/ios/development/HolyHim-1.1.0-3-development.ipa`. See `REBUILD_VERIFICATION.md` for its limits. The user confirmed physical Day 1 opening; physical completion acceptance remains separate from the live no-purchase QA verification; all full-catalog/presentation/device release gates still apply.
