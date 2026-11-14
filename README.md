# HolyHim

A daily Scripture walk for young men on iPhone. One short lesson a day
(Scripture, what it means, what it asks of you, a prayer), then hold "Amen".
Streaks with grace days, medallions, saved verses, home-screen widgets and
reminders. Days 1 to 7 are free; the rest of the year is one $1.99 purchase.

Version **1.0.0 (1)**, in development on `redesign/v2`. Nothing has been
pushed, deployed or uploaded for HolyHim yet. Release steps and their status
live in [docs/RELEASE.md](docs/RELEASE.md).

## What is in the app

- **Walk**: today's lesson on its photograph, then the whole road: 73 chapters,
  each lesson a 3D coin on a winding brass path, milestones beside it and
  Back to today.
- **Brothers**: a community after Cognein's, with words, prayer requests and
  wins, Amens, replies, sorting, report and block. Joining means agreeing to
  the rules; the server moderates every post, reply and name
  (`functions/community.js`, patterns in `functions/moderation.json`, shared
  with the app). Owner tooling: `tool/moderation.py`.
- **Ranks**: the board by streak or days read, with the crowned podium.
- **Growth**: streak ring, next medallion, the month, every medallion as a coin
  you can spin, and the road so far.
- **Profile**: photo, numbers, next milestone and every setting.
- Five tabs swipe left and right without end under Cognein's liquid glass:
  the native iOS 26 tab bar, or the refracting minimizing bar elsewhere.

## How HolyHim relates to HolyHer

HolyHim runs on HolyHer's engine (`/Users/amir/Downloads/HolyHer`) with its
own brand, lessons, art, store listing and cloud identity.

- `python3 tool/sync_upstream.py` reads a committed HolyHer revision (never its
  uncommitted work, never writing to it), renames it, swaps HolyHer's
  Firebase, Google and RevenueCat identifiers for HolyHim's (read from
  `config/` and `ios/Runner/GoogleService-Info.plist`), and commits it to
  `upstream/holyher-renamed`.
- Merge that branch into `redesign/v2`, then rerun the generators below.
- HolyHim owns `content/`, `art/`, `assets/art/`, `assets/brand/`, `config/`,
  `store/`, `public/`, `docs/`, app icons and launch images, and the files
  generated from them. A sync never writes those paths (see `OWNED` in the
  script). The brand layer lives in `lib/design/themes.dart`,
  `lib/design/typography.dart`, `lib/design/tokens.dart` and screen copy.

The Nov 10 renamed copy is preserved on `archive/nov10-rename`. HolyHer's
history before the split (`snapshot/walk-v1`, `master`) is kept unchanged.

## Run and verify

Flutter 3.41+ / Dart 3.11+, Xcode 26, Node 22+.

```sh
flutter pub get
flutter analyze
TZ=America/New_York flutter test
python3 tool/verify_lessons.py
python3 tool/build_lessons.py --check
python3 tool/verify_scripture.py
python3 -m unittest discover -s tool/tests -v
python3 -m unittest discover -s tool/art -p 'test_*.py' -v
(cd functions && node --test test)
```

Generators, after content, art or a sync merge changes:

```sh
python3 tool/build_lessons.py          # lessons.g.dart, widget verses, fixtures
python3 tool/art/package_chapters.py   # chapter catalog
```

Rules tests need the local emulator:

```sh
JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home \
PATH=/opt/homebrew/opt/openjdk@21/bin:$PATH \
env -u DEBUG firebase emulators:exec --project demo-holyhim \
  --config firebase.emulators.json --only firestore,storage 'node --test functions/test'
```

Screens render to PNG without a device: `flutter test tool/render/screens_test.dart`
writes to `build/render/screens/`. Device runs use the paired iPhone over the
local network only: `python3 tool/run_iphone.py --help`.

## Content

`content/lessons_v2.json` is the single source for all 365 lessons, written in
the voice described in `content/STYLE.md`. Scripture is the World English
Bible, checked against the pinned corpus in `tool/scripture/`.
