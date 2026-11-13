# Verification ledger

This ledger describes local evidence for the native redesign. It is not a production deployment or an App Store acceptance report.

## Automated checks

- `flutter-tests-final.txt`: full Flutter suite, 90 passing at the recorded run. Includes migration, release/calendar behavior, reading continuation/reflow, quiz identity/locking, local persistence failures, account isolation, synchronization and navigation retention/reselection.
- `presentation-semantics-tests-final.txt`: two focused checks also included in the full suite pass: ambient motion does not rebuild its screen child, and Saved overflow remains independently accessible.
- `presentation_layout_test.dart`: every main screen family is exercised in six logical layouts at text scales 1.0, 1.3, 2.0. Test rendering proves layout/error behavior; native captures provide separate font evidence.
- `analyze-final.txt`: Flutter static analysis, no issues at the recorded run.
- `backend-tests-final.txt`: 31 Node tests pass, including actual completion dates, retries/revisits and reset, canonical grading, retained free access and deletion races.
- `firestore-tests-2.txt`: five Firestore emulator integration tests pass, including v3 semantic-stage/profile validation and invalid-state rejection.
- `native-sqlite-final.txt`: the shipped Darwin sqflite driver successfully configures and makes its first durable write.
- `scripture-verification.txt`: 365 lessons, 371 quoted verses and the 38,058-verse cache checked against the pinned Scripture source.
- `teaching-build.txt`, `teaching-slice.txt`: the authored five-lesson enhanced slice is consistent. This is **not** a full enhanced-catalog gate. The 360 other lessons remain in their existing five-card format.
- `build-info-check.txt`: generated fallback build metadata agrees with pubspec.

`contrast-report.json` measures palette foregrounds against composited native screenshot samples: body >13:1, secondary >5:1, and sampled white action labels >5:1. This is representative coverage, not an exhaustive contrast audit.

## Native typography

`gallery/font--E0F7AB65--s1.json` records UIKit's actual `.AppleSystemUIFontRounded-Regular` and `.AppleSystemUIFontRounded-Semibold`, the native family, resolved weight variation, actual Flutter measurements, version and build. At 22 points the regular sample differs by 0.0 point; semibold differs by approximately 0.000014 point. `gallery/native-rounded-specimen.png` is drawn by UIKit. The adjacent font route is drawn by Flutter. Runtime initialization rejects a mismatch larger than 0.05 point.

The adapter loads system tables only in memory. No copied Apple font file is included in the app's assets. The specimen proves the measured two-weight sample on the captured OS; it does not substitute for every glyph/language/device check.

## Gallery and motion

Open `gallery/index.html`. Each capture has a sidecar JSON with its route, logical and pixel dimensions, actual pixel ratio, text scale, Reduce Motion setting, installed application code hash and automation events. All routes use `lib/dev/preview_fixtures.dart` and `tool/preview_main.dart`; Firebase is not initialized and no real account data is loaded. Contact submission states use an injected local transport.

Still images use a stable Reduced Motion phase for comparison. The native gallery currently covers 375 × 667, 393 × 852, 430 × 932 and iPad 1024 × 1366, with representative native text scales 1.0, 1.3 and 2.0. Full-route capture, native landscape/split coverage and motion recordings were not completed before the user requested removal of the simulator previews and direct installation on their iPhone.

Requested landscape captures that retained portrait geometry were rejected and removed from the gallery. The hosted narrow-viewport attempt did not reach ready and is not presented as evidence. Landscape and narrow layouts have separate passing Flutter layout tests, which do not establish native OS Split View behavior. No full native-motion parity claim is made.

`gallery-audit.json` records geometry, specimen and launch-frame checks. Human review is still needed for composition, gestures, VoiceOver and transient system overlays. The screenshots are not golden-test simulations.

## Remaining release gates

1. The user connected their iPhone 14 Pro Max and requested direct installation in the actual HolyHim app. The actual `lib/main.dart` profile-mode build is signed and installed into `com.holyhim.app`; no separate preview app was installed. `native-phone-build-fixed.txt`, `phone-install-fixed.json` and `phone-launch-fixed.txt` record the corrected build/install/startup. The first physical run exposed read-only CoreText table mutation; the bridge now makes writable copies before adaptation. The iPad remains unavailable. The corrected process stayed alive and Firebase bootstrap created its heartbeat after the native font guard, confirming the actual entry point passed typography initialization. A 20-second Instruments Animation Hitches recording was attempted, but export failed after its temporary kernel trace exhausted local disk space; the generated trace was removed and disk space recovered. No device frame-pacing pass is claimed. The user confirmed that Welcome or their journey is visible on the physical iPhone after the fix. Physical gesture feel, VoiceOver and energy behavior remain unverified.
2. Verify VoiceOver focus order, announcements and nested actions on device. Automated semantics checks cover selected controls, not a full VoiceOver session.
3. Exercise actual OS Split View, rotation during a lesson, notification permission transitions and scheduling, password-manager/autofill behavior, Apple/Google cancellation/recovery, silent-switch audio and native sharing on connected devices.
4. Run authorized live-account cloud convergence, sign-out, reset/export/deletion and retained-access acceptance against the compatible backend. Local domain/emulator tests are not proof of those production flows.
5. Deploy reviewed v3-compatible rules/functions only as a separately authorized release before live-account distribution. No deployment or store submission occurred here.
6. Full authenticated Cognein screen/motion comparison remains incomplete. The actual reference welcome and original setup/lesson-surface specimens are rendered; no complete visual parity claim is made.

See `REVIEW.md` for visible defects and the revisions they produced, and `MIGRATION.md` for schema and release dependencies.


## Second design pass — current evidence

- `iteration-two-analyze.txt`: no analyzer issues.
- `iteration-two-tests.txt`: **94 tests passed**, including the failed five-card completion/position regression, late-journey reveal at 1×/2× text, accessibility tab activation and the complete screen-family reflow matrix. The 320×568 / 3× text case also passes.
- `iteration-two-content-integrity.json`: lesson data, teaching JSON and unit JSON match the original dirty worktree hashes exactly.
- `review-renders/index.html`: current composition review across a short phone, the physical phone's logical dimensions, iPad portrait/landscape and a narrow split-sized column. Large-text examples are included. These are **offscreen Flutter frames using macOS rounded system tables in memory**, not native iOS evidence.
- `iteration-two-device-build-final.txt`: signed physical-device profile build of actual `lib/main.dart`, successful. `codesign --verify --deep --strict` passes. `iteration-two-build-manifest.json` records source and binary hashes.
- `iteration-two-phone-install.json`: installed successfully into the user's existing `com.holyhim.app`. No separate app, account reset, production deployment or App Store submission occurred.
- `iteration-two-phone-open.txt`: iOS rejected foreground launch with `Locked`. The revised build's **physical screenshot and interaction review remains pending** until the user unlocks the phone. The currently connected iPad remains unavailable.
- `tool/capture_phone_gallery.py` can capture the exact installed production widgets using explicit non-release fixture arguments and Xcode's physical-device screenshot button. Each state uses a unique readiness nonce. It restores ordinary HolyHim after the batch. It never initializes Firebase or reads the actual account in the fixture branch.
- Bounded `FrameTiming` capture is prepared for representative interactions; no physical performance pass is claimed without the resulting samples. Manual finger feel and VoiceOver traversal remain open checks.
- Xcode's unused caches and simulator build products were removed. One required runtime was restored after discovering that this Xcode installation needs it even for physical builds; its regenerated 3 GB dyld cache was removed using the supported `simctl` command. Approximately 7 GB was free afterward. See `xcode-cleanup.json` for scope. Projects, current iPhone symbols, signing assets and archives were preserved.

The earlier simulator gallery is historical first-pass evidence. It does not prove the revised UI. Existing backend, native storage, Scripture and five-day teaching verification results remain relevant because this pass preserved those contents and services. The production V3 profile/rules release remains a separately scoped deployment; no live deployment is implied by this local redesign.
