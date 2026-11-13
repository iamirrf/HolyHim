# HolyHim redesign — development delivery

Version 2.0.0 (6), branch `redesign/v2`. `snapshot/walk-v1` and the existing work were preserved. The compatible Firebase rules and six named functions were deployed with explicit approval on November 5. No push, App Store upload, hard-paywall activation or phone-data deletion was performed.

Implemented:

- Three-scene welcome and full-screen SunRize-style email authentication; bundled Dancing Script bold wordmark; sage/gold accents, depth and transparent navigation edges.
- Eleven onboarding surfaces, ruler birthday, editable authored guide conversations, planned-routine preview, profile/photo setup and actual durable-save status. Drafts resume at the unfinished step; completion is saved before the dismissible lifetime paywall. Promise hold and sample lesson are removed.
- Retained Walk/Saved/Growth/Profile tabs; corrected swipe/route synchronization; profile identity/statistics/settings hierarchy and dedicated persistent theme picker.
- Photo picking, pinch/drag cropping, local preview, upload, replacement/removal and deployed backend cleanup. Explicit removal also hides a social-provider photo.
- Exactly Scripture → Meaning → Reflection → Prayer. Practical invitations are inside Reflection. The 1.2-second Amen control sits outside scrolling prayer text. Completion uses the adapted 2.8-second Cognein effect and prevents duplicate progress.
- Account-scoped durable local state, monotonic onboarding, preserved pending edits and retryable sync errors. Firestore map ordering and timestamp representation no longer prevent acknowledgment; failed local completion writes can retry without a duplicate award, and old-account cache errors cannot leak into the current account. Rewinding guide answers clears later answers through stale snapshots and retries.
- RevenueCat lifetime adapter for `holyhim_lifetime` / `lifetime`, localized price, restore and store states, ownership isolation, pending update/foreground refresh and testing exit. Exit does not create a purchase. Future hard gate remains disabled.
- Independent daily verse shared by app, notifications and widget catalog, anchored to January 1, 2026; one reminder per day with a real Scripture excerpt and exact-verse link. Cold taps survive sign-in and paywall dismissal. Native small/medium/Lock Screen widget target is embedded, with App Group entitlements and bundled verse/art catalogs.
- All 365 lessons written and reviewed; all exact WEB quotations independently validated. 25 generated Christian images and 19 matching transparent 3D badges bundled with thumbnails and a shared 365-day manifest.
- Compatible Firestore/Storage rules, account-photo deletion, verified billing endpoints/webhook and replaced-photo cleanup deployed and verified locally and live.

Evidence:

- `verification.json`: final check results and explicit limits.
- `gallery.html`, `screens/`: raster layout captures; these are not device screenshots.
- `SCREEN_COMPARISON.md`: reference composition/state checklist and remaining physical checks.
- `library-review.jpg`, `badges-review.jpg`: inspected generated artwork.
- `CONTENT_REVIEW.md`: sequential authorship and all-lesson review record.
- `MISSING_FEATURES.md`: remaining acceptance gaps and release actions.
- `DEPLOYMENT.md`: approved backend scope and completed deployment record.

Verified delivery:

- Signed physical-device build succeeds with the embedded widget and App Group on both targets.
- HolyHim **2.0.0 (6) was upgraded in place and launched on Amir’s real iPhone over `localNetwork`**. The existing app data was preserved. A real-device cache check confirms completed onboarding, existing lesson progress and zero pending profile edits after the acknowledgment fix. `iphone-run.json` records the confirmed running process.
- All six named backend functions are ACTIVE; Firestore/Storage release sources match this checkout and old endpoints were retained.
- Fifteen live checks passed with a disposable QA account: profile create/rename/onboarding stability, answer rewinding, progress, saved add/remove, access verification, owner-only reads, avatar upload/replacement/removal, and full account/photo deletion. The QA account was deleted.
- Analyzer clean; 101 Flutter tests, 25 emulator/function tests, 17 Python tool tests, content/independent Scripture validation, and native Foundation widget tests pass.

Remaining verification:

1. Apple’s UI test connection is blocked by **“Device is busy (Preparing Amir’s iPhone)”** and a secure `com.apple.mobile.notification_proxy` connection error. The final build is installed and its foreground process was confirmed. Retrying UI tests after a successful unlocked launch still timed out during device preparation. The minimum next recovery step is to restart and unlock the phone, keep it awake, and retry the physical review. The 29 gallery images are explicitly raster layout captures, not phone screenshots.
2. Native liquid-glass comparison, measured swipe frame times, physical haptic feel, VoiceOver, large-text/transparency settings and crop gestures still need the device review. `PERFORMANCE.md` distinguishes the passing swipe behavior test from measured FPS.
3. Actual StoreKit sandbox purchase and restore need the signed device’s sandbox confirmation flow. SDK-channel fixtures and live server ownership checks pass; no real or sandbox purchase was made. The testing exit remains enabled and never grants a purchase.
4. Widget embedding/signing and the shared calendar catalog are verified. The actual iPhone App Group payload is version 3, includes the active theme palette, and matches calendar verse 309; it contains no account credentials. OS placement, midnight reload and notification taps need physical checks; calendar/DST/travel behavior is covered in Dart and native model tests.
5. Local legal and store review copy are prepared; the previous hosted web app/marketing build and App Store assets have not been published or refreshed. The installed app reads the updated legal text offline.

Firebase deployment is now approved and complete. Push, App Store submission, Hosting publication and hard-paywall activation remain separately approved actions under the project AGENTS.md.
