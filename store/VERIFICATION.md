# HolyHer verification record

Status recorded October 30, 2026 for the expanded 365-lesson app. Apple accepted version 1.0.0 (1) and began processing it. This separates observed automated/native/upload results from acceptance still open. No App Review submission, approval, or scheduled public release is claimed.

## Recorded passing checks

| Check | Result and practical limit |
|---|---|
| Flutter suite | **53 tests passed, including the store capture.** The suite exercises controlled services/providers; it does not prove live Apple/Firebase configuration. |
| Flutter analyzer | **No issues found** in the latest coordinated analysis. |
| Backend domain suite | **17 tests passed.** Node tests and controlled function-handler checks cover calendar unlocking, completion validation/merging, entitlement interpretation, billing identity handling, and reconciliation/deletion races. They do not replace deployed-function acceptance. |
| Scripture verifier | **365 lessons and 371 distinct quoted verses verified.** All 38,058 cached verses match an independent parse of the pinned, unmodified USFX XML. Archive/XML hashes and original archive entries match. |
| Generated catalog/evidence | Authored JSON, bundled constant Dart catalog, provenance fixture, and editorial report agree. Days 1–365 are present in order; titles, references, and each original prose field are distinct. |
| Editorial structure | **47,475 original prose words**, 114–146 words per lesson; all specified per-field bounds pass. Scripture and the labeled first-person literary reflection remain separate. |
| Store captures | **10 RGB PNGs**, five iPhone 1206 × 2622 and five iPad 2064 × 2752, prepared from actual Flutter UI renders with captions/framing. Provider state is deterministic preview data; these are not physical-device or live-payment screenshots. |
| Final screenshot packaging | Ten framed images verified as current RGB files with matching manifest dimensions/byte sizes. The actual paywall review capture's Apple checksum/size matches the upload. |
| Branding | The supplied HolyHer icon archive/master hashes are recorded in `config/icon-provenance.json`; prepared store artwork uses the current branding. |
| App privacy baseline | The 13-category baseline covers the app and current SDK collection/purpose declarations; RevenueCat purchase history is deliberately strengthened to linked because the app supplies its account UID. Podfile.lock still matches the SDK inventory hash. The completed signed archive includes the root privacy file and 29 total manifests; its combined 13 collected-data categories are covered by this baseline. This is a declaration audit, not runtime data-use or App Store validation. |

Flutter coverage includes ordered learning cards and final-card completion; questionnaire persistence/preview; lifetime-only paywall behavior; direct-navigation access guards; current-account purchase state; restore/cancellation/pending/revocation cases; stale asynchronous responses after account switching; queued completion and cache isolation; calendar/streak boundaries; small-phone large text and iPad landscape layouts.

The content build checks all 365 real lessons. The Scripture verifier preserves translation words and punctuation, excluding presentation markup, footnotes, cross-references, and verse numbers. It performs no network refresh and rewrites no evidence by default.

## Reproduce local checks

Run from the project root when no other Flutter verification owns the build lock:

```sh
python3 tool/build_lessons.py --check
python3 tool/verify_scripture.py
flutter analyze
TZ=America/New_York flutter test --concurrency=1
npm test --prefix functions
```

An intentional content rebuild uses `python3 tool/build_lessons.py` and changes the generated catalog/evidence. Store capture is a separate run:

```sh
flutter test test/screens_test.dart --dart-define=STORE_SCREENSHOTS=true --plain-name 'capture App Store screens' --concurrency=1
python3 store/frame_screenshots.py
```

Commands listed here are reproduction instructions, not additional executions claimed by this documentation update. Audit the completed native archive with `python3 tool/verify_archive.py`; its observed result is recorded below.

## Production checks still open

| Gate | Recorded state |
|---|---|
| Google project control/billing | **Verified:** holyher-app-production is controlled by iamirrf1@gmail.com with billing configured. The previous project's billing is disabled and its temporary editor grant to that account removed. |
| Hosting/Functions/rules | **Final source deployment complete:** all eight functions and Hosting deployed to the correct production project. **17 live checks and 14 additional read-only transport checks passed**, including persisted support, actual inactive RevenueCat entitlement, and account deletion. Both runs are preserved in live-cloud-verification.json. |
| Authenticated webhook smoke | Deployed Secret Manager value accepted with HTTP 200; retry was idempotent, no user/access record was created, and the exact QA event marker was removed. RevenueCat points to the correct endpoint but redacts its saved authorization header; configured-header equality and an actual RevenueCat-delivered transaction are not established by this smoke test. |
| Production secrets | **Verified:** server-secret presence/access and deployed function bindings checked in the correct project. No values are recorded here. |
| Support/billing retention | Firestore TTL policies are **ACTIVE**. TTL is asynchronous; this does not promise deletion at an exact clock time. |
| Authentication providers | Native email, Apple, and Google acceptance remains open. Apple Services ID/signing-key setup is a separate owner action from purchase credentials; see APPLE_OWNER_SETUP.md. |
| RevenueCat/Apple billing | Apple credentials connected; product/entitlement configured. Real purchase/restore, backend access validation, cancellation/pending cases, transfer, and refund/webhook acceptance remain gates. |
| Apple lifetime product | **Applied and read back:** product availability and localized prices verified across all 175 storefronts, including US$1.99. The persisted plan is no longer an unapplied draft. |
| IAP App Review screenshot | **Live read-back confirmed:** ID fcad9c60-08c3-42ef-9a8d-1c99fb217ea2; checksum and byte size match the actual uploaded paywall capture. |
| Previous unsigned build | The earlier 69.3 MB result is **stale**: it embedded holyher-production and lacked the app-root privacy manifest. Those regenerable outputs were removed. It cannot establish final identity/privacy or distribution readiness. |
| Signed archive | **Passed:** com.holyher.app, version 1.0.0 (1), both device families, correct production Firebase app, Codellion signature and Apple sign-in entitlement, compiled icon/launch resources, root privacy file, and all 29 bundled privacy manifests covered by the disclosure. See archive-verification.json. This development-signed archive still requires distribution export and Apple validation. |
| Physical device | Production build installed on iPhone 14 Pro Max. Launch was refused because the phone was locked; owner unlock requested. Native flows and physical iPad acceptance remain open. See device-verification.json. |
| Distribution upload | **Succeeded:** Xcode reported export/upload success and Apple reported package processing at October 30, 22:41:52 EDT. Processing completion and App Review remain separate. See apple-upload-verification.json. |
| Exported IPA | **Passed:** build/ios/ipa/holyher.ipa has distribution signing, debugger disabled, correct production identity/configuration, both device families, and matching privacy inventory. This separately exported artifact comes from the uploaded archive. See distribution-verification.json. |
| Reviewer identities | Two retained Firebase test accounts have real password sign-in and Secret Manager read-back verified. No paid access or journey was fabricated. Apple credential upload and native purchase acceptance remain open. See reviewer-account-status.json. |
| App Store submission | Completed build processing, reviewer credentials/contact, privacy/age/export answers, IAP attachment, and review remain to be confirmed. |
| Release control | November 15, 2026, 6:00 AM EST / 11:00 UTC is the configured target, not a verified Apple schedule. |

The final production run should cover fresh/reinstalled accounts, purchase restoration, both sign-in providers plus email, cross-device data isolation, missed-day accumulation, future-day locking, offline return, reminder permission denial, account deletion, and support delivery. Update this record with observed outcomes; do not replace missing evidence with setup reports.

Relevant artifacts: [editorial report](../content/editorial_report.json), [screenshot provenance](screenshots/README.md), [privacy preparation](PRIVACY_DISCLOSURE.md), [review preparation](REVIEW_NOTES.md), and [owner handoffs](OWNER_ACTIONS.md).
