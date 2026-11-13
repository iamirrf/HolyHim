# HolyHim v2 native verification

Updated November 4, 2026 (America/New_York).

The production `Runner` app compiled successfully for the arm64 iOS 26.5 simulator on November 3. The full build included AppDelegate, plugin registration and the embedded WidgetKit extension. `/tmp/holyhim-v2-production-build.log` ends with `BUILD SUCCEEDED`. The separate WidgetKit target also compiled successfully (`/tmp/holyhim-widget-build.log`). The Foundation widget tests passed JSON decoding, exact unlock gating, missing-future-content fallback, art reset and both New York DST midnights.

The verified production simulator app is at:

```
/Users/amir/Library/Developer/Xcode/DerivedData/Runner-akyrqaaehdemvwfndqgdfofpnrtl/Build/Products/Debug-iphonesimulator/Runner.app
```

A standalone `HolyHimVisualQA` target/scheme and `tool/v2_preview.dart` provide real app widgets with local sample progress and no Firebase initialization. The separate QA native build was interrupted when free space dropped to 159 MiB; this is not a successful QA-target compile. Only task-generated intermediates and the session-created SE simulator were removed to reclaim space. Existing archives, signing material and user simulator data were preserved.

Actual iPhone 17 Pro captures were then made by cloning the verified production debug app, replacing the clone's debug Flutter assets with the fixture bundle, changing the clone bundle identifier to `com.holyhim.app.qa`, and ad-hoc signing the clone. The original production app was not changed. The iOS 26 runtime logged the native tab bar. The fixture control runs only in the Dart debug service and is not a production auth bypass.

Reviewed captures in `store/v2-gallery/`:

- `iphone17pro-blush-walk.png`: native 1206 × 2622 capture of the Walk screen with sample Mira / Day 7 progress. Fonts, Today card and native capsule render without an observed overflow. This image also replaces `public/images/walk-screen.png`.
- `iphone17pro-blush-path.png`: native capture of the scrolled Walk path, showing completed/current/locked nodes and the minimized native capsule.
- `iphone17pro-initial.png`: initial native launch frame, before the first Flutter frame.

The misleading temporary image from the URL-confirmation driver setup was removed. Midnight Rose, SE/compact, iPad and a full route contact sheet were not completed. No simulator performance result is presented as device profile FPS. Physical sign-in, haptics, notification delivery/taps, widget placement and Apple provisioning remain device verification gates.

Native QA was stopped on the user's November 4 instruction to prioritize a wireless physical-iPhone launch and reclaim Xcode storage. The fixture app and Flutter attachment were terminated, and the only simulator booted by this pass was shut down. Root owns the physical-device launch and further cache cleanup. No deployment, push, App Store upload or Apple-account capability mutation occurred in this pass.

An older development-signed physical-device app remains at `build/ios/iphoneos/Runner.app` (Apple Development signature from November 1, team DU9D6TAM58). It is an older build, not the new v2 simulator executable. Older development artifacts also remain under `build/ios/development/`; they were not rebuilt or deleted.
