# HolyHer production handoffs

Updated October 30, 2026. The 365-lesson implementation, automated checks, icons, and store materials are prepared. The items below concern production account control, live acceptance, and the Apple release. They are not a request to repeat configuration already reported complete.

## Only owner-required steps

1. Run the private [Apple Terminal login command](APPLE_OWNER_SETUP.md#3-one-private-terminal-login-for-the-app-store-listing), entering the hidden password and Apple's two-factor code locally. The saved session lets the agent continue listing/privacy/release automation while it remains valid; no password belongs in chat.
2. Create the separate HolyHer-only **Sign in with Apple** key and Services ID in the Apple portal, following [the exact setup guide](APPLE_OWNER_SETUP.md#1-create-the-separate-sign-in-with-apple-key). Keep the downloaded `.p8` outside the repositories and use the secure importer. RevenueCat purchase keys are already connected and do not replace this authentication key.
3. Confirm a monitored App Review contact when needed, and respond to Apple sign-in, StoreKit, and notification prompts during final real-device acceptance.

The agent continues archive validation, store uploads/read-backs, reviewer-account preparation, and release configuration. Their remaining gates are recorded below; they are not extra manual setup assignments for the owner.

## Google account and production cloud

The controlling Google account is **`iamirrf1@gmail.com`**, using the separate **`holyher-app-production`** project, with owner access and billing verified. This replaces the earlier project created through a different account. The earlier project's billing is disabled, and the temporary editor grant to the intended owner on that old project has been removed. Keep Cognein's project and data separate.

The final source deployment completed for all eight HolyHer functions and Hosting in the correct production project. Support/billing TTL policies are active. **All 17 live cloud checks and 14 additional read-only transport checks passed**, including support persistence, an actual inactive RevenueCat entitlement, and account deletion. [Live evidence](live-cloud-verification.json) preserves both runs. The public routes are:

- `https://holyher-app-production.web.app/`
- `https://holyher-app-production.web.app/privacy`
- `https://holyher-app-production.web.app/terms`
- `https://holyher-app-production.web.app/support`

The live checks confirmed public pages and persisted support submission. A monitored operations workflow remains necessary for handling and replying to real requests. TTL cleanup is asynchronous, so avoid promising removal at an exact clock time.

An authenticated webhook smoke test using the deployed Secret Manager value returned HTTP 200; retry was idempotent, no user/access record was created, and the QA event marker was removed. RevenueCat is configured with the correct endpoint, but its API redacts the saved authorization header. This verifies the endpoint's authenticated transport, not a comparison of the configured header or receipt of a real RevenueCat billing event.

## Authentication and purchase connection

Verify email signup/sign-in/reset and the production Apple and Google providers on a fresh native installation. Apple authentication configuration requires a separate Services ID/signing key; the purchase keys connected to RevenueCat cannot replace it. Follow [the Apple owner setup guide](APPLE_OWNER_SETUP.md) for the exact portal association, Firebase callback, and secure key import.

RevenueCat Apple credentials are connected. The expected Secret Manager entries, server access, and deployed function bindings are verified in the new Google project; do not repeat successful secret setup. No secret value belongs in these documents or chat. The server secrets are `REVENUECAT_SECRET_API_KEY` and `REVENUECAT_WEBHOOK_SECRET`.

Confirm the App Store non-consumable `holyher_lifetime`, RevenueCat `lifetime` entitlement, and offering agree with `config/revenuecat.json`. The launch price is **US$1.99 once**. Do not add a recurring plan. Test purchase, cancellation/pending approval, restore after reinstall, purchase transfer behavior, and refund/revocation propagation through the authenticated webhook. A connected key or dashboard product alone does not establish those results.

The nonpublic [IAP catalog](iap-catalog.json) and [persisted plan](iap-plan.json) have been **applied**. Live read-back verified available, localized prices in all **175 Apple storefronts**, including **US$1.99**; future territories are enabled. Do not regenerate or reapply the creation plan. The app's distribution must not exceed territories with an available, priced lifetime product. The actual paywall App Review image **fcad9c60-08c3-42ef-9a8d-1c99fb217ea2** is confirmed in Apple's live read-back, with checksum and byte size matching the uploaded capture. Product configuration and screenshot acceptance do not establish successful sandbox purchase/restore or App Review approval.

The helper scripts configure real services and may create or update secrets or QA records. Use them only with the intended account/project; inspect the existing configuration before repeating a setup that has already completed. `tool/check_cloud.py` creates temporary real QA accounts and documents and attempts cleanup—it is not a read-only cloud inspection.

## Native and device acceptance

The fresh signed archive for `com.holyher.app` under Codellion LLC passed production identity, deep signature, iPhone/iPad support, Apple sign-in entitlement, compiled branding, and bundled privacy checks. Its root privacy file plus 28 SDK manifests are covered by the prepared disclosure. **Xcode distribution export/upload succeeded; Apple began processing version 1.0.0 (1).** The production build installed on iPhone 14 Pro Max; iOS blocked opening it because the phone was locked. [Archive evidence](archive-verification.json), [upload evidence](apple-upload-verification.json), and [device evidence](device-verification.json) record the limits of these checks. Completed Apple processing, physical iPad and native-flow acceptance remain open.

On iPhone and iPad, exercise onboarding, purchase/restore, reading all five cards, final-card completion, rereading, catch-up days, account switching, reminders, deletion, and offline return to previously unlocked lessons. Check restart/resume and cross-device sync. Use controlled backend dates for calendar acceptance rather than changing a public user's device clock or adding a production bypass.

## App Store handoff

The agent prepares persistent Firebase test accounts and securely configures App Store reviewer access after Apple login, with a monitored contact confirmed by the owner. Reviewers can use a fresh account for onboarding/sandbox purchase and a purchased journey account for return visits. Calendar locks also apply to review accounts; paid access is never fabricated. Credentials must not be committed. All ten final framed screenshots are RGB, match the current captures, and agree with the manifest; listing upload and final privacy/age/export completion remain open.

The two Firebase review identities are now prepared, with actual password sign-in and private Secret Manager storage verified. Their passwords do not need to be created by the owner or pasted into chat. They have no fabricated purchase or journey. Apple credential upload and native purchase acceptance remain open; see [reviewer-account-status.json](reviewer-account-status.json).

Run the single private Terminal command in [APPLE_OWNER_SETUP.md](APPLE_OWNER_SETUP.md) to upload listing/screenshots and the prepared `metadata/en-US/review_notes.txt` narrative, save the privacy draft, and set the release policy. Afterwards `--reuse-session` permits further work on this Mac without retyping a password while Apple's session remains valid; missing/expired sessions fail closed. The notes-only upload preserves existing reviewer contact, demo credentials/requirement, and review attachments. Enter the real reviewer contact/credentials securely before submission; they are never filled from repository placeholders.

The agent can run `--reuse-session --inspect-release-gates` to read current app download pricing/availability, age/content-rights answers, reviewer completeness, builds/encryption, and IAP review association. Its report excludes private reviewer values and changes no answers. Free app-download pricing, the current age/export questionnaires, and final IAP/version association are separate from the verified lifetime-product price; the inspector keeps unavailable or inapplicable fields explicit.

The completed archive's combined privacy report matches the prepared disclosure. Publish the matching App Privacy answers and complete the current age-rating/export questionnaires before submission. Attach the IAP to the first version submission. Confirm live support/privacy/terms URLs before submitting.

The target is **November 15, 2026, 6:00 AM EST / `2026-11-15T11:00:00Z`**. Verify the chosen release control in App Store Connect after upload and submission; `config/release.json` records intent only. Do not describe the app as uploaded, approved, or scheduled until the corresponding Apple result is observed. Review timing and store propagation can affect actual availability.

Current evidence and remaining uncertainty are recorded in [VERIFICATION.md](VERIFICATION.md). No credentials are required in the repository to make these handoffs reviewable.
