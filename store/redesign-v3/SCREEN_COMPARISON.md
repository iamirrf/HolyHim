> November 5 device update: the signed full build is installed and running on Amir’s iPhone over localNetwork. Shared App Group data on the phone matches the daily verse and palette. Native UI screenshot automation is currently blocked by Xcode’s secure device-preparation service; gallery images remain raster captures. Live persistence and photo cleanup now pass fifteen checks after the approved deployment.

# Screen comparison record

Reference checkouts: Cognein `/Users/amir/Downloads/evolve.ai` at `633680c84cec9a1b509f5092e8e2129562a6e047`; SunRize `/Users/amir/Downloads/Business/SunRize/code`. Source geometry is recorded in `store/v2-design-ports.json` and the additional hashes in this directory. Colors, copy, Christian artwork and readable HolyHim reading fonts are adapted. Dancing Script bold is bundled for the dark-pink wordmark.

The gallery contains raster captures of real Flutter widgets at 393×852 points, using actual bundled fonts and artwork. It is a layout review, **not an iPhone screenshot or proof of native liquid glass, haptics, smoothness or pixel-exact parity**. Widget tests use the portable glass rendering path. Earlier reference captures are available in `store/pearl-redesign/reference/`.

| Surface | Reference composition carried across | State evidence | Device comparison |
|---|---|---|---|
| Welcome | Three scenes, pagination, script wordmark, equal-width provider/email controls | Normal capture; 200% small-screen/Reduced Motion test | Installed; UI review pending |
| Email sign-in / sign-up | SunRize full-screen form, keyboard branding, glass fields, password visibility, confirmation, reset, back/mode controls | Both form captures; inline validation paths | Native keyboard and provider auth pending |
| 1 Name | First/optional-last fields, reference spacing and progress pills | Capture; draft writes; full-flow and large-text test | Pending |
| 2 Birthday | Cognein month/day/year ruler mechanics and fling limits | Capture; full flow | Physical ruler haptics pending |
| 3 Life season | Searchable context-choice layout | Capture; selection/full-flow test | Pending |
| 4 Faith routine | Reference four-choice hierarchy | Capture; full-flow test | Pending |
| 5 Discovery guide | HolyHim Guide question/answer bubbles, choice counts, typing, editing | Capture; complete-flow and answer-rewind/stale/retry tests | Native keyboard/typing comparison pending |
| 6 Routine preview | Planned-time curve; no predicted spiritual outcomes | Capture; zero-motion completion regression | Animation comparison pending |
| 7 Outcomes | Eight choices, maximum three selected | Capture; full-flow test | Pending |
| 8 Daily rhythm guide | Pace, reminder time and intention | Capture; full flow; permission timeout | Native permission prompt review pending |
| 9 Profile setup | Avatar, optional display name, notifications, terms | Capture; full flow | Photo picker and crop gestures pending |
| 10 Save / plan summary | Real durable-save result and personalized summary | Capture; local save/error handling; no sample lesson | Live create/rename/resume persistence verified |
| 11 Lifetime paywall | Personalized benefits, previews, one lifetime price, CTA, restore and legal links | Unavailable capture; localized SDK fixture, cancel/pending/restore/account-isolation tests; testing exit | StoreKit sandbox pending |
| Walk / floating bars | Cognein tab controls and retained pages; no full-width edge material | Gallery; route/tab/gesture regression | Native glass and frame times pending |
| Saved | Search/action hierarchy, image-backed verse cards, empty state | Populated/empty captures; undo/account-isolation/large-text tests | Pending |
| Growth / calendar / badges | Streak focus, calendar, milestones and 3D keepsakes | Populated/empty captures; domain/accessibility tests; artwork contact sheet | Calendar tap/scroll comparison pending |
| Profile | Identity card, three statistics, milestone, preferences/support/sign-out groups | Capture; name-edit/persistence/large-text tests | Pending |
| Theme | SunRize full-width gradient swatches and selected ring | Capture; instant state updates, persistent cache/account tests | Real App Group palette verified; visual restoration pending |
| Photo edit / crop | Cognein drag/pinch crop, 512px JPEG, preview/replace/remove | Edit capture; removal semantics and owner/storage/cleanup tests | Native selection, pinch and drag pending |
| Scripture → Meaning → Reflection | Exactly three learning cards and Cognein swipe deck | Three captures; four-card navigation regression | Card spring/gesture profiling pending |
| Prayer / Amen | Existing lesson header, anchored 1.2-second hold above safe area | Capture; cancelled/completed hold and duplicate-completion tests | Haptic comparison pending |
| Completion | Reference 2.8s orbit, rim comet, sparse sparks, settled halo; rose/gold | Settled capture; completion receipt/Reduced Motion/timing constants | Actual animation/haptic timing pending |
| Settings / account / support / legal | Clear grouped hierarchy; legal/account/restore remain reachable for future gate | Support/legal captures; deletion confirmation and large-text tests | Native authentication/delete prompts pending |
| Widget / daily notification | Shared independent calendar verse and palette, exact displayed-verse link | Dart and native Foundation tests; native extension build | App Group signing/payload verified; OS delivery and widget refresh pending |

General states: normal/selected/empty layouts are covered where applicable; returning-profile loading and retryable sync errors are covered by repository tests; store loading/unavailable/cancel/pending/owned/restore are modeled by the SDK adapter. A complete live-error screenshot matrix, VoiceOver traversal, Reduce Transparency rendering and dynamic-type inspection on the real phone remain device verification gates. No measured FPS or completed physical comparison is asserted.
