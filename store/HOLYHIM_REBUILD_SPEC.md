# HolyHim: complete Cognein-depth design and guided Bible learning

## 1. Product direction and non-negotiable decisions

Rebuild HolyHim’s presentation and learning experience using the actual Cognein repository at `/Users/amir/Downloads/evolve.ai` as the reference for composition, navigation, materials, animations, sounds, haptics, and interaction depth.

### Locked product decisions

| Area | Decision |
|---|---|
| Identity | **White and blush pink**, retaining the supplied pink-cross icon and bundled Lexend typography. |
| Main navigation | Exactly **Learn, Saved, Profile**, in that order. |
| Learning home | Follow Cognein’s Learn screen: progress hero, next lesson, guided roadmap, lesson nodes, and completion states. |
| Lesson presentation | Follow Cognein’s learning-card design and interactions, adapted to Bible teaching. |
| Curriculum | Preserve the existing **365 messages, day order, titles, and verified WEB quotations**. Deepen their teaching rather than replace the curriculum. |
| Questions | Multiple choice that checks understanding and explains the answer. |
| Writing | No journal, written reflections, personal check-in feature, or reflection tab. |
| Access | Remove payment from the active app experience. Keep one additional lesson unlocking each calendar day. |
| Existing free users | People who begin during this free phase keep access to this 365-lesson edition if pricing returns later. |
| Accounts | Preserve account-first Apple, Google, and email authentication and cross-device synchronization. |
| Feedback | Sounds **on initially**; haptics **on initially**. Independent controls for both. |
| Platforms | iPhone and iPad, including landscape, split view, and large text. |
| Delivery priority | Complete scope and quality first. November 15 remains a target. |
| Apple work | Apple account configuration, App Store changes, submission, and release scheduling remain deferred. |

The selected experience excludes public community, rankings, competitive faith scores, AI coaching, video lessons, advertising, and professional certificates.

### What the repository audit established

HolyHim currently has working content, authentication, cloud services, offline safeguards, and a basic three-tab interface. Its existing motion constants resemble Cognein’s, but most controls do not use the same spring mechanics. Its background is static, headers scroll with content, onboarding is simpler, and lesson resume is local.

The implementation must deliver the actual behaviors described below. Shared constants or similar colors alone do not establish parity.

---

## 2. Complete screen and visual design specification

### 2.1 Shared visual system

Create one shared component system before rebuilding individual screens.

| Token | Specification |
|---|---|
| Main surface | White `#FFFFFF` |
| App background | Warm white `#FFF9FB` |
| Blush surface | `#F9E5ED` |
| Selected surface | `#F2D0DF` |
| Primary action | Deep rose `#9C456B` |
| Primary text | Plum ink `#382331` |
| Secondary text | `#735867` |
| Decorative divider | `#E9D4DF` |
| Interactive outlines | A stronger rose than decorative dividers, meeting contrast requirements |
| Status colors | Restrained success/error colors, always paired with text or icons |
| Typography | Lexend; primarily weights 400, 500, and 600 |
| Spacing | Shared 4, 8, 12, 16, 20, 24, 32, and 40-point scale |
| Controls | Minimum 44-point touch targets; primary buttons normally 52 points high |
| Cards | Cognein-derived geometry, layered shadows, animated surfaces, and edge illumination |
| Appearance | White/blush throughout; no dark-mode selector in this scope |

The chosen primary action color has approximately 6:1 contrast against white. Secondary text remains readable on white and blush surfaces. Pale pink alone must never communicate selection, correctness, focus, or availability.

Preserve the supplied icon artwork. Adapt Cognein’s blue edge light into rose/blush illumination and its dark materials into white, pearl, and pink surfaces.

### 2.2 Shared components and source mapping

| Cognein reference | HolyHim implementation |
|---|---|
| Persistent backdrop host and animated mesh | One persistent white/blush backdrop shared across tabs and routes |
| `AppTopBar` and branded fading header | Unified HolyHim brand header and secondary-page header |
| `AppPressable` | One accessible, spring-driven press component used throughout |
| Minimizing glass navigation bar | Three-tab HolyHim bottom bar with the same interaction quality |
| Course-list roadmap | HolyHim Learn screen and 365-day roadmap |
| Lesson card surface and deck | Bible teaching cards with the same lift, drag, light, and transition behavior |
| Quiz question card | Multiple-choice Bible questions with immediate explanation |
| Lesson celebration | Rose/blush completion choreography |
| Shared loaders, notices, tips, and dialogs | One coherent loading, feedback, tutorial, and confirmation system |

Port the relevant presentation components into HolyHim. Remove Cognein-specific product dependencies from those components, including advertising, AI, subscriptions, and competition logic.

### 2.3 Top navigation

Use two consistent header variants.

**Main-tab header**

- HolyHim wordmark and small brand mark on the left.
- Current streak indicator on the right.
- Tapping the streak opens the progress/calendar sheet.
- Pin the header while content scrolls beneath it.
- Match Cognein’s progressive material: approximately 70% tint at the top, fading to transparent, with maximum blur sigma 20.
- Header tint follows the shared background continuously.
- Respect status-bar insets without double-counting toolbar padding.

**Secondary-page header**

- Back or close control, clear title, and at most two relevant actions.
- Same material, typography, focus treatment, and safe-area behavior.
- Native back gestures remain available.
- Lesson chrome follows Cognein’s immersive card composition rather than adding a second conventional toolbar over it.

Reduce Transparency substitutes an opaque, readable white surface. Every header must remain readable over scrolling cards.

### 2.4 Bottom navigation

The bottom bar contains:

1. **Learn** — guided daily learning.
2. **Saved** — saved lessons and their verses.
3. **Profile** — identity, progress, settings, and support.

Behavior:

- Retain each tab’s scroll position, filters, and loaded state.
- Support synchronized tab taps and horizontal page swipes.
- Use Cognein’s approximately 300 ms transition for tab taps.
- Interpolate the selected pill and background continuously during swipes.
- Re-selecting the current tab scrolls its primary list to the top.
- Switching tabs must not restart the background, replay all entrances, or replace content with loading spinners.
- Pushed detail screens preserve the originating tab underneath.
- The bar is hidden during immersive lessons and onboarding.

Use the source’s native adaptive glass treatment where supported, with the custom Cognein-derived fallback on older iOS versions.

For custom minimization:

- Expanded height approximately 68 points; compact height approximately 52.
- Minimize after 24 points of sustained downward user scrolling.
- Expand on upward scrolling, returning to the top, or changing tabs.
- Ignore programmatic scrolling, bounce, and unrelated nested scroll views.
- Compact-bar interaction expands it predictably.
- Keep the expanded, labeled version for accessibility configurations where minimization reduces usability.

### 2.5 Splash, welcome, and authentication

| Surface | Design and behavior |
|---|---|
| Native launch | Supplied icon on the matching white/blush background, transitioning cleanly into Flutter. |
| App splash | Brand mark and shared loader during actual initialization. Known returning users avoid a welcome-screen flash. |
| Welcome | Cognein-style animated product showcase with three genuine scenes: learning cards, guided roadmap, and saved verses. |
| Email sign-in | Focused form with validation, password visibility, autofill, keyboard-safe layout, reset link, and recoverable errors. |
| Email account creation | Matching composition, clear password requirements, submission/loading states, and navigation back to sign-in. |
| Password reset | Email entry followed by an appropriate sent-state confirmation and a route back to sign-in. |
| Provider authentication | Apple/Google loading, cancellation, connection failure, and retry states without losing the current welcome position. |

Welcome specifics:

- Five-second settled slide duration.
- Approximately 680 ms slide transition.
- Manual swipe and accessible page controls.
- Decorative scenes use Cognein-style motion, with HolyHim content and colors.
- Apple, Google, and email entry remain clearly accessible.
- Existing-user sign-in has an obvious entry.
- Privacy, Terms, About, and Help are available before authentication.
- Reduced Motion disables automatic advancement and decorative loops.
- Automatic scene changes produce no unsolicited sound or haptic.

### 2.6 Onboarding: ten meaningful surfaces

Keep the existing familiarity, focus, and obstacle choices. Personalization changes guidance and emphasis; everyone receives the same ordered curriculum.

| Step | Surface | Required behavior |
|---|---|---|
| 1 | Preferred name | Prefill where available; editable and skippable; support real names and keyboard-safe scrolling. |
| 2 | Bible starting point | New, returning, or regular reader; selectable cards with clear selected states. |
| 3 | Current focus | Peace, confidence, hope, guidance, or rest. |
| 4 | Rhythm barrier | Busy, forgetting, difficult language, or applying the message. |
| 5 | Your suggested rhythm | Show real guidance derived from the answers, without invented growth forecasts. |
| 6 | Optional reminder | Choose a time or skip. Request OS permission only after explicit opt-in. |
| 7 | How learning works | Demonstrate the actual teaching-card and multiple-choice interaction. Clearly identify preview activity. |
| 8 | Your rhythm summary | Show the saved choices with direct edit links and an explanation of daily unlocking. |
| 9 | Saving your setup | Represent actual local/cloud save state, with retry and offline treatment. |
| 10 | Real Day 1 preview | Use the actual lesson title and verified verse. Primary action: **Begin my journey**. |

Onboarding mechanics:

- Use Cognein’s coordinated progress, backdrop, option entrances, and step transitions.
- Restore the actual saved step before painting the pager.
- Save local drafts immediately; queue cloud checkpoints without blocking every Next action.
- Persist edits and flush drafts when backgrounding.
- Local save failure must be visible.
- Final journey creation requires a server acknowledgment.
- Notification denial leaves onboarding usable with reminders off.
- Back navigation preserves answers.
- Summary edits return to the summary rather than restarting the entire flow.
- All content remains scrollable at large text sizes and with the keyboard open.

Successful final flow:

**Saved setup → Day 1 preview → Begin my journey → server creates journey once → onboarding completes → Day 1 lesson opens.**

The first lesson returns to Learn.

### 2.7 Learn tab: the Cognein learning-home equivalent

Learn combines the daily entry, progress overview, and full roadmap.

| Area | Specification |
|---|---|
| Greeting | Preferred name where available, calm contextual copy, and current journey information. |
| Progress hero | Cognein-style composed card, completion ring, actual completed count, and progress toward 365. |
| Next-lesson entry | Resume an unfinished lesson; otherwise recommend the earliest unfinished unlocked day. |
| Catch-up state | Explain that missed days remain available. Show available lessons without guilt-based messaging. |
| Roadmap | Cognein’s winding path, unit headers, lesson nodes, progress illumination, and checkpoint treatment. |
| Unit preview | Title, day range, brief teaching summary, completion count, and available lessons. |
| All-lessons view | Accessible list alternative with day, title, Bible reference, theme, and status. |
| Search | Search the bundled catalog by title, reference, theme, and day. |
| Progress/calendar sheet | Actual activity dates, streak, completed lessons, and milestones. |
| Caught-up state | Confirm today’s work and show the next unlock date in the journey timezone. |
| Full-year state | Distinguish “all lessons available” from “all 365 completed.” Celebrate completion only when true. |

Roadmap rules:

- Group the existing order into **73 units of five lessons**.
- Author unique, accurate unit headings based on the five existing messages.
- Preserve day numbers and content order.
- Distinguish completed, in-progress, available, recommended-next, and future nodes.
- Calendar availability remains independent of completing previous lessons.
- Future nodes open an unlock explanation, never a payment screen.
- Auto-reveal the recommended current node once after initial layout; preserve position afterward.
- Provide a clear return-to-current control when browsing far away.
- Virtualize the roadmap. Do not keep 365 animated nodes or listeners running.

### 2.8 Learning cards: guided teaching and multiple choice

Use Cognein’s full-screen deck composition, card surface, lighting, water-style progress treatment, drag lift, swipe physics, question presentation, and closing-card celebration.

Each lesson has **nine semantic steps**:

| Step | Content |
|---|---|
| 1. Opening | Existing title, day number, and one plain-English learning objective. |
| 2. Verse | Exact WEB quotation, reference, and translation label. |
| 3. Understand | Existing Reason content, deepened with concise context and explanation. |
| 4. Question 1 | Four-choice check of the verse or its meaning. |
| 5. Confidence | Existing encouraging message, connected clearly to the teaching. |
| 6. Hope | Existing hope content; any authored devotional encouragement remains clearly separate from Scripture. |
| 7. Question 2 | Four-choice application-understanding question. |
| 8. Carry | A short practical takeaway, replacing the open-ended writing prompt. |
| 9. Closing | Summary, question result, actual save state, celebration, and Continue. |

Long content may produce additional rendered cards while retaining these stable semantic steps.

**Question behavior**

- Exactly two questions per lesson: **730 reviewed questions**, with four options each.
- One correct answer, plausible alternatives, and a short explanation.
- Questions test what the lesson teaches, not the reader’s feelings or faithfulness.
- First selection locks that question for the current attempt.
- Reveal the correct answer and explanation when needed.
- Both questions must be answered to finish; a perfect score is not required.
- Wrong answers receive gentle explanatory feedback.
- Repeating a lesson creates a new practice attempt without increasing completed-day counts.
- Store selected option IDs rather than display positions.
- Shuffle options reproducibly within an attempt and preserve that ordering on resume.

**Deck behavior**

- Forward swipe and Next follow identical rules.
- Unanswered questions prevent moving forward; backward navigation remains available.
- First/last-card boundaries resist and settle safely.
- Previously viewed cards return at rest rather than replaying every entrance.
- VoiceOver reads the full content immediately.
- Provide a way to finish text-reveal animation without waiting.
- Hidden cards are excluded from accessibility.
- Exit offers Continue learning or Save and exit for an unfinished lesson.

**Completion**

- Entering the closing card triggers one idempotent save.
- Show Saving, Saved, Pending sync, or Retry based on actual state.
- Celebrate after durable local acceptance; describe pending cloud synchronization accurately.
- Continue becomes available after that acceptance.
- Continue can interrupt the celebration and return to the originating screen.
- No earlier card can complete the lesson.

### 2.9 Saved tab

Use one saved item per lesson day, containing the lesson reference and its verse.

- Save controls appear on the verse card, lesson actions, and lesson previews.
- All controls reflect the same bookmark state.
- Saved rows show the verse, Bible reference, lesson title, day, and theme.
- Search locally across the bounded saved catalog.
- Provide theme filters and Recent/Day ordering.
- Offer readable list and tablet grid layouts.
- Open a verse detail sheet or its full lesson.
- Support native sharing of the verse as text or a white/blush card image.
- Shared Scripture includes its reference and WEB attribution.
- Use a correctly anchored share sheet on iPad.
- Removing a saved item offers a short undo.
- Empty state links directly to Learn.
- Saving, removal, offline changes, pending synchronization, failure, and retry have designed states.

There are no personal notes or text annotations.

### 2.10 Profile, settings, account, and support

| Surface | Required design and behavior |
|---|---|
| Profile home | Cognein-style identity card, name, private account details, actual progress, saved count, streak, and edition-access status. |
| Identity editing | Preferred name and a private initials/brand-glyph avatar; save, cancel, validation, and unsaved-change states. |
| Learning setup | Review and edit familiarity, focus, and rhythm preferences without resetting the journey. |
| Milestones | Meaningful completed-lesson milestones at 7, 30, 90, 180, and 365; no spiritual score. |
| Settings hub | Organized Learning, Feedback, Account, Data, and Help sections. |
| Reminder settings | Time, enabled state, actual permission status, denial recovery, and device-settings return reconciliation. |
| Sound and haptics | Independent switches, initially on; preview controls and immediate application. |
| Reading preferences | Standard/larger text choices layered on system text size, with a real reading preview. |
| Tips | Enable/disable and replay contextual tutorials without altering progress. |
| Account settings | Provider-aware actions; password changes appear only where applicable. |
| Change password | Current/new password flow, validation, recent authentication, success, and failure. |
| Data export | Export profile, preferences, learning history, and saved items through the native share/save interface. |
| Reset learning progress | Clear completions, attempts, and resume data while retaining the start date, timezone, calendar availability, saved items, preferences, and edition access. |
| Delete account | Clear explanation, recent authentication, confirmation, progress, retry, and signed-out completion. |
| Sign out | Confirmation and clear handling of locally saved pending changes. |
| Help hub | Searchable help categories and direct access to tutorials, contact, and feedback. |
| FAQ | Accurate answers about cards, questions, daily unlocking, catch-up, saved lessons, offline use, synchronization, and accounts. |
| Tutorials | Short interactive demonstrations using the actual components. |
| Contact support | In-app form using the existing backend, with real submission, validation, rate-limit, retry, and success states. |
| Send feedback | Separate feedback purpose using the same secured delivery infrastructure. |
| About | HolyHim’s purpose, publisher, version, translation attribution, and working links. |
| Privacy and Terms | Readable in-app documents, matching hosted versions, with offline access. |

All secondary screens use the shared header, surfaces, controls, dialogs, feedback, and motion vocabulary.

---

## 3. Content, access policy, APIs, and synchronization

### 3.1 Deepen all 365 existing lessons

For every day:

- Preserve its existing title, order, core message, and verified quotation.
- Add one clear learning objective.
- Deepen context and explanation in simple English.
- Add two questions and their explanations.
- Convert the Carry writing prompt into a practical takeaway.
- Keep Scripture distinct from authored teaching and encouragement.
- Avoid interpreting devotional prose as a literal Bible quotation.
- Avoid unsupported promises about money, health, or specific future outcomes.

Author and review a complete nine-step vertical slice for the first five lessons, then apply the approved structure to all 365.

Extend the content builder and independent verifier to check:

- All 365 lessons and 73 units exist.
- Exactly 730 questions exist.
- Each question has four distinct options and one valid correct option ID.
- Question, lesson, and step IDs are stable.
- Every question has an explanation and teaching-source reference.
- Existing Scripture remains verbatim and traceable to the pinned corpus.
- All referenced steps and assets exist.
- No lesson exposes unfinished teaching or placeholder questions.

### 3.2 Genuine free access

Removing the visible paywall is insufficient. Payment currently controls root routing, the home shell, lesson access, journey creation, and server completion.

Implement these changes together:

- Remove payment guards from all active client routes.
- Remove billing initialization and refresh from startup and foreground handling.
- Remove purchase, pricing, restoration, and subscription navigation from the free customer flow.
- Remove the RevenueCat client dependency from the active Flutter build.
- Preserve existing billing implementation in version history and retain server records/configuration for genuine legacy rights.
- Keep Apple and RevenueCat product records unchanged.

Introduce a **server-owned edition-access grant**:

- Edition identifier: `holyhim365`.
- A person starting during the free phase receives a retained grant for this edition.
- Create the grant atomically with first journey creation.
- Backfill grants for existing journeys during the free phase.
- Store the grant separately from verified purchase ownership.
- Resetting progress or signing out preserves the grant.
- Account deletion removes account-owned data and its free-edition grant.
- Future refunds or billing webhook events cannot revoke a retained free grant.
- No expiry timer or automatic paywall reactivation is introduced.

### 3.3 Journey start and recovery

- Keep `startJourney(timeZone)` idempotent.
- Preserve an existing start date, timezone, and completions.
- Set onboarding complete only after successful journey creation.
- If journey creation succeeds but the final profile acknowledgment fails, resume finalization without creating a second journey.
- An already-onboarded unpaid user with no journey receives a concise Begin journey state using saved preferences.
- A first start while offline shows saved setup and a reconnect/retry action.
- Established offline journeys retain access to previously verified unlocked days.
- New calendar unlocks require server confirmation.

### 3.4 Public interfaces and models

| Interface | Change |
|---|---|
| `getAccessStatus` | New authenticated callable returning edition eligibility, retained grant status, and genuine purchase status as separate concepts. |
| `startJourney` | Retain existing request shape; add free-grant authorization and atomic grant creation. |
| `getJourney` | Preserve current fields; add a backward-compatible journey revision used for resets and stale-write protection. |
| `completeLessonAttempt` | New callable accepting day, content version, attempt ID, selected option IDs, and journey revision. Validate and grade on the server. |
| Legacy `completeLesson` | Retain compatibility for the old build and migrated pending work; record legacy completions without inventing quiz results. |
| `resetLearningProgress` | New authenticated, recently reauthenticated reset operation that advances the journey revision. |
| `deleteAccount` | Remove RevenueCat availability from the deletion path for never-billed free users. |
| `supportRequest` | Preserve existing behavior; add validated support/feedback purpose and optional app-version context. |

Add typed models for:

- `EditionAccess`
- `LessonStep`
- `LessonQuestion`
- `LearningAttempt`
- `LessonResume`
- `SavedLesson`
- `AppPreferences`

Use server-owned canonical answer data generated from the same versioned content source. Ignore client-supplied scores. Duplicate submissions with the same attempt ID must return the original result.

### 3.5 Persistence and account isolation

Extend the existing UID-scoped architecture.

- **Bookmarks:** account-private, bounded to the catalog, with synchronization of additions and removals.
- **Resume:** semantic step ID, rendered part, content version, attempt ID, option order, and selected answers.
- **Attempts:** server-written results and account-private reads.
- **Preferences:** sounds, tips, and reading settings; preserve the existing haptic preference.
- **Onboarding:** semantic step IDs and a versioned draft rather than relying solely on the old seven-step integer.

Resume behavior:

- Restore before showing the reading card.
- Save locally immediately.
- Debounce cloud checkpoints at approximately 800 ms.
- Flush on pause and exit without blocking navigation on the network.
- Apply another device’s checkpoint when opening a lesson, not by jumping an active reader mid-card.
- Clear completed learning resumes.
- Ignore obsolete checkpoints that arrive after completion or reset.
- Preserve location through rotation, text-size changes, and pagination changes.

Account changes must clear private routes, loaded state, pending feedback, and account-scoped caches. Preserve the existing asynchronous generation guards.

### 3.6 Migration and deletion

- Preserve existing completed days and actual activity.
- Existing completions remain completed when questions are introduced.
- Map old card indexes to semantic steps.
- Where new required questions precede the restored location, resume at the first unanswered question with a quiet lesson-updated explanation.
- Migrate the existing durable completion outbox; do not discard pending work.
- A progress reset increments the journey revision so old devices cannot restore erased completion data.
- Preserve owner-only Firestore rules and server-only access/progress writes.
- Validate new collections rather than broadening access to all user subcollections.

Inventory legacy billing users before removing client billing. Legacy provider cleanup belongs in a private authenticated retry queue. A billing outage must not prevent a never-billed free user from deleting their HolyHim account.

---

## 4. Animation, sound, haptics, accessibility, and states

### 4.1 Motion specifications

Use Cognein’s source values as the baseline.

| Interaction | Specification |
|---|---|
| Press down | 100 ms ease-out to scale `.96` |
| Press release | Velocity-preserving spring: mass 1, stiffness 400, damping ratio `.55` |
| Card snap-back | Mass 1, stiffness 380, damping ratio `.72` |
| Card fly-off | Mass 1, stiffness 900, damping ratio 1 |
| Pixel settling | Distance tolerance `.5`; velocity tolerance 20 |
| General entrance | 420 ms ease-out cubic |
| General exit | 180 ms ease-in |
| Onboarding transition | Approximately 600 ms; progress and background follow position |
| Welcome transition | Approximately 680 ms after five settled seconds |
| Ambient mesh | Twenty seconds each direction; one persistent controller |
| Shared loader | Five-dot, 1.6-second wave with staggered timing |
| Answer selection | Approximately 240 ms animated fill, border, icon, and emphasis |
| Lesson completion | One 2.8-second visual/audio/haptic timeline |
| Route transition | Cognein fade-through behavior while preserving native back navigation |

Deck commit uses 25% of the **actual deck width** or approximately 800 logical pixels per second. Boundary resistance follows the source’s `.35` behavior.

The single completion clock drives:

- Initial light feedback.
- Crest at approximately 800 ms.
- Settle at approximately 930 ms.
- Stable completed halo afterward.

Leaving the screen cancels remaining effects immediately.

### 4.2 Haptic vocabulary

Centralize all app-owned feedback.

| Action | Feedback |
|---|---|
| Tab change, toggle, bookmark | One restrained selection or light cue |
| Option selection | Light selection cue |
| Onboarding step completion | Medium then light, separated by approximately 100 ms |
| Card threshold | One selection tick, rearmed only after moving sufficiently below the threshold |
| Blocked swipe | One gentle tick |
| Correct answer | Light impact |
| Incorrect answer | Selection tick |
| Completed lesson | Shared choreography; reduced-motion variant uses light then selection feedback |

Generic controls must not duplicate semantic cues. Native navigation adapters must not add a second manual cue to feedback already owned by the adapter.

Haptics off must silence every app-owned path.

### 4.3 Sound

Sounds start enabled, as selected.

- Use the Cognein-style forward swipe variants, backward swipe, soft landing, correct-answer note, and completion surge.
- Preload small low-latency pools when opening a lesson.
- Keep swipe, landing, correct-answer, and completion levels restrained.
- Incorrect answers remain silent.
- Honor the iOS silent switch.
- Mix with the user’s existing audio.
- Do not request microphone access.
- No narration, background music, or automatic welcome-slide audio.
- Sound failure must never block interaction.
- Turning sound off stops active app cues immediately.
- Account switching and route exit cancel pending cues.

Reuse the reference repository’s resolved presentation/audio/share package versions where needed, without importing unrelated dependencies.

### 4.4 Accessibility and adaptive layouts

- Preserve natural text scaling through 3×.
- Never use text shrinking to force essential content into a card.
- Paginate ordinary teaching content; allow natural scrolling when large text, landscape, or quiz length requires it.
- Announce semantic card name, position, answer state, and save status.
- Reserve feedback space where practical to prevent jumping answer layouts.
- Do not communicate correctness through color alone.
- Provide keyboard focus and activation for relevant iPad controls.
- Keep all important actions reachable above safe areas and the keyboard.

Layout defaults:

- Compact: below 600 points.
- Tablet/intermediate: 600–1023.
- Extended iPad: 1024 and above.
- Center lesson cards within a readable maximum width of approximately 560 points.
- Keep roadmap content bounded rather than stretching across a wide tablet.
- Use two- or three-column Saved layouts where space permits.
- Use a two-column Profile layout on wide iPad screens.
- Respond to actual available constraints during split view.

Reduced Motion:

- Stops automatic welcome movement, ambient mesh, parallax, typewriter animation, and orbit celebrations.
- Uses direct state changes or short opacity transitions.
- Shows the completed halo immediately.
- Preserves every navigation and learning function.

### 4.5 Complete state catalog

Every applicable screen must specify and implement:

- Initial loading.
- Cached content while refreshing.
- Empty content.
- Search with no results.
- Offline but usable.
- Connection required for first start.
- Pending synchronization.
- Saving.
- Saved confirmation.
- Recoverable failure with retry.
- Authentication cancellation.
- Permission denied.
- Disabled action with explanation.
- Destructive confirmation.
- Content unavailable because of calendar release.

Use shared notices, loaders, dialogs, sheets, and button states. Copy must describe actual state. Do not simulate generation, synchronization percentages, achievements, or saved data.

---

## 5. Implementation sequence, verification, and completion criteria

### Phase 1 — Establish the reference and remove paid access

1. Update `store/COGNEIN_SCREEN_MAP.md` into a real parity matrix: Cognein reference, HolyHim screen, component reuse, states, and acceptance evidence.
2. Record the actual reference files’ versions/hashes without changing the Cognein repository.
3. Implement the server-owned free-edition grant and compatible backend changes.
4. Remove active client billing and payment routing.
5. Prove the complete signed-in flow: onboarding → free journey → lesson → saved completion.
6. Update customer-facing pricing copy and prepared documentation.

**Gate:** a user with no purchase can start and complete an eligible lesson with no StoreKit or RevenueCat client calls.

### Phase 2 — Build the shared presentation system

1. Implement white/blush tokens, surfaces, persistent backdrop, and both header variants.
2. Port real press physics, feedback services, loaders, sheets, dialogs, and notices.
3. Build the retained three-tab shell and glass navigation.
4. Validate a representative phone and iPad screen before applying the system everywhere.

**Gate:** shared chrome, motion, interaction, and accessibility work as a coherent system.

### Phase 3 — Complete welcome, authentication, and onboarding

1. Build the three real animated welcome scenes.
2. Complete all email/provider authentication states.
3. Implement the ten onboarding surfaces and local-first drafts.
4. Finish reminder permission handling.
5. Implement idempotent free journey start and recovery from interrupted finalization.

**Gate:** fresh, returning, interrupted, slow-network, and offline-first-start scenarios behave correctly.

### Phase 4 — Complete Learn and the teaching deck

1. Approve the first five fully authored teaching lessons as the vertical slice.
2. Implement the progress hero, next-lesson entry, unit previews, roadmap, list alternative, search, and calendar.
3. Implement all nine semantic card types, questions, explanations, resume, and completion.
4. Complete all 365 enhanced lessons, 73 unit descriptions, and 730 questions.
5. Verify the entire content package before treating the new learning format as complete.

**Gate:** every day is backed by finished content, and every learning interaction works with real persisted state.

### Phase 5 — Complete Saved, Profile, settings, and support

1. Finish bookmark synchronization, search, filtering, detail, sharing, removal, and undo.
2. Finish identity, progress, milestones, and all preference/account screens.
3. Finish export, reset, deletion, and pending-change handling.
4. Complete FAQ, tutorials, contact, feedback, About, Privacy, and Terms.
5. Align the hosted landing/support pages and prepared store materials with the free experience and actual features.

**Gate:** every visible action has a working destination and a complete success/failure path.

### Phase 6 — Full verification and development delivery

#### Functional and backend tests

- Free enrollment creates a real retained edition grant.
- Genuine purchase status remains separate.
- Existing users retain start date, timezone, progress, and access.
- Future pricing cannot revoke an earned free grant.
- Both questions are required; perfect answers are not.
- Wrong-answer explanations and retries behave correctly.
- Server grading ignores client-provided scores.
- Attempt submission is idempotent.
- Legacy completions and pending work migrate without lost progress.
- Midnight, DST, leap days, catch-up, and day-365 limits remain correct.
- Reset rejects stale completion submissions.
- Account switching never exposes another account’s state.
- Billing outages cannot block the free learning flow.
- Account deletion covers new saved/resume/attempt data.

#### Offline and synchronization tests

- Resume after termination on every onboarding and lesson step.
- Resume the same semantic step on another device.
- Answer order and selections survive restoration.
- Previously unlocked lessons remain usable offline.
- New unlocks and initial journey creation require server confirmation.
- Saved changes and completed attempts survive restart and reconcile once.
- Local storage failures remain recoverable.
- Completion or reset prevents stale checkpoints from restoring old state.

#### Visual and interaction evidence

Produce a reviewed gallery covering every route and its important states, plus recordings of:

- Welcome.
- Complete onboarding.
- Tab taps and swipes.
- Navigation-bar minimization.
- Header scroll-under behavior.
- Roadmap navigation.
- Lesson drag, snap-back, questions, explanations, and completion.
- Saved sharing/removal.
- Settings, support, and destructive confirmations.

Compare relevant compositions and interactions beside Cognein’s actual reference behavior.

#### Accessibility and performance

Test compact and large phones, iPad portrait/landscape, split view, keyboard display, VoiceOver, 3× text, Reduce Motion, and Reduce Transparency.

Profile scrolling and deck interactions on the physical iPhone. Target the device’s frame budget, avoid sustained jank, and confirm that hidden screens/backgrounded apps do not keep decorative animation or delayed feedback running.

### Delivery artifacts

- Complete source implementation and migration notes.
- Updated screen-by-screen parity matrix.
- Full validated 365-lesson teaching catalog and question bank.
- Automated test results and physical-device evidence.
- Complete visual/state gallery and interaction recordings.
- New signed development build and verified distribution artifact with a build number above the uploaded build 1.
- Updated customer-facing website and prepared release materials.

The uploaded build 1 cannot be made free remotely because its client still requires purchase confirmation. It is superseded by the new implementation.

Use existing local signing for development verification. Keep Apple account setup, product changes, App Store upload/selection, submission, and release scheduling deferred until you resume that work.
