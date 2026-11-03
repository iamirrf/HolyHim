# Native redesign migration

This work targets the Flutter iPhone/iPad app. The public website is outside the redesign. The workspace was already dirty; its starting source and Git status are preserved in `baseline-source.tar.gz` and `baseline.json`. Neither repository was reset or committed.

## Onboarding

Checkpoint version 3 uses the semantic IDs `name`, `moment`, `starting-point`, `barrier`, `guided-example`, `daily-rhythm`, `focus`, `reminder`, `summary`, `save`, `day-one`, `arrival`.

Version 1 first passes through the existing seven-stage meanings; version 2 maps its ten existing meanings into the new sequence. Version 3 trusts a valid semantic ID ahead of a numeric index. Completed accounts keep completion, answers, and enabled reminders. Migration requests no permission. Suggested time, enabled reminder time, actual permission decision, explicitly answered stages, and unscored example state are separate fields.

Local drafts are serialized. Setup completes only after retained free enrollment succeeds. Retries keep their operation identity. Updating the onboarding-complete flag preserves the existing journey notifier and daily-release state.

## Reading and completion

Only Days 1–5 have authored enhanced teaching. They retain nine semantic steps and two canonical questions. The other 360 lessons retain Verse, Confidence, Reason, Hope, Carry. Continuation fragments are measured separately and concatenate to the complete original text. Source offsets restore the unread position after width/text-size changes. Existing semantic and older numeric resumes remain readable.

Accepted enhanced completion atomically stores its outbox, clears resume, and records local progress using the production transactional store. Calendar dates are actual first completion dates in the saved journey timezone. The backend preserves an existing date on practice/retry. Unknown historical dates remain unknown; they are never reconstructed from app-visit streak dates. Reset clears completion dates along with progress while preserving the original release calendar and access grant.

## Release dependency

**No production backend, Firestore rules, website, or App Store deployment was performed.** This source changes the accepted profile schema to version 3 and adds completion-date/read-offset fields. Deploy the reviewed compatible Firestore rules and callable functions as part of the separately authorized release before distributing this app to live accounts. Existing deployed v2 rules can reject new profile writes; a local simulator build is not evidence that production has been upgraded.

The backend and Firestore changes were exercised locally. Real Apple/Google sign-in, push permission/scheduling, cross-device cloud convergence, and destructive account actions still need an authorized live-account/device acceptance run before release. Local fixtures deliberately avoid production account reads and messages.

## Typography and build identity

UIKit resolves `.rounded` at runtime for regular and semibold. CoreText tables are adapted in memory for Flutter; copied system font files are neither bundled nor saved. The 22-point specimen checks actual Flutter widths against UIKit and fails initialization if either differs by more than 0.05 point. Native metadata supplies app version/build, with a generated pubspec fallback. The redesign keeps the existing version 1.1.0 (3); this is a local implementation, not a new signed distribution archive.

## Main implementation map

- `lib/core/theme/holy_typography.dart`, `ios/Runner/AppDelegate.swift`: native typography, specimen, native floating material.
- `lib/core/widgets/holy_ui.dart`, `holy_objects.dart`, `holy_material.dart`, `holy_navigation.dart`, `holy_ruler.dart`: shared environment, surfaces, controls, route, completion, blur, navigation and time rulers.
- `lib/features/landing`, `auth`, `onboarding`: welcome scenes, auth/reset states and twelve-stage setup.
- `lib/features/home`: Learn, presentation adapter, Saved/detail and actual-date calendar.
- `lib/features/lesson`: enhanced/existing readers, measured continuations, shared physics, pause/resume.
- `lib/features/settings`, `support`: preferences, individual editors, account/data and support/legal surfaces.
- `lib/dev`, `tool/preview_main.dart`, `tool/capture_ios_gallery.py`: isolated native QA routes, interactions and capture metadata. These are separate from production `lib/main.dart`.
