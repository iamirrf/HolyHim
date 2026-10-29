# HolyHer v1 delivery — October 29, 2026

## What was built

HolyHer is implemented in its original folder, signed with the existing Codellion
LLC development identity, installed, and launched on the owner's iPhone 14 Pro
Max. The owner confirmed the complete onboarding → local Start → lesson →
Complete → close/reopen flow works. v1 includes ten messages, Today/Journey/Profile,
local streak/progress/access persistence, bundled Lexend, the locked light theme,
and iOS/Android runners. It uses no app account, backend, real payment, analytics,
or runtime font/content requests. All original lesson prose and storage keys
were preserved. The complete changed-file inventory, service contracts and
original discrepancies are recorded in [README.md](README.md).

Actually run and passed: `flutter analyze` (no issues), `flutter test
--concurrency=1` under America/New_York (21 tests), scripture retrieval/comparison,
contrast calculations, static source audit, unsigned iOS release compilation,
signed iPhone release compilation, signature verification, direct device
installation and OS launch. Flutter's combined run command returned an
installation/launch error after building; explicit `devicectl` install and launch
both succeeded. On-phone acceptance is the owner's confirmation, not an automated
claim of watching or controlling the phone UI.

## The 10 lessons

Each reference links to its verification source. All quotations are public-domain
KJV, verified word for word including punctuation before and after writing;
source display small-caps LORD is retained as LORD. All references are unique.

1. **You Are Not Facing This Alone** — [Deuteronomy 31:6](https://www.biblegateway.com/passage/?search=Deuteronomy+31%3A6&version=KJV).
2. **Held Up by His Right Hand** — [Isaiah 41:10](https://www.biblegateway.com/passage/?search=Isaiah+41%3A10&version=KJV).
3. **A Refuge You Can Run To** — [Psalm 46:1](https://www.biblegateway.com/passage/?search=Psalm+46%3A1&version=KJV).
4. **If God Is for You** — [Romans 8:31](https://www.biblegateway.com/passage/?search=Romans+8%3A31&version=KJV).
5. **His Thoughts Toward You Are Peace** — [Jeremiah 29:11](https://www.biblegateway.com/passage/?search=Jeremiah+29%3A11&version=KJV).
6. **Peace Before Things Are Settled** — [John 14:27](https://www.biblegateway.com/passage/?search=John+14%3A27&version=KJV). Content bar and field-by-field read-back quality gate passed; promise of peace amid a current worry.
7. **Strength You Can Receive** — [Isaiah 40:31](https://www.biblegateway.com/passage/?search=Isaiah+40%3A31&version=KJV). Content bar and quality gate passed; promised help for ordinary tired tasks.
8. **Known From the Beginning** — [Psalm 139:13–14](https://www.biblegateway.com/passage/?search=Psalm+139%3A13-14&version=KJV). Content bar and quality gate passed; personal creative care before achievement or approval.
9. **Light for Your Next Step** — [Psalm 119:105](https://www.biblegateway.com/passage/?search=Psalm+119%3A105&version=KJV). Content bar and quality gate passed; help through God's word for one concrete next step.
10. **You Can Rest Here** — [Matthew 11:28](https://www.biblegateway.com/passage/?search=Matthew+11%3A28&version=KJV). Content bar and quality gate passed; Jesus' promised rest with unfinished tasks.

## How to run it

Open **HolyHer** on the iPhone; the installed release build can run without the
Flutter debugger. For development from the Mac:

```sh
cd /Users/amir/Downloads/HolyHer
flutter run
```

Flutter plus the target platform tools are prerequisites. An iOS device install
also requires the existing authenticated developer account and provisioning; those
were used successfully for this installation. The app itself needs no account,
server, purchase, or backend configuration. README contains the exact device
build/install commands and the signed development profile's expiry.

## The two declared future seams

1. **Days 11–365:** not written or fabricated. Append verified entries to the
   existing lesson list. Counts and progress derive from available content;
   Journey's unwritten-day note is non-tappable.
2. **Ship-time integrations:** RevenueCat monthly/annual products, valid
   entitlement handling, real Restore Purchases, the separate Firebase project,
   production `com.holyher.app` identity, production signing and store listings
   under Codellion LLC. The development install uses `com.example.holyher`.
   Store work and the owner's domain registration remain deferred.

## What could not be verified

- Android's debug build failed during Gradle Kotlin JAR transformation while the
  Mac was nearly full. An automated test compilation also explicitly failed with
  `No space left on device`. Android build/emulator verification was deferred at
  the owner's request; there is no verified APK or Android device run.
- No iOS simulator app run was completed. The physical iPhone installation and
  owner-confirmed flow provide the native iOS proof instead.
- Airplane-mode first launch and exhaustive visual/accessibility testing on the
  physical phone were not separately confirmed. Code has no runtime network
  dependency; widget renders were inspected and all lessons tested at 320dp/3×.
- DST, timezone/backwards dates, concurrent triggers, corruption, and interrupted
  write boundaries were tested with controlled state rather than changing the
  owner's device clock or forcibly killing it during a preference write.
- SharedPreferences does not guarantee disk durability after a setter returns.
  Recovery reconstructs consistent counters from saved history; abrupt OS/disk
  failures can still lose the latest unflushed value. This required-storage limit
  is documented rather than presented as an atomic transaction guarantee.

## Confirmation

The v1 implementation is complete and installed; the owner confirmed the iPhone
flow works. Android native verification remains open as stated above. No purchase,
domain registration, new account, Firebase project, RevenueCat product, or store
listing was performed. Product success remains the owner's subsequent evaluation.
