> Development rebuild in progress (October 31, 2026). The active source now uses free edition access and Learn/Saved/Profile. Only the first five lessons have the new guided format. See [rebuild status and migration](store/REBUILD_MIGRATION.md) and [parity matrix](store/COGNEIN_SCREEN_MAP.md). Historical build-1 billing and release notes below are not the current implementation or proof of a completed rebuild.

# HolyHim

HolyHim is a women-focused daily Bible companion for iPhone and iPad. The current source contains **365 complete lessons**, a personalized onboarding flow, Today / Journey / Profile, and a **US$1.99 one-time lifetime purchase**. Version `1.0.0+1` uses production bundle identifier `com.holyhim.app` under Codellion LLC.

The implementation, production cloud deployment, Apple product setup, and automated checks are complete. The signed iPhone/iPad archive passed identity, signature, and bundled-privacy verification and installed on iPhone 14 Pro Max. **Apple accepted the upload of version 1.0.0 (1) and began processing it.** This checkout is **not yet a verified App Store submission candidate**: native account/purchase acceptance, completed Apple processing, and listing/submission gates remain open. iOS blocked the phone launch while it was locked. See [delivery status](DELIVERY.md), [verification evidence](store/VERIFICATION.md), and [owner actions](store/OWNER_ACTIONS.md).

The requested release target is **November 15, 2026 at 6:00 AM America/New_York / 11:00 UTC**. [Release configuration](config/release.json) records that target; it does not establish an App Store schedule, upload, approval, or public availability.

## Reading experience

Each lesson moves through **Verse → Confidence → Reason → Hope → Carry** using swipeable learning cards and a forward action. Completion is available on the last card. Bible quotations are verbatim public-domain World English Bible (WEB). The reader-facing explanation and separately labeled first-person devotional reflection are original prose; the reflection is distinct from Scripture.

All readers receive the same ordered curriculum. Onboarding saves preferred name, Bible familiarity, focus, routine obstacle, and optional reminder. These choices inform presentation, reading guidance, and application prompts. Previously unlocked lessons remain available for rereading and catch-up.

The design adapts relevant Cognein surfaces and interactions in HolyHim's pearl, blush, and Lexend system. [The screen map](store/COGNEIN_SCREEN_MAP.md) records the corresponding screens and intentional product boundaries. The supplied HolyHim icon set is recorded in [icon provenance](config/icon-provenance.json).

## Accounts, access, and daily release

Sign-in is required through Apple, Google, or email/password. Firebase Authentication and Firestore support the account and synced setup/progress. All eight Cloud Functions and Hosting are deployed to the correct production project. Live email authentication, account isolation, receipt reconciliation for an unpaid account, support submission, and account deletion passed. Native provider and purchase acceptance remain open. Apple Sign-In's separate Services ID/signing-key setup is documented in [the owner setup guide](store/APPLE_OWNER_SETUP.md).

`holyhim_lifetime` is the sole non-consumable product, granting the RevenueCat `lifetime` entitlement. Localized prices come from the App Store product. Purchase and Restore Purchases use RevenueCat and backend confirmation; a local boolean does not grant production access. RevenueCat identifiers are recorded in [purchase configuration](config/revenuecat.json). The [Apple product plan](store/iap-plan.json) has been applied: live read-back verified availability and localized prices in all 175 storefronts, including US$1.99. Apple read-back also confirms the actual paywall review image with matching checksum/byte size. These setup results do not prove a real purchase, restore, refund, or webhook flow.

The purchased journey begins with Day 1. One new lesson unlocks per calendar day in the journey's saved time zone, using server dates. Missed days accumulate rather than disappear. Previously unlocked content supports offline reading after successful setup; reconnect to sync and obtain new unlocks. Account-specific caches and generation checks isolate sign-in sessions.

Settings includes setup editing, optional local reminders, haptics, restore, help, About, Privacy, Terms, sign-out, and account deletion. Apple-linked deletion includes reauthentication and token revocation; the backend removes account data and requests RevenueCat customer deletion. Live acceptance remains a release gate.

There is no advertising or marketing analytics package. Firebase and Google Sign-In declare technical service data, and RevenueCat provides purchase analytics. The app therefore must not be described as collecting no data. See [privacy disclosure preparation](store/PRIVACY_DISCLOSURE.md).

## Content and reproducible checks

Authored content lives in `content/lessons_001_183.json` and `content/lessons_184_365.json`. `tool/build_lessons.py` generates the bundled constant catalog, source fixture, and editorial report. Edit the authored JSON rather than generated Dart.

From this directory:

```sh
python3 tool/build_lessons.py --check
python3 tool/verify_scripture.py
flutter analyze
TZ=America/New_York flutter test --concurrency=1
npm test --prefix functions
```

After an intentional content edit, run `python3 tool/build_lessons.py`, then rerun verification. The read-only Scripture verifier checks the pinned archive/XML hashes, independently parses all source verses, compares every quotation, and checks generated artifacts. It does not fetch or rewrite evidence by default.

Latest recorded results: **53 Flutter tests passed, including the store capture**, `flutter analyze` reported **no issues**, **17 backend tests passed**, and all **365 lessons / 371 quoted verses** verified. **17 live cloud checks and 14 additional read-only transport checks passed**; [the evidence](store/live-cloud-verification.json) preserves both runs. The original devotional prose totals **47,475 words**. Ten current RGB App Store images—five iPhone and five iPad—match the final manifest and are documented in [screenshot instructions](store/screenshots/README.md). These deterministic app renders do not demonstrate a live purchase or a native-device run.

## Development and production services

Install Flutter/Dart and the native Apple toolchain, resolve the declared packages, and use the HolyHim Firebase project configuration before running:

```sh
flutter pub get
flutter run
```

`flutter run` does not bypass account, purchase, or backend requirements. The production project is `holyhim-app-production`, controlled by `iamirrf1@gmail.com` with billing verified. All eight functions and Hosting are deployed, server-secret access/bindings are verified, and support/billing TTL policies are active. Billing on the earlier project is disabled, and the temporary editor grant to the intended owner on that old project has been removed. Keep HolyHim services separate from Cognein.

The deployed website is `https://holyhim-app-production.web.app`, with `/privacy`, `/terms`, and `/support`. Live checks passed for public pages, persisted support submission, the actual inactive RevenueCat entitlement, and account deletion. Native sign-in and active purchase/restore acceptance remain separate release gates.

The deployed webhook accepted an authenticated smoke request and an idempotent retry without creating user/access data; its QA marker was removed. RevenueCat's endpoint is correct, but its API redacts the configured header. A real RevenueCat-delivered transaction and full purchase lifecycle remain unverified.

Server credentials belong in Secret Manager, and reviewer credentials belong in App Store Connect. Do not commit or print secrets. The existing connection/deployment helpers change real services; they are operator tools, not read-only checks. [Owner actions](store/OWNER_ACTIONS.md) identifies the remaining handoffs without treating reported configuration as verified behavior.
