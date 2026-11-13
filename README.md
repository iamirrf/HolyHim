# HolyHim 2.0

A Scripture walk for iPhone and iPad. Four daily screens,
eight live themes, saved verse images, streaks with grace days, and nineteen
milestones. Version **2.0.0 (6)**. This checkout is a release candidate in progress;
see [the current redesign audit](store/redesign-v3/DELIVERY.md) for verified work and remaining gates.

The original tree is committed at `snapshot/walk-v1` (`a07b5bc`). Implementation
is on `redesign/v2`. The compatible Firebase backend was deployed with explicit approval on November 5. Nothing has been pushed or uploaded to the App Store.

## Run and verify

Use Flutter 3.41+ / Dart 3.11+, Xcode 26 and Node 22+.

```sh
flutter pub get
flutter analyze
TZ=America/New_York flutter test
python3 tool/verify_lessons.py
python3 tool/build_lessons.py --check
python3 tool/verify_scripture.py
python3 -m unittest discover -s tool/tests -v
python3 -m unittest discover -s tool/art -p 'test_*.py' -v
node --test functions/test
```

Rules tests intentionally require a local demo project. On this Mac:

```sh
JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home \
PATH=/opt/homebrew/opt/openjdk@21/bin:$PATH \
env -u DEBUG firebase emulators:exec --project demo-holyhim \
  --config firebase.emulators.json --only firestore,storage 'node --test functions/test'
```

```sh
python3 tool/build_web.py
python3 tool/preview_public.py
python3 tool/run_iphone.py --help
```

The marketing pages live in `public/`; the Flutter web app builds to `public/app/`.
The web service worker caches public shell/art files only. Firestore owns account
cloud synchronization. An account-scoped device snapshot preserves unfinished onboarding, themes, completed lessons and pending field edits across restarts.

For a Firebase-free visual fixture build, use `flutter run -t tool/v2_preview.dart`.
Its real screens use an isolated local test account. This is a separate entrypoint;
production `lib/main.dart` has no preview sign-in bypass.

## Data and content

- `lib/domain/`: calendar pacing, DST/travel handling, derived streak/grace engine,
  badge thresholds, notification plan, custom-scheme routing and completion receipt.
- `lib/services/repository.dart`: optimistic field merges, durable device snapshots, schema 6
  profile and walk documents. UI actions never await server acknowledgment.
- `lib/services/migration.dart`: background v1 profile, completion and saved migration.
- `functions/`: account deletion, support, verified lifetime-access reconciliation,
  RevenueCat webhook and replaced-avatar cleanup. Prepared owner-only rules accept
  compatible v5/v6 profiles and legacy migrations. Production deployment is separate.
- `content/lessons_v2.json`: sole runtime catalog source; `content/STYLE.md` is the
  voice guide. `content/v2-editorial-status.json` distinguishes fresh writing from
  working adaptations. Mechanical validation is separate from editorial approval.
- `tool/scripture/`: pinned public-domain WEB corpus. The independent XML verifier
  checks all 38,058 cached verses and the exact 365 lesson quotations.

The design framework ports the owner's Cognein and SunRize code. Source paths and
hashes are recorded in `store/v2-design-ports.json`. Playfair Display, Lora, Manrope
Dancing Script and Pinyon Script are bundled with their OFL licenses.

## Artwork and release

The built-in image-generation workflow produced 25 coordinated Christian photos
and 19 transparent 3D badges. Originals, prompt specifications and hashes live in
`art/`; optimized runtime assets and thumbnails live in `assets/art/`.
`tool/art/package_redesign.py` builds the shared 365-day artwork mapping.
Review [photos](store/redesign-v3/library-review.jpg) and
[badges](store/redesign-v3/badges-review.jpg).
The WidgetKit extension uses `group.com.holyhim.app`. App Group registration, embedding and
signing are complete and verified on the real iPhone. See `ios/HolyHimWidget/README.md`.

The compatible rules and six named functions were deployed with explicit approval.
Hosting publication, pushing and App Store upload still require approval; see
`store/redesign-v3/DELIVERY.md` for current verification gates.
Do not run old v1 deployment/acceptance scripts against this v2 checkout.
