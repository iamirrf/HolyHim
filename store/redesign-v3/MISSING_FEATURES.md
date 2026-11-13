# Remaining acceptance gaps — November 5, 2026

The requested app flows, lesson catalog, generated artwork, photo persistence, themes, dismissible lifetime paywall, independent daily verse, notifications and widget extension are implemented. This audit separates implemented functionality from physical acceptance work still needed before release.

| Gap | Current evidence | Work still needed |
|---|---|---|
| Exact native visual comparison | 29 actual-widget raster captures, reference component/source checklist; signed physical build runs | Capture and compare real iPhone screens, native liquid glass and every loading/error/selected state. No claim of pixel-exact parity yet. |
| Swipe, animation and accessibility acceptance | Swipe regression, cancelled/completed Amen tests, reduced-motion and 200% text tests pass | Measure Profile-mode frame times; inspect haptics, sound, VoiceOver, native keyboard, transparency and photo crop gestures on the phone. |
| StoreKit transaction acceptance | SDK adapter fixtures and live server access checks pass; testing exit works without ownership | Perform actual sandbox purchase, cancellation, pending/restore and account-isolation checks. No purchase has been performed. |
| OS widget and reminder acceptance | Embedded/signed extension; real App Group palette and daily verse match; calendar/DST/travel tests pass | Place widgets on Home and Lock Screen; check OS midnight refresh and cold/warm notification/widget taps across authentication. |
| Published release surfaces | Updated offline legal text and prepared store copy | Hosting/marketing and App Store publication remain separate approved actions. The hard paywall stays disabled pending launch approval. |

The final development build is installed in place and foreground-launched on Amir’s real iPhone using `transportType: localNetwork`; data was preserved. Its real account cache retains completed onboarding, the theme and lesson progress, with zero pending profile fields. Firebase is deployed and all fifteen isolated live checks pass.

Apple’s UI-test service still reports **Device is busy (Preparing Amir’s iPhone)** after a successful foreground launch. Earlier attempts also failed the secure `com.apple.mobile.notification_proxy` connection. The next device recovery step is to restart and unlock the iPhone, keep it awake, then retry the read-only `HolyHimDeviceReview` target. No simulator or phone-data deletion was used.

The obsolete onboarding promise and test lesson were deliberately removed. The paywall close button and temporary testing access are deliberate development behavior. Retained access grants and legacy promise recognition remain preserved.
