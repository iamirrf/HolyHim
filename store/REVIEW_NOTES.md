# HolyHer 1.0 review preparation

Publisher: Codellion LLC. Bundle: `com.holyher.app`. Devices: iPhone and iPad. Planned release: November 15, 2026, 6:00 AM EST / `2026-11-15T11:00:00Z`.

The review narrative is `metadata/en-US/review_notes.txt`; the listing helper uploads this through Deliver's review-notes option and verifies its read-back. It sends only the narrative, preserving existing contact details, demo credentials/requirement, and attachments. Listing upload and App Review submission remain open. Enter the real reviewer contact and credentials securely in App Store Connect; do not submit with them unconfigured.

## Reviewer access

Prepare real Firebase email/password test accounts, then enter credentials and a monitored review contact securely in App Store Connect. Store no passwords here. A fresh account supports onboarding and the sandbox purchase/restore flow; a purchased journey account supports return visits. Later lessons follow the same calendar rule for reviewers. The complete catalog is bundled, and controlled tests cover later-day behavior. Keep the production backend available throughout review. Do not fabricate paid access, backdate a public user's journey, add a public clock bypass, or hardcode a reviewer password.

Both reserved Firebase review identities are prepared and their real password sign-ins verified. Credentials are kept in the labeled `HOLYHER_APP_REVIEW_ONBOARDING` and `HOLYHER_APP_REVIEW_JOURNEY` Secret Manager secrets under the correct Google owner. These identities do not create email inboxes or claim email verification. Apple credential upload and native paid-flow acceptance remain open; see `reviewer-account-status.json`. Re-running `python3 tool/prepare_review_accounts.py` validates recognized accounts without resetting passwords or granting access.

Accounts support synchronized setup, the server-governed daily curriculum, completion history, and activity across devices. The selected release requires sign-in through Apple, Google, or email. Explain these actual account features in review notes; Apple's significant-account-functionality requirement still applies, and approval is not assumed.

## Feature walkthrough

1. Sign in and complete the guided questions: preferred name, Bible familiarity, focus, routine obstacle, and optional reminder. The summary and real lesson preview lead to the lifetime purchase.
2. Purchase `holyher_lifetime`, a non-consumable granting the RevenueCat `lifetime` entitlement. US launch price is $1.99. Prices shown in the app come from the localized App Store product. There are no subscriptions.
3. Day 1 opens when the purchased journey starts. The server unlocks one more day each calendar day in the saved journey time zone. Missed days accumulate; any previously unlocked lesson can be read or reread. Future days on a fresh account are intentionally unavailable.
4. Open a lesson from Today or Journey. Swipe or use the forward action through Verse, Confidence, Reason, Hope, and Carry. Complete is available on the final card and saves the day. The full 365-lesson catalog is bundled.
5. Use Profile → Settings for setup editing, reminders, restore, support, privacy, terms, sign-out, and account deletion. Apple-linked deletion reauthenticates and revokes the Apple token; the backend removes account, profile, and journey records and requests RevenueCat customer removal.
6. After successful setup, previously unlocked content supports offline reading. Reconnect for new day unlocks and cross-device synchronization. Reminders are local and optional.

Scripture is exact public-domain World English Bible text, labeled WEB. The following reader-facing prose and the separately labeled first-person devotional reflection are original writing. That literary reflection is not a Bible quote, a new revelation, or generated content. The same ordered lessons serve all readers; setup changes presentation and application prompts.

## Submission dependencies

- Real reviewer accounts/contact information, verified production sign-in providers, and successful purchase/restore/deletion acceptance.
- Apple Sign-In Services ID/signing-key configuration, separate from RevenueCat's purchase keys, followed by actual Apple sign-in and deletion/token-revocation acceptance. [Owner setup](APPLE_OWNER_SETUP.md) supplies exact portal settings and a secure importer.
- Public pages and persisted support submission passed the live cloud checks; requests still need a monitored operations workflow. Final deployment of all eight functions and Hosting to holyher-app-production succeeded. All 17 live checks and 14 additional read-only transport checks passed, including actual inactive RevenueCat entitlement and account deletion. Support/billing TTL policies are active.
- Authenticated webhook smoke and idempotent retry passed with no user/access data created; the QA marker was removed. RevenueCat's saved endpoint is correct, but its API redacts the authorization header. Real RevenueCat-delivered transaction and purchase-lifecycle acceptance remain open.
- Completed Apple processing and App Store acceptance. Distribution export/upload succeeded; Apple reported version 1.0.0 (1) processing. The fresh signed archive passed production identity, signature, compiled branding, and all 29 bundled privacy-manifest checks. It installed on iPhone 14 Pro Max; launch was blocked by the locked phone. Complete native acceptance, save the verified privacy answers, and finish the current age/export questionnaires before submission.
- The Apple lifetime product plan is applied, with live availability and localized prices verified in all 175 storefronts, including US$1.99. The real paywall App Review screenshot fcad9c60-08c3-42ef-9a8d-1c99fb217ea2 is confirmed in Apple read-back with matching checksum/byte size. Attach the IAP to the first version submission. These setup results do not establish successful sandbox transactions or approval.
- Five iPhone and five iPad marketing PNGs are current RGB files matching the screenshot manifest; actual-render provenance is recorded alongside them. Latest automated checks passed: 53 Flutter tests including capture, analyzer with no issues, 17 backend tests, and all 365 lessons/371 quoted verses verified. Complete native-device acceptance separately.

Sources: [Apple review access and account rules](https://developer.apple.com/app-store/review/guidelines/), [account deletion](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion), [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).
