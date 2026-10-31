# Cognein → HolyHer screen and interaction map

Reference: `/Users/amir/Downloads/evolve.ai`. The reference repository was read but not modified. HolyHer adapts its reusable Flutter presentation patterns to an original light blush, pearl, and plum identity; the bundled Lexend family remains local.

| Cognein source screen/pattern | HolyHer implementation | Adaptation |
|---|---|---|
| Initial / welcome | `features/landing/landing_screen.dart` | Original cross mark, typography, product promise, account entry, accessible legal/help routes |
| Auth welcome + combined email auth | `features/auth/auth_screen.dart` | Apple, Google, email sign in/sign up, validation, password reset, provider loading/cancellation/error feedback |
| Onboarding shell, draft and option surfaces | `features/onboarding/onboarding_screen.dart` | Preferred name → Bible familiarity → focus → obstacle → optional reminder → saved rhythm → authentic Day-1 preview; real cloud saves and resumable step |
| Deterministic LearningPlanRules | `features/onboarding/personalization.dart` | Fixed ordered curriculum with an editorial application lens, 35 focus questions and practical rhythm guidance; no model-generated scripture or lesson promises |
| SaveStatusStep | Saved rhythm screen | Reports actual saved setup. No artificial generation delay, invented testimonials, certificates, or projected outcomes |
| LessonPreviewStep | Day-1 preview | Uses exact first lesson title and verse; same blush reading treatment |
| Cognein paywall | `features/paywall/paywall_screen.dart` | Single lifetime purchase, store price, true restore, error/loading/pending states, sticky purchase action on normal viewports, natural scrolling at large text/short landscape, account switching |
| MainAppScreen | `features/home/home_shell.dart` | Three retained tabs: Today, Journey, Profile; custom glass capsule navigation and preserved tab scroll state |
| Course list / learning plan card | Today | Current calendar-day lesson, missed unlocked lesson entry, open/revisit behavior, real streak/progress, focus guidance |
| Course module/list | Journey | Virtualized complete catalog, editorial theme sections, available/completed/locked states; unlocked-state route guard also enforced inside LessonScreen |
| LessonDeck | `features/lesson/lesson_deck.dart` | Source spring mechanics adapted: velocity-driven fly-off, resistance at boundaries, shared pressed/snap motion, back navigation, reduced-motion path; haptics respect user preference |
| Lesson card surface and progress | `features/lesson/lesson_cards.dart` | Five cards in fixed Verse → Confidence → Reason → Hope → Carry order; separate labeled original devotional reflection on Hope; personal application on Carry; only card five offers completion |
| Lesson resume | LessonCards local bookmark | Per-account/day card position; scrollable content; natural-height card view for large text and short landscape; reading-help controls and hidden peek semantics |
| Lesson celebration | `features/lesson/lesson_screen.dart` | Actual local completion must succeed before the saved celebration; queued cloud progress is described honestly; explicit Return to my day |
| Profile | Profile tab | Private identity, lifetime status, actual completed count/streak, pending/error sync status and retry, settings/support/legal navigation |
| Settings / account removal | `features/settings/settings_screen.dart` | Edit rhythm without resetting journey, reminder scheduling and permission handling, haptics, real purchase restore, logout, reauthenticated account deletion |
| Help, support, about, legal | `features/support/support_screens.dart` | In-app help and policy summaries, full hosted URLs, contact support, purchase/account answers; available before sign-in |
| Splash | `features/splash/splash_screen.dart` | Original HolyHer mark and loading semantics during actual bootstrap |
| AppSurface/AppPressable/mesh styling | `core/widgets/holy_ui.dart`, `holy_motion.dart` | Shared pearl surfaces, rose borders, soft layered shadows, subtle mesh background, press feedback, reading-width limits, common headers/buttons/rows |

## Deliberately excluded

Community/feed/comments, public profile/avatar/username, leaderboard, competitions/quizzes, AI coach/chat persona, video playback, occupational catalogues, certificates/XP, advertising, subscription plan management, and AI-generated personalization. These do not serve HolyHer’s single daily Bible practice.

## Verification

`test/screens_test.dart` exercises authentication validation/errors, actual questionnaire persistence and Day-1 preview, final-card-only completion and labeled devotional voice, direct locked-route rejection, lifetime purchase/restore without local access grants, tab destinations, and layout at 320dp with 3× text, iPad landscape, and phone landscape. Its QA captures are actual Flutter renders with bundled fonts, not design mockups. Production integration and store account/device checks remain separate release gates.
