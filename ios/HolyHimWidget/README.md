# HolyHim Verse of the Day widget

Small, medium and Lock Screen rectangular widgets use the same independent daily verse as the app: local Gregorian calendar days since January 1, 2026, rotating through the 365 verified verses. Completing a lesson never changes the verse. Taps open `holyhim://verse/{displayed-day}`.

Runner embeds the extension and both targets declare `group.com.holyhim.app`, automatic signing and version 2.0.0 (6). Runner supports iOS 15; the extension requires iOS 16. The App Group receives theme colors, reading state and optional cached artwork. The extension bundles the complete verified verse catalog and all 25 artwork thumbnails, so midnight rotation does not require a network connection or a recent app launch.

The timeline contains eight entries, beginning with the current verse and continuing at calendar-based midnights. Device-local calendar arithmetic handles DST and travel, using the current system time zone even before the containing app reopens. WidgetKit controls actual refresh timing. Sign-out clears the account payload and returns to the default HolyHim presentation. No account credentials are sent to the extension.

Foundation verification (no simulator):

```sh
xcrun swiftc ios/HolyHimWidget/HolyHimWidgetData.swift ios/HolyHimWidget/Tests/WidgetDataTests.swift -o /tmp/holyhim-widget-data-tests
/tmp/holyhim-widget-data-tests
```

Compile using the shared physical-device build directory:

```sh
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Profile -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build/ios/device CODE_SIGNING_ALLOWED=NO build
```

The unsigned build passes. Wireless installation requires Xcode's signed-in Codellion LLC developer account and provisioning profiles containing the App Group for both bundle IDs (`com.holyhim.app`, `com.holyhim.app.widget`). Only a real iPhone over `transportType: localNetwork` is authorized for installation and visual verification.
