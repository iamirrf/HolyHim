> Current Walk with God implementation: see [release status](store/WALK_WITH_GOD_STATUS.md) and [visual gallery](store/walk-redesign/index.html). The historical delivery record below does not establish readiness for version 1.2.0 (4).

> Development rebuild in progress (October 31, 2026). The active source now uses free edition access and Learn/Saved/Profile. Only the first five lessons have the new guided format. See [rebuild status and migration](store/REBUILD_MIGRATION.md) and [parity matrix](store/COGNEIN_SCREEN_MAP.md). Historical build-1 billing and release notes below are not the current implementation or proof of a completed rebuild.

# HolyHim delivery status

Updated October 30, 2026. HolyHim contains the complete 365-lesson implementation, deployed production cloud services, the configured worldwide lifetime product, and prepared store materials. **Apple accepted the 1.0.0 (1) upload and began processing it. App Review readiness and release scheduling remain unverified.**

## Implemented

- **365 complete WEB lessons**, with 365 unique references/titles and distinct original confidence, reason, hope, devotional-reflection, and practical-reflection prose. Every quotation is tied to the pinned authoritative corpus and its provenance.
- A premium iPhone/iPad experience: splash/welcome, Apple/Google/email authentication screens, guided questionnaire, personalized rhythm summary and preview, lifetime paywall, Today, virtualized Journey, Profile, five learning cards, completion, Settings, help, About, Privacy, and Terms.
- Account-specific setup, progress, activity, and caches; server-governed calendar unlocking; accumulated missed days; offline access to previously unlocked lessons after setup; queued completion and cross-account safeguards.
- RevenueCat purchase/restore integration for the `holyhim_lifetime` non-consumable and `lifetime` entitlement. US launch price is **$1.99 once**, with localized store pricing and no recurring plan.
- Firebase/Firestore/Cloud Functions source for access validation, journey start/unlock/completion, activity, authenticated billing webhooks, deletion, and website support.
- Production identity `com.holyhim.app`, Codellion LLC publishing identity, supplied HolyHim icons, English listing/review materials, privacy preparation, and ten App Store marketing captures.

The first-person devotional voice is clearly separate from the quoted World English Bible passage. All readers receive the same complete curriculum; setup personalizes guidance and application rather than generating Scripture or lesson text.

## Recorded verification

| Check | Latest recorded result |
|---|---|
| Flutter automated suite | 53 tests passed, including the store capture |
| Flutter analyzer | No issues found |
| Backend domain suite | 17 tests passed |
| Scripture and generated catalog | 365 lessons, 371 quoted verses verified; all 38,058 cached source verses match an independent XML parse |
| Original prose | 47,475 words; required field lengths and global uniqueness checks passed |
| Store images | Five iPhone and five iPad RGB PNGs prepared from actual Flutter-rendered screens |
| Icon provenance | Supplied icon archive and master hashes recorded |
| Production cloud | Final deployment of all eight functions and Hosting succeeded; server-secret bindings/access verified; support/billing TTL policies active |
| Live cloud acceptance | 17 live checks and 14 additional read-only transport checks passed, including persisted support, actual inactive RevenueCat entitlement, and deletion |
| Webhook transport | Authenticated smoke and idempotent retry passed; no user/access data created, QA marker removed. RevenueCat endpoint correct; redacted configured header and real billing-event delivery remain unverified |
| Apple lifetime product | Product plan applied; live availability and localized prices verified for all 175 storefronts, including US$1.99 |
| IAP review screenshot | Apple live read-back confirms actual paywall capture fcad9c60-08c3-42ef-9a8d-1c99fb217ea2 with matching checksum/byte size |
| Signed archive | Production identity, iPhone/iPad families, signature, branding resources and all 29 bundled privacy manifests passed |
| Physical install | Installed on iPhone 14 Pro Max; launch blocked by locked device |
| App Store upload | Xcode export/upload succeeded; Apple reported package processing. No review submission or public release |
| Exported IPA | build/ios/ipa/holyhim.ipa passed distribution signing, disabled-debugger, identity and privacy checks |
| Reviewer identities | Two retained Firebase test accounts created, actual sign-in and private credential storage verified; paid/native acceptance and Apple credential upload remain open |

These results establish automated behavior, a signed native archive, and successful App Store upload. They do not establish completed Apple processing, native provider/purchase acceptance, App Review submission/approval, or public release. [Verification details](store/VERIFICATION.md) records those boundaries.

## Remaining production gates

The `holyhim-app-production` Google project is controlled by `iamirrf1@gmail.com`, with billing and production service bindings verified. All eight functions and Hosting are deployed. All 17 live cloud checks and 14 additional read-only transport checks passed; [the evidence](store/live-cloud-verification.json) includes persisted support, actual inactive RevenueCat entitlement, and account deletion. The earlier project's billing is disabled, and its temporary editor grant to the intended owner has been removed. RevenueCat Apple credentials are connected, and worldwide product availability/prices and the review-image read-back are verified. Native Apple/Google/email authentication and real purchase/restore/refund/webhook/deletion flows remain acceptance gates. Apple Sign-In requires its own Services ID/signing-key setup, separate from RevenueCat purchase keys; see [the owner guide](store/APPLE_OWNER_SETUP.md).

The fresh signed archive passed production identity, deep signature, iPhone/iPad support, Apple sign-in entitlement, compiled branding resources, and combined privacy checks. It contains the correct Firebase app, the root privacy file, and 29 total privacy manifests covered by the prepared 13-category disclosure. It installed on iPhone 14 Pro Max; iOS blocked launch because the phone was locked. **Distribution export/upload succeeded and Apple began processing the package.** The ten framed screenshots are current RGB images matching their manifest. Current-device acceptance, completed Apple processing, reviewer accounts/contact, final privacy/age/export answers, listing upload, and IAP/version submission remain open. Evidence: `store/archive-verification.json`, `store/apple-upload-verification.json`, and `store/device-verification.json`.

The requested release is **November 15, 2026 at 6:00 AM EST (11:00 UTC)**. It is recorded in `config/release.json`, not claimed as configured in App Store Connect. Approval and store propagation affect actual availability.

See [owner actions](store/OWNER_ACTIONS.md) for the remaining handoffs and [review preparation](store/REVIEW_NOTES.md) for the reviewer flow.
