# Rebuild verification — November 1, 2026

This is an in-progress development checkpoint, not acceptance of the complete rebuild. Build **1.1.0 (3)** is signed, installed, and launched on the physical iPhone. The native storage initialization defect is corrected. The free backend and compatible rules are now deployed, and live no-purchase enrollment/completion passes. The full 365-lesson guided catalog and the remaining presentation/native acceptance gates remain open.

## Current evidence

| Check | Result | Evidence under `rebuild-test-results/` |
|---|---|---|
| Flutter analysis | Clean | `startup-fix-analyze.txt` |
| Flutter tests | 63 passed | `startup-fix-flutter.txt` |
| Native SQLite driver | Failed before fix; passes afterward using shipped Darwin wrapper | `native-storage-regression-before.txt`, `native-storage-regression.txt` |
| Physical device database | 20 KiB, integrity `ok`, schema 1, 11 records, one signed-in namespace | `startup-fix-device-database.json` |
| Signed app | Build 3 signature, identity, device provisioning verified | `startup-fix-build-verification.json` |
| Backend runtime | 29 tests passed on Node 22.23.4 | `free-backend-node22-tests.txt` |
| Firestore emulator | Four suites passed | `free-rollout-emulator.txt` |
| Live free flow | 14 checks passed on retained journey QA account | `free-flow-live-verification.json` |
| Live transport/rules | All 11 callable authentication guards pass; deployed rules match source | `free-rollout-transport-verification.json` |
| Legacy billing | `syncAccess` and `revenuecatWebhook` deployment revisions unchanged | `free-rollout-functions-before.json`, `free-rollout-functions-after.json` |
| Cleanup worker | Not publicly invokable | `free-rollout-worker-privacy.json` |
| Original corpus | 365 original lessons and pinned WEB quotations preserved | Independent Scripture verifier; checkpoint integrity manifest |
| Content coverage | Five enhanced lessons, ten questions; editorial findings pending revision | `../FIVE_DAY_EDITORIAL_REVIEW.md`, `content/editorial-status.json` |
| Acceptance tracking | 305 requirements, 16 gates, 15 shared states | `tool/verify_acceptance.py`; structure is not release acceptance |

## Google sign-in and startup correction

The reported “couldn't load your saved journey” appeared after Google authentication. The new local SQLite file remained zero bytes because `PRAGMA secure_delete = ON` was sent through `execute`, whose Darwin implementation requires `SQLITE_DONE`. This PRAGMA returns `SQLITE_ROW`; the iOS wrapper rejected it before schema creation. Dart FFI tests did not expose that native-driver difference.

The setting now uses `rawQuery`. `tool/verify_native_storage.py` compiles the actual sqflite Darwin Objective-C driver and runs the application's real configuration calls against it. Before the fix it exited 4 on that exact statement; afterward the configuration and first durable write pass. Build 3 was installed without deleting the database, account, or preferences. The phone's previously empty database initialized correctly, and a signed-in namespace was recovered. The temporary diagnostic copy was removed; no names, account identifiers, credentials, or record values were written to the diagnostic report.

## Free enrollment rollout

The next reported “setup is saved; reconnect and try again” was reproduced against the live `startJourney`: HTTP 403, “Please restore your lifetime purchase.” The new free client was still talking to the old paid enrollment handler.

After Node 22 tests, emulator verification, and a fresh read-only inventory, the compatible free-edition functions and rules were deployed. The exact plan, source hashes, preserved rollback source snapshot, previous function/rule revisions, deployment logs, and outcome are recorded in `free-rollout-plan.json`, `free-rollout-source.zip`, and `free-rollout-report.json`.

The inventory before deployment had **0 journeys, 0 legacy entitlement records, and 0 retained grants**, so no backfill was needed. The recorded post-rollout inventory has **2 journeys and 2 retained grants, with 0 legacy entitlement records**. The QA tool directly modified only the retained journey test account. Counts do not establish Apple purchase history.

Live checks cover free enrollment without purchase ownership, retained access, idempotent start, current onboarding profile writes, anonymous read denial, guided checkpoints, canonical grading with one incorrect answer, duplicate completion, journey read-back, stale checkpoint rejection, owner attempt reads, and bookmark operation receipts/tombstones. All eleven authenticated callables reject anonymous requests. The cleanup worker's private invoker policy and the exact deployed rules were read back. Legacy billing handler revisions remain unchanged.

This does not establish physical completion/resume/sharing/reset/deletion acceptance, production support delivery, Apple/Google/email cancellation variants, or every rollout scenario. The installed app uses the updated backend immediately. The user confirmed that Day 1 opens on the physical iPhone after retrying enrollment. This is recorded in `iphone-day-one-confirmation.json`, separately from the live QA completion test. Physical lesson completion and the full native feature matrix remain unverified.

## Development artifacts and preserved inputs

Latest: `build/ios/development/HolyHim-1.1.0-3-development.ipa`. This is an AOT/release-mode app signed for development with the existing team/profile, so it does not require debugger attachment. Its SHA-256, archive integrity, extracted signature and identity checks are recorded in `startup-fix-artifact.json`. It is not the final accepted distribution delivery.

Build 2's debug app/IPA and development-signed AOT app/IPA remain preserved separately. Initial debug attachment attempts stalled; no debugger-authority setting was changed. A removed Flutter temporary helper workspace caused an Xcode warning; that stale window was closed and the intact permanent `ios/Runner.xcworkspace` reopened. No source was lost.

The pre-edit source checkpoint is `/Users/amir/Downloads/HolyHim-checkpoint-20261031-202900/`. Original archive/IPA, signing/project configuration, supplied artwork, original curriculum, `store/VERIFICATION.md`, and `store/device-verification.json` remain preserved. `tool/verify_checkpoint.py` verifies the recorded working tree, preserved native artifacts, reference repository, dependency locks, and pre-edit archive. No checkpoint commit/index mutation was made.

A requested cleanup reclaimed approximately 10.3 GiB by removing outdated iOS 27.0 device symbols and regenerable compiler/npm/editor installer caches. Current iOS 27.2 support, installed dependencies/extensions, simulators, personal files, and app/source artifacts were kept. Native build retries no longer lack disk capacity; some compiler caches naturally regenerate. See `disk-cleanup.json`.

## Remaining release gates

Days 6–365 still need authoring and review; the first five need revisions and acceptance. All 73 units need finished summaries and acceptance. The 21-render gallery remains partial, and Cognein presentation parity, recordings, accessibility/performance, iPad testing, full native provider flows, account/data management, production support delivery, and final distribution verification remain outstanding.

The physical iPad is unavailable. No App Store upload/submission/scheduling, Apple account/product changes, or hosted website publication was performed in this work. Uploaded build 1 still has its original client purchase gate. Full content and acceptance verifiers intentionally block release.

## Reproduce the relevant checks

```sh
flutter analyze
flutter test --reporter expanded
python3 tool/verify_native_storage.py
npm --prefix functions test
python3 tool/build_teaching.py --check
python3 tool/verify_teaching.py --slice
python3 tool/build_legal.py --check
python3 tool/verify_acceptance.py
JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home PATH=/opt/homebrew/opt/openjdk@21/bin:$PATH firebase emulators:exec --config firebase.emulators.json --only firestore --project demo-holyhim 'node --test functions/test/firestore.integration.js'
```

`tool/verify_free_flow_live.py --run-qa-flow` intentionally creates real QA attempt activity on the recognized retained journey account; it is not a read-only command. It never resets/deletes an account or writes purchase ownership. Native storage verification requires macOS/Xcode. Emulator verification refuses a non-loopback host or non-demo project.
