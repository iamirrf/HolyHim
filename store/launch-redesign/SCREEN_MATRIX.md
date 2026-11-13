# Launch redesign screen and state inventory

Updated November 9, 2026. Source: the user's complete Cognein-inspired launch redesign brief. Reference geometry: `store/v2-design-ports.json`; earlier reference comparison: `store/redesign-v3/SCREEN_COMPARISON.md`. “Raster” refers to the current Flutter layout captures under `store/launch-redesign/screens/`; none is a screenshot of Amir's iPhone. The current 2.0.0 (6) profile app was built for `iPhoneOS` with development signing, verified to contain all 292 chapter assets, installed in place, and launched on Amir's physical iPhone over `transportType: localNetwork` (`store/iphone-run.json`, PID 76255). Native visual acceptance, StoreKit scenarios, accessibility, and performance remain pending.

| Route or state | Reference mapping and target composition | Implementation | Visual evidence | Current iPhone result |
|---|---|---|---|---|
| Native launch, loading, retry | Cognein brand entrance; readiness-driven transition and recovery | Branded launch and retry exist | Raster `welcome.png`; signed current build | 2.0.0 (6) launched wirelessly; visual review pending |
| Welcome scenes 1–3 | Cognein scene pacing; Scripture, saved verse, personal walk | Existing three scenes; composition review pending | Raster `welcome.png` | Pending |
| Apple and Google auth | Cognein provider hierarchy; loading, cancel, error | Existing controls; provider-specific native check pending | Raster `welcome.png` | Pending |
| Email sign-in and sign-up | SunRize form layout; autofill, visibility, validation, keyboard | Existing form | Raster `email-signin.png`, `email-signup.png` | Pending |
| Password reset sending, sent, retry | Consistent glass form and explicit status | Existing route; state captures pending | None for states | Pending |
| Returning account, offline, sync error | No onboarding flash; cached profile and access | Cached profile and verified access result; runtime check pending | None | Pending |
| Onboarding 1: name | Cognein centered intro, provider prefill, keyboard-safe action | Implemented | Current raster `onboarding-1.png` | Pending |
| Onboarding 2: birthday | Cognein snapping month/day/year rulers and age rule | Existing ruler; physical haptics pending | Raster `onboarding-2.png` | Pending |
| Onboarding 3: life season | Six substantial cards, no search | Implemented; search removed | Current raster `onboarding-3.png` | Pending |
| Onboarding 4: Scripture routine | Four differentiated choices | Implemented | Raster `onboarding-4.png` | Pending |
| Onboarding 5: Guide obstacle | Transcript, anchored choices, contextual response, edit and stale-animation cancellation | Acquisition, duplicate familiarity, and repeated goal prompts removed; contextual acknowledgments, anchored scrollable answer tray, and answer editing implemented; native timing pending | Current rasters `onboarding-5.png`, `onboarding-5-choices.png` | Pending |
| Onboarding 6: intentions | Eight cards, maximum three, count and limit feedback | Implemented; 200% layout test passes | Current raster `onboarding-6.png` | Pending |
| Onboarding 7: daily rhythm | Pace and reminder conversation; permission result | Two-question conversation, anchored answer tray, answer editing, and actual permission result; acknowledgment polish pending | Current rasters `onboarding-7.png`, `onboarding-7-choices.png` | Pending |
| Onboarding 8: routine preview | Chosen pace, accurate reminder, advice, first three covers | Deterministic plan and actual selected-minute totals implemented; all 73 chapter photos packaged | Current raster `onboarding-8.png` | Pending |
| Onboarding 9: profile setup | Photo crop/upload, display name, reminder, consent, denied/retry | Existing flow; physical picker/denial review pending | Current raster `onboarding-9.png` | Pending |
| Onboarding 10: saving and ready | Durable save, failure/retry, named summary | Existing durable save; summary shows life season, pace, actual reminder, orientation, obstacle advice, and intentions | Current raster `onboarding-10.png` | Pending |
| Onboarding 11: lifetime access | Cognein purchase hierarchy, localized price, restore, legal/account | Gate defaults on; backend purchased and retained statuses read and cached. Native StoreKit scenarios pending | Current raster `paywall-unavailable.png` | Pending |
| Four-tab shell | Cognein tabs, swipe/tap coordination, retained scroll | Existing; native glass and measured swipe timing pending | Raster `walk.png`, others | Pending |
| Walk/Home and Today | Compact greeting, verse, routine, milestone, Continue state | Plan summary and Continue reading label added | Current raster `walk.png` | Pending |
| Chapter journey and lesson preview | Chapter art, expanded current chapter, compact others, measured return-to-current | Current chapter expands with landscape art; other chapters are compact and expandable; return uses rendered layout | Raster `walk.png`, `walk-journey.png` | Pending |
| Daily verse detail | Exact daily Scripture, share, route to lesson | Existing | Raster coverage not established | Pending |
| Lesson Scripture | Portrait photo, full WEB quote, safe reading veil | Four-card reader; all 73 chapter portrait photos packaged | Current raster `scripture.png` | Pending |
| Lesson Meaning | Landscape photo, full explanation | All 73 chapters have landscape art | Current raster `meaning.png` | Pending |
| Lesson Reflection | Quiet reading surface and practical invitation | Existing four-card text | Raster `reflection.png` | Pending |
| Lesson Prayer and Amen | Portrait crop, scrollable prayer, anchored 1.2-second hold | Existing hold and durable completion; position restoration added | Raster `prayer.png` | Pending |
| Lesson resume, reread, failed completion | Account-scoped stage/fraction/revision; completed rereads start at Scripture | Local typed position; completion clear; device restart check pending | No current capture | Pending |
| Completion and badge reveal | Coordinated pulse, collectible, Reduced Motion | Existing; physical motion/haptic check pending | Raster `completion.png` | Pending |
| Saved list, search, detail, empty, undo | Photo-led keepsakes and readable references | Existing; chapter-specific art packaged for all 73 chapters | Raster `saved.png`, `saved-empty.png` | Pending |
| Growth, calendar, day detail, badges | Statistics, dates, criteria, earned/locked states | Existing | Raster `growth.png`, badge review sheet | Pending |
| Profile and editing | Identity, status, preferences, crop/upload/retry | Existing; native photo interaction pending | Raster `profile.png` and photo edit | Pending |
| Preferences and theme picker | Eight semantic themes, text preview, reminders, sound, haptics, widget help | Existing; cross-theme/large text native review pending | Raster theme/settings images | Pending |
| Account export, restore, sign-out, deletion | Accessible without purchase; pending/error/success states | Existing routes; device reauthentication check pending | Raster account images; state coverage incomplete | Pending |
| Support, About, Terms, Privacy, route recovery | Shared type and material system, accessible without purchase | Existing; final state captures incomplete | Raster support/legal images | Pending |
| Home/Lock Screen widgets | Photo and exact daily verse for owners; branded access-required otherwise | Access gate and native model implemented; OS placement pending | No device widget capture | Pending |
| Reminder permission, schedule, cold/warm tap | Exact verse and actual permission; owners only | App reconciliation gated by access; OS delivery pending | No device notification capture | Pending |
| Public website and web owner app | Four-stage demo, chapter progression, lifetime copy, owner web access | Copy/demo corrected; all 73 chapter previews generated; browser visual QA pending | Static HTML, generated 73-chapter inventory, and nine site interaction tests | Pending |
| Store screenshots, review, IAP and privacy | Final native app, fourteen privacy categories including photos | Metadata/privacy source prepared; current screenshots and archive pending | Earlier marketing assets only; final current-build set pending | Pending |

## Shared state and adaptation review

| Coverage | Current evidence | Remaining acceptance |
|---|---|---|
| Selected, pressed, disabled, loading, empty, error, denied, restored and completed | Widget/adapter tests and selected older raster captures | Re-capture applicable states in the current build and compare on phone |
| Small/large phone, iPad, eight themes, 200% text, keyboard | 106 Flutter tests including Guide editing and eight-theme contrast test | Native phone/tablet layout and keyboard inspection |
| VoiceOver, Reduce Motion, Reduce Transparency | Reduced Motion/widget semantics tests | Physical VoiceOver and transparency inspection |
| Animation and performance | Source timings and gesture tests | Real-device recordings and Profile-mode frame measurements |
| Purchase/restore/revocation/account switching | SDK fixtures and server rules tests | Physical StoreKit sandbox purchase, restore and revocation |
| Offline ownership and same-device reading position | Local account-scoped caches and Dart tests | Cold launch, account switch, content revision and actual device storage inspection |

## Artwork count and review

`art/chapter-manifest.json` inventories all 73 canonical five-day chapters. All 73 chapters have 146 photographic masters and 292 packaged assets (`portrait`, `landscape`, portrait thumbnail, subject thumbnail), with dimensions, hashes, crops and focal points. Every master has a recorded full-size visual review and the complete contact sheet has been inspected; physical-device image review remains pending. Current chapter assets total 35.69 MiB against the 45 MiB target. `store/redesign-v3/chapter-contact-sheet.jpg` is a raster art contact sheet, not a device capture. The earlier 25-image general library remains a fallback; its repeated mapping is not counted as the requested chapter photography.
