> Historical status. Superseded by [the November 4 redesign delivery audit](redesign-v3/DELIVERY.md). The remaining gates below describe an earlier checkout.

# HolyHim 2.0 — release status

Updated November 4, 2026. This supersedes `WALK_WITH_GOD_STATUS.md` for the
`redesign/v2` branch. Original v1 work is preserved by local commit `a07b5bc`
on `snapshot/walk-v1`. No push, deployment, production account test, or App Store
upload has been performed by this redesign.

## Implemented

- Version 2.0.0 (5), bundled Playfair Display / Lora / Manrope / Pinyon Script,
  eight theme atmospheres, Cognein/SunRize ports, native iOS 26 tab configuration
  and portable refracting fallback, reduced motion/transparency, accessible text.
- Signed-out welcome, Apple/Google/email auth, local onboarding, four tabs,
  five-card lesson deck, hold Amen, completion, calendar, badges, saved verses,
  image sharing, profile controls, support/export/deletion and legal pages.
- Firestore schema 5 optimistic repository with field merges, background legacy
  migration, pure pacing/streak/grace/badge/notification engines and owner rules.
  Functions export only deleteAccount/supportRequest; deployed v1 endpoints
  remain unchanged until an approved deployment explicitly removes them.
- Local notification queue, permission guard, tap routing and native delegate.
- Nine-section local website, legal/support/404, five-card demo, live themes,
  reduced-motion/no-JS support. Static and production-JS interaction checks pass.
- Gemini plan/generate/review/package tooling, reviewed style/hash approval,
  concurrency/backoff/resume and package split. Dry run: 392 images, zero paid calls.
- WidgetKit source/extension, App Group configuration and local widget bridge.
  Native widget arm64 simulator compile and Foundation/DST tests passed.

## Content

The user approved the warm, plain voice of Days 1–7. **Days 1–168 are freshly
authored. Days 169–365 are still working adaptations and must be rewritten.**
See `content/v2-editorial-status.json` for exact sequential batch states/hashes.
`content/lessons_v2.json` is the only runtime source. Every entry passes current
mechanical gates; that does not mark unfinished editorial drafts approved.

All 365 verses match the pinned public-domain WEB. The independent verifier also
checks all 38,058 corpus entries against the original XML and archive hashes.

## Verification so far

- Domain, repository, notifications/migration and accessible screen tests pass in
  scoped runs. The final full-suite/analyzer record is being completed.
- Firestore emulator and function tests: 15/15 passed on demo-holyhim; use the
  Java 21 invocation documented in README.md, not the production project.
- Content validator/builder/scripture and 17 Python content/art tests passed.
- Website: six production-script interaction checks and local HTTP/static audits
  passed. See `v2-website-qa.md` for scope and exact limits.
- Production Runner arm64 simulator build succeeded; source log:
  `/tmp/holyhim-v2-production-build.log`. Widget native compile also passed.
- Native fixture screenshot work is in progress. Multiple large native builds
  hit OS Error 28 (disk full). Only task-owned generated outputs and the temporary
  QA simulator may be removed to recover capacity; source and prior release
  archives are preserved.

## Remaining ship gates

1. Finish the remaining sequential lesson batches and regenerate the catalog.
2. Provide an AI Studio API key in GEMINI_API_KEY; generate Day 1 candidates and
   obtain the user's style choice before any bulk generation. Review/package art.
3. Complete native visual/device checks, including native glass, haptics,
   Apple/Google sign-in and a real local reminder tap. No physical-device result
   or 60 fps measurement is currently claimed.
4. Browser visual QA at 390/768/1440 remains unverified: the mandatory in-app
   browser execution tool was unavailable. No Chrome screenshots are claimed.
5. Register/enable the App Group in the owner's Apple signing account and verify
   widget refresh/deep links on a signed device. Distribution export requires the
   pre-existing Apple Distribution certificate setup.
6. Update store screenshot assets after visual approval, check final metadata,
   then obtain explicit approval for Firebase deploy and App Store upload.

Missing artwork always uses a themed fallback. Production deployment remains
gated by the user's brief; code completion does not grant deployment permission.
