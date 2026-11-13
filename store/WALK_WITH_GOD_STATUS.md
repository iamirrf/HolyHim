# Walk with God — implementation and release status

Version **1.2.0 (4)**. Updated November 3, 2026, America/New_York. **Release acceptance remains incomplete.** The new app and public website are staged; no new client has been uploaded to Apple or deployed to production Hosting.

## Production compatibility repair

The production Firestore rules accept profile schemas 2, 3, and 4 and reject unknown versions. Compilation, deployment, read-back hash, authenticated writes, and restoration of the retained onboarding QA draft are recorded in `walk-rules-deployment.json` and `walk-onboarding-live.json`.

Compatible `startJourney`, `getJourney`, `completeReading`, `saveReadingCheckpoint`, legacy completion endpoints, reset, and export functions are deployed to `holyhim-app-production`. Thirteen authenticated production checks passed using only the retained journey QA account: idempotent creation/retry, five-card acceptance without answers, incomplete rejection, noninflating rereads, reading dates, permanent badge, late checkpoint protection, authentication, account isolation, and export. See `walk-reading-live.json`. Customer accounts were not modified.

## Implemented

- Shared bundled Source Serif 4 / Manrope typography; Pearl, Rose, Lavender, Sage, Dawn, and Midnight palettes; bundled open-font license notices; one persistent mesh/particle backdrop; reduced effects; native iOS glass with a Flutter fallback.
- Recoverable launch, account entry, four semantic onboarding checkpoints, optional personalization, real Day 1 preview, immediate local saves, bounded cloud retries, and server-acknowledged journey entry.
- Five stationary, independently scrollable reading cards; spring swipes, back/next, keyboard arrows, bookmark, sharing, final-action completion, accurate pending synchronization, and permanent keepsakes.
- All 365 readings / 1,825 cards. Titles, sequence, references, and exact pinned WEB passages are preserved. Each reading is 290–360 words. Codex reviewed every body, recorded hashes, and replaced remaining writing activities. See `WALK_CONTENT_REVIEW.md`; independent human review is not claimed.
- Account-scoped transactional reading outbox and checkpoints, legacy resume migration/outbox draining, optimistic revision conflicts with both positions retained for export, persisted offline checkpoint retry, reset archives, deletion guards, and generation checks across account changes.
- Completion-date reading streaks, distinct lesson progress, rereads, accurate calendar data, and permanent badges at 1, 7, 30, 90, 180, and 365 distinct readings. Historical visit records remain separate.
- Winding 73-unit Walk, current reading/Return to today, compact preview sheets, Saved search/filter/detail/undo/text and verse-image sharing, Profile, calendar, themes, badges, reading size, identity, support, legal, export, reset, and deletion screens.
- Up to 60 one-shot native quote reminders, device-local delivery time, journey-timezone lesson selection, exact account/day destinations, queue refresh/cancellation, and a web-only preference editor. Real delivery and tap acceptance remain unverified.
- Firebase web registration, shared `/app/` client, browser authentication, clean protected URLs, account-scoped IndexedDB with Web Locks and deletion tombstones, public shell/artwork caches, local public Firebase SDK modules, recoverable loading, and explicit app update reload. Shell versions cover every generated asset; artwork manifests revalidate while versioned image files remain immutable.
- Responsive Firebase public website with genuine Flutter screenshots, the same authored interactive Day 1 sample, journey/themes/Saved/FAQ sections, support API preservation, and matching legal/error pages.
- Gemini Python pipeline with 365 distinct composition prompts, fixed visual brief/reference input, resumable batches, bounded retries, model selection, optimized versioned assets, source/checksum/review manifest, and approved-asset packaging. No images have been generated, approved, or published.

## Verification evidence

The [gallery](walk-redesign/index.html) contains actual Flutter captures for all six themes, setup, reader, Saved, Profile, settings, calendar, keepsakes, iPad layouts, and 200% text. Images use isolated QA fixtures and the botanical fallback; they are not physical-device evidence.

Automated verification includes **105 passing Flutter unit/widget/layout/semantics tests**, an additional passing protected-router regression, a clean analyzer, 31 backend unit tests, seven real Firestore emulator integration tests, generated-content checks, and independent verification of 365 lesson passages / 371 corpus verses. Public-site and IndexedDB checks passed Chromium, Firefox, and WebKit at desktop, tablet, and 390/320-pixel widths, including mocked support submission, exclusive tabs, and deletion tombstones. See `walk-redesign/browser-qa.json`.

Authenticated Chromium checks passed protected email sign-in, return to Saved, browser Back/Forward with retained search, direct-link refresh, and offline reopening of the unlocked reading at its saved card. See `walk-redesign/account-browser-qa.json`. An isolated service-worker update test also passed explicit reload, worker activation, and IndexedDB record retention (`walk-redesign/browser-update-qa.json`). Mobile support, legal, and styled error pages passed layout checks (`walk-redesign/public-pages-qa.json`). The development-signed iOS archive passed identity, deep-signature, device-family, Apple Sign-In entitlement, and bundled-privacy verification (`walk-redesign/archive-verification.json`). App Store distribution export is blocked by the absent Apple Distribution signing identity/Xcode account (`walk-redesign/ios-build.json`). No version-1.2.0 IPA exists. The prior version-1.0.0 IPA is preserved under `build/ios/ipa-before-walk/`. The native build result is recorded separately; an earlier failed run is never counted as passing. Browser engine automation does not establish native Safari/Chrome/Firefox OAuth acceptance or physical VoiceOver/performance quality.

## Remaining release gates

1. **Artwork credential and output:** supply `GEMINI_API_KEY` outside the repository and a reviewed reference composition; generate, inspect, approve, bundle the initial artwork, and publish the optimized 365-image collection. Current manifests contain only planned entries. No substitute imagery is represented as Gemini output.
2. **Native distribution and device acceptance:** HolyHim **1.2.0 (4) is installed on the online, unlocked iPhone**, verified by device read-back after an in-place upgrade through the paired-device installation service. CoreDevice remote launch remains blocked before app execution because its developer image cannot mount/unmount (12040/12010, device InternalError), even after Apple device-support refresh. The direct debugger service is also unavailable. USB retry and manual app-launch feedback have been requested. configure the Apple Distribution certificate/account and export/verify the final IPA; capture physical-device recordings; verify actual reminder delivery and matching warm/cold taps, permission denial, device timezone changes, and account cancellation. Verify Apple/Google providers and cancellation on supported devices.
3. **Accessibility and sustained performance:** complete manual VoiceOver, contrast, touch/keyboard, reduced effects, and sustained animation checks on small/large iPhones and iPad portrait, landscape, and actual system Split View. Automated 200% text/layout coverage is available; it does not replace these checks.
4. **Web release acceptance:** finish remaining browser error-state checks, verify real OAuth cancellation/redirects in current Safari, Chrome, and Firefox, then deploy the accepted client and public website and verify production routes/support/legal. The new web build remains local.
5. **Store package:** finalize current screenshots, reviewer instructions, and delivery evidence after acceptance. The requested November 15, 2026 06:00 America/New_York release is a target, not an Apple schedule. No new upload or submission has been made.

## Reproduction and preserved work

Use the current commands in the repository README. Build the public site and shared client with `python3 tool/build_web.py`; preview using `python3 tool/preview_public.py`. Production mutation scripts require the existing owner credentials and never print secrets. Authenticated browser QA accepts only retained QA credentials via stdin.

Existing uncommitted work was preserved before editing in `/tmp/holyhim-before-walk-redesign.tar.gz`. The previous signed archive is retained under `build/ios/archive-before-walk/`. Historical build-1 and prior guided-format reports are retained and superseded by this status; they do not prove acceptance of version 1.2.0 (4).
