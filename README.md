# HolyHer

Women-focused Bible confidence app, package `holyher`, completed in the existing
`/Users/amir/Downloads/HolyHer` folder. v1 contains ten real messages, a three-page
onboarding flow, a hard local paywall, and Today / Journey / Profile tabs.

The app is local-only: no account, server, payment, telemetry, remote fonts, or
runtime network request. The paywall's Start action grants local access; it does
not charge money. Annual is selected by default. Pricing is centralized and
unchanged: **$1.99 for the first 3 months, then $1.99/month or $19.99/year**.

## Run

From this directory, with Flutter and the target platform's development tools installed:

```sh
flutter run
```

For the owner's currently paired iPhone, after Xcode signing is authenticated:

```sh
flutter run --release -d 00008120-000C099A14FBC01E --no-resident
```

A release-mode development installation can open independently of the Flutter
debugger. Device installation requires the existing Codellion LLC Apple
Developer account in Xcode and a valid development provisioning profile. The app
itself needs no account or backend setup. Keep production bundle ID configuration
and store submission separate from this local development installation.

For an iOS simulator, select a simulator in `flutter devices` and use
`flutter run -d <simulator-id>`; no Apple account signing is required.

## Discovery inventory and corrections

The initial project had 15 files: the 13 Dart files below plus `pubspec.yaml` and
`analysis_options.yaml`. It had no native runners, tests, bundled fonts,
lockfile, or Git repository. No alternate app copy was created; Cognein source
was only read for Lexend assets.

| Original file | Role and dependencies | Change |
|---|---|---|
| `pubspec.yaml` | Flutter, Riverpod, SharedPreferences, formerly Google Fonts and intl | Bundle all nine Lexend weights; remove runtime font fetcher and unused intl; no application package added |
| `analysis_options.yaml` | Flutter lints; const/final rules | Preserved |
| `lib/core/constants/app_constants.dart` | Name, tagline, prices; no imports | Fix six Dart pricing errors; centralize summary, notes and Start labels |
| `lib/core/theme/app_theme.dart` | Flutter theme; formerly Google Fonts | Local Lexend and explicit token text colors; keep scrolling app bar white; remove unused accent/button styling |
| `lib/core/widgets/glass_button.dart` | Flutter and theme | One shared accessible action, nullable callback, growing height |
| `lib/data/lessons.dart` | Required eight-field model; no imports | Preserve first five messages, append verified days 6–10; mark future content seam |
| `lib/services/streak_service.dart` | Riverpod; formerly intl and direct preferences | Pure calendar rules, serialized checks, history-first persistence, injected clock/store; same keys and callable APIs |
| `lib/services/progress_service.dart` | Riverpod; lesson catalog and local store | Validate completions, serialize writes, derive next lesson/count/fraction/all-complete from available content |
| `lib/services/paywall_service.dart` | Riverpod and local store | Defensive unlock read, awaited/coalesced unlock, retain legacy key and document real purchase seam |
| `lib/features/landing/landing_screen.dart` | Flutter, constants, theme, glass button, onboarding | Scroll at large text, prevent duplicate pushes, draw existing cross without font fallback |
| `lib/features/onboarding/onboarding_screen.dart` | Flutter/Riverpod, theme, glass button, progress | Preserve three centered pages, allow content scrolling, prevent duplicate Finish |
| `lib/features/paywall/paywall_screen.dart` | Flutter/Riverpod, constants, theme, glass button, paywall | Block route dismissal, responsive plan rows, correct availability claims, await Start, mark restore insertion point |
| `lib/features/home/home_shell.dart` | Flutter/Riverpod, constants/theme, data, lesson/paywall screens, services | Independent access guard, preserved tab state, scrolling tabs, progress count and dynamic unwritten-day note |
| `lib/features/lesson/lesson_screen.dart` | Flutter/Riverpod, theme, glass button, lesson model, progress | Shared Complete action, prevent duplicate completion taps, preserve reading order |
| `lib/main.dart` | Flutter/Riverpod, constants/theme, entry screens and services | Non-blocking runApp, concurrent local bootstrap, app-resume streak checks and observer disposal |

Added source:

- `lib/services/streak_logic.dart`: pure local date parsing, validation, restore,
  and advancement; `StreakState` remains exported through streak service.
- `lib/services/local_store.dart`: injectable raw read/write adapter; only this
  boundary imports SharedPreferences. Failed reads return null; failed writes
  return false; initialization and writes have bounded waits.
- `ios/` and `android/`: Flutter mobile runners, development identifiers,
  HolyHer display name, existing cross launcher icons, white launch themes.
  Android app backup is disabled. Debug signing is for development only.
- `assets/fonts/`: existing Lexend weights plus SIL OFL; original font metadata
  retains copyright notices. No font download is made by the app.
- `pubspec.lock`: resolved reproducible dependencies.
- `test/`: content, pure streak, service, actual preferences-adapter and widget
  tests; fake store allows failures and interrupted-write scenarios.
- `test/fixtures/scripture.json`: independently fetched public-domain source text
  and URLs for all ten quotations; never bundled as runtime app content.
- `tool/verify_scripture.py`: standard-library build-time source retrieval.
- `tool/generate_icons.py`: offline rendering of the existing cross into native
  icons using palette values read from the app theme.
- Flutter-generated metadata and native build configuration complete the runners.

The prompt's claims that the app was already runnable and needed no SDK were
incorrect for this folder: Flutter 3.41.5 / Dart 3.11.3 are installed, while the
native runners were missing. Streak math was inline and used elapsed 24-hour
subtraction; defensive reads, resume checks and the shell access guard were
missing. Several primary actions used a conflicting solid button. These were
corrected while preserving the screen flow and lesson prose.

## Service contracts and storage

Screens use Riverpod providers, never storage packages. New subscribers receive
the current validated state immediately. All service initialization and update
methods return `Future<void>`.

| Owner | Preserved key | Stored type |
|---|---|---|
| Streak | `streak_active_days` | `List<String>` of canonical local YYYY-MM-DD dates |
| Streak | `streak_current` | int; compatibility projection |
| Streak | `streak_longest` | int; best-ever compatibility projection |
| Progress | `progress_completed_days` | `List<String>` of available lesson day numbers |
| Progress | `progress_onboarding_complete` | bool |
| Paywall | `paywall_lifetime_unlocked` | bool; legacy name preserved to retain access |

`initialize()`, `markTodayActive()` and `dayKey(DateTime)` remain supported.
`checkAndUpdateStreak()` is the common update entry point. The clock and storage
can be overridden in tests. `completeDay(int)` and `finishOnboarding()` belong to
progress; `unlock()` and the single access boolean belong to paywall.

Streak history is authoritative. Restore reconstructs the trailing run and best
historical run, keeping any valid larger stored record. An inconsistent current
counter cannot create phantom activity. Invalid history resets cleanly; malformed
progress entries are ignored; invalid booleans default to onboarding/locked.

Writes save history before counter projections; recovery reconstructs counters
from whichever history value survived. This is recovery consistency, not a
transaction or a disk-durability promise. SharedPreferences explicitly does not
guarantee that a completed setter has reached disk:
https://pub.dev/packages/shared_preferences . A storage outage leaves coherent
in-memory session state; relaunch restores only what was actually persisted.

### Streak traces exercised by tests

| Before | Trigger | After |
|---|---|---|
| Empty, current 0 / best 0 | First open Oct 27 | Oct 27 active, 1 / 1 |
| Oct 27 active, 1 / 1 | Three concurrent checks or same-day reopen | One history write total; subsequent checks have no write/event |
| Oct 27 active, 1 / 1 | Open Oct 28 | Both dates retained, 2 / 2 |
| Oct 27–29 active, 3 / 3 | Open Nov 1 | Old history retained, 1 / 3 |
| Oct 29 active | Resume/tab switch just after midnight Oct 30 | 2 / 2, then same-day no-op |
| Best 7 retained, last date Oct 28 | Clock moved back to Oct 26 | No write or state change |
| Local dates adjacent over spring/fall DST | Open next local date | Increment once; no elapsed-hour comparison |
| Duplicate/skipped local travel date | Check | Duplicate unchanged; gap resets to 1 |
| Valid history; obsolete or interrupted counters | Restart after each write boundary | Counters reconstructed from saved history |
| No history; orphan counters or wrong types | Initialize | Clean state, then first activity is 1 / 1 |
| All available lessons complete | Open/resume/tab | Streak remains independent; no fake next lesson |

There is no calendar lock on lessons: Today advances to the first incomplete
available message immediately after completion. Journey supports rereading and
out-of-order opening. Completing an already completed day is a no-op. All counts
use the available list rather than a hardcoded limit.

## Scripture and content audit

All quotations were fetched from BibleGateway's public-domain KJV text before
writing days 6–10 and fetched again afterward. The content test compares exact
wording and punctuation. HTML small-caps LORD is represented as LORD; verse
numbers and presentation whitespace are omitted. No translation words are
modernized or paraphrased. All ten references are unique.

| Day | Title | KJV source |
|---|---|---|
| 1 | You Are Not Facing This Alone | [Deuteronomy 31:6](https://www.biblegateway.com/passage/?search=Deuteronomy+31%3A6&version=KJV) |
| 2 | Held Up by His Right Hand | [Isaiah 41:10](https://www.biblegateway.com/passage/?search=Isaiah+41%3A10&version=KJV) |
| 3 | A Refuge You Can Run To | [Psalm 46:1](https://www.biblegateway.com/passage/?search=Psalm+46%3A1&version=KJV) |
| 4 | If God Is for You | [Romans 8:31](https://www.biblegateway.com/passage/?search=Romans+8%3A31&version=KJV) |
| 5 | His Thoughts Toward You Are Peace | [Jeremiah 29:11](https://www.biblegateway.com/passage/?search=Jeremiah+29%3A11&version=KJV) |
| 6 | Peace Before Things Are Settled | [John 14:27](https://www.biblegateway.com/passage/?search=John+14%3A27&version=KJV) |
| 7 | Strength You Can Receive | [Isaiah 40:31](https://www.biblegateway.com/passage/?search=Isaiah+40%3A31&version=KJV) |
| 8 | Known From the Beginning | [Psalm 139:13–14](https://www.biblegateway.com/passage/?search=Psalm+139%3A13-14&version=KJV) |
| 9 | Light for Your Next Step | [Psalm 119:105](https://www.biblegateway.com/passage/?search=Psalm+119%3A105&version=KJV) |
| 10 | You Can Rest Here | [Matthew 11:28](https://www.biblegateway.com/passage/?search=Matthew+11%3A28&version=KJV) |

Days 6–10 were read back field by field and pass the brief's editorial bar:
one second-person confidence, three verse-grounded reason sentences, two
concrete hope sentences, and one gentle reflection. Their proof frames are,
respectively, Christ's promise of peace, God's promised help, God's personal
creative care, help through His word, and Jesus' promised rest. They stand alone,
follow peace/strength/worth/courage/rest, contain no guilt or guaranteed earthly
outcome, and do not promise a future content delivery date.

## Verification

Run the checks again with:

```sh
flutter analyze
TZ=America/New_York flutter test --concurrency=1
python3 tool/verify_scripture.py
```

Widget tests render QA PNGs in `build/qa/`: landing, onboarding, paywall, Today,
lesson, Journey, Profile, all-complete Journey, and small-phone/large-text views.
These are Flutter test renders, not screenshots from a phone or simulator.
Screens were visually inspected from those renders. Tests cover all ten lessons
at 320dp with 3× text, gate behavior, monthly/annual selection, rereading,
completion persistence, resume/tab triggers, rapid landing taps, corrupt types,
concurrency, interrupted history projections, and a synthetic 365-entry catalog.

Computed contrast ratios (normal text must be at least 4.5:1):

| Foreground | White | Blush | Light pink |
|---|---:|---:|---:|
| Accent | 6.97 | 6.28 | 5.44 |
| Body | 16.29 | 14.68 | 12.71 |
| Secondary | 8.00 | 7.22 | 6.24 |

White on accent is 6.97:1. Flame is icon-only, 32dp, 3.92:1 on white and 3.53:1
on blush. Screen colors use theme tokens. Runtime source contains no HTTP client,
remote images/fonts, Firebase/RevenueCat initialization, live credentials,
tracking SDK, personal-data logs, obsolete pricing or stale package imports.
The Python verifier uses the network only when explicitly run during content QA;
it is not shipped or called by the app.

### Native proof and limits

Final automated checks on October 29, 2026: **flutter analyze: no issues;
flutter test: all 21 tests passed**, with America/New_York as the test timezone.

- `flutter build ios --release --no-codesign`: succeeded, producing a 15.5 MB
  `build/ios/iphoneos/Runner.app`. An unsigned build cannot be installed on a phone.
- Signed iPhone release installation was attempted. Initially Xcode reported
  `No Accounts` and no development profile for `com.example.holyher`.
  After the owner authenticated the existing account, the signed release build
  succeeded. Flutter's combined installation/launch step still returned an
  error, so installation and launch were performed directly with Xcode tools:

  ```sh
  xcrun devicectl device install app --device 79D1760F-3CCF-5595-874B-46E260F41DCD build/ios/iphoneos/Runner.app
  xcrun devicectl device process launch --device 79D1760F-3CCF-5595-874B-46E260F41DCD com.example.holyher
  ```

  Both commands succeeded: HolyHer was installed and launched on the owner's
  iPhone 14 Pro Max. The release signature was checked with
  `codesign --verify --deep --strict`; its development profile belongs to
  Codellion LLC and expires October 29, 2027. This is a development deployment,
  with `com.example.holyher`; it is not an App Store release.
- Android debug build was attempted and failed during Gradle Kotlin JAR
  transformation while the Mac was nearly full; test compilation also explicitly
  reported `No space left on device`. Tests were successfully rerun after space
  recovered. Android native verification was deferred at the owner's request.
- An isolated `holyher_pixel` Android AVD was created with the existing API 34
  image; it was not launched. Existing Cognein emulator data was not changed.
- No simulator app run or phone offline/restart acceptance is claimed by the
  widget tests. Installation and OS launch succeeded; the owner's on-phone
  interaction was requested separately. The owner confirmed that onboarding,
  local Start, opening/completing a lesson, and closing/reopening work on the
  iPhone. Airplane-mode operation was not separately confirmed.
- iOS preferences are app-local; ordinary OS device backups are outside the
  app's cloud-sync behavior. Cleared-data tests use absent local preferences.

## Exactly two future seams

1. **Days 11–365 content:** append verified entries to `lib/data/lessons.dart`.
   Journey derives its non-tappable unwritten range from available content and
   `AppConstants.totalDays`. Do not pad the list with invented entries.
2. **Ship-time integrations:** replace storage behind the service contracts with
   the separate new Firebase project; replace local purchase access with
   RevenueCat's monthly/annual products and entitlement check; add real Restore
   Purchases at the marked paywall insertion point. Production identity
   `com.holyher.app`, release signing, listings under Codellion LLC, and the
   owner's domain registration remain ship-time work.

No domain, subscription, developer account, Firebase project, RevenueCat product,
or store listing was bought or created. Cognein was not modified. The owner
confirmed the installed iPhone flow works. Product success remains the owner's
subsequent evaluation.
