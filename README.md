# HolyHer — Walk with God

HolyHer is a free 365-day Scripture journey for iPhone, iPad, and the shared Flutter web app. Version **1.2.0 (4)** replaces the lesson interaction with five reading-only cards: Scripture, Meaning, Encouragement, Hope, and Prayer. Titles, sequence, references, verified WEB quotations, existing account data, and edition access are preserved.

The production onboarding rules repair and compatible reading endpoints are deployed. The redesigned clients and Firebase public website are staged locally. **This release is not yet ready for distribution.** See [current implementation and remaining acceptance checks](store/WALK_WITH_GOD_STATUS.md), the [visual gallery](store/walk-redesign/index.html), and the [content review](store/WALK_CONTENT_REVIEW.md).

## Run and verify

```sh
flutter pub get
flutter analyze
TZ=America/New_York flutter test --concurrency=1
node --test functions/test/domain.test.js
python3 tool/build_readings.py --check
python3 tool/verify_scripture.py
python3 tool/build_web.py
python3 tool/preview_public.py
```

The local website is available at `http://127.0.0.1:4173/`; authenticated reading uses `/app/`. Web build output is reproducible and ignored by Git. The app uses bundled Manrope and Source Serif 4. Native account storage remains SQLite; the browser uses account-scoped transactional IndexedDB with concurrent-tab and deletion protection.

## Artwork

```sh
python3 tool/generate_artwork.py --dry-run --days 1-365
```

Live generation requires `GEMINI_API_KEY` outside the repository and a reviewed reference image passed with `--reference`. The manifest currently contains 365 planned compositions and no generated assets. Until generated images are reviewed and packaged, screens display the botanical theme fallback. See `python3 tool/generate_artwork.py --help` and `python3 tool/prepare_artwork_assets.py --help`.

## Release

Bundle: `com.holyher.app`; Apple team: `DU9D6TAM58`; Firebase project: `holyher-app-production`. The requested release target remains November 15, 2026 at 06:00 America/New_York. This date is a target, not an App Store release schedule. No new App Store upload or submission has been made.

[Historical build-1 and earlier rebuild notes](store/HISTORICAL_README_PRE_WALK.md) are retained for provenance and do not describe the current release.
