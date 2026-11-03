The rest of the rebuild should proceed in two coordinated tracks: **finish and verify the complete learning experience**, and **author/review the remaining curriculum**. They should meet at a strict release gate covering all 365 lessons, rather than leaving the app with two learning formats.

The current implementation is a foundation. The last recorded checks show 48 passing Flutter tests, 24 passing backend tests, and preserved Scripture, but they do not establish complete Cognein parity, production readiness, or native-device correctness.

**The starting point**

| Area | Current position | Remaining outcome |
|---|---|---|
| Original curriculum | All 365 messages and verified WEB quotations preserved | Preserve them throughout the expansion |
| Enhanced lessons | Five authored lessons, ten questions | 365 finished lessons, 730 reviewed questions |
| Units | 73 unique headings exist | Review headings and finish accurate teaching summaries |
| Free access | Local backend implementation and transaction tests | Emulator verification, production inventory, deployment, and live acceptance |
| Presentation | Shared foundations and a partial rebuild | Actual Cognein composition, materials, movement, and interaction depth |
| Persistence | Initial attempts, bookmarks, drafts, and resume | Verified conflict handling, recovery, migration, and account isolation |
| Supporting screens | Several functional first passes | Every requested destination and applicable state completed |
| Evidence | 21 Flutter renders | Complete state gallery, recordings, reference comparisons, and device evidence |
| Development build | Version/build number advanced | Successful signed build and verified distribution artifact |
| Apple release work | Deferred | Remains deferred |

The detailed sequence follows.

---

**1. Restore a dependable development and verification environment.**

The first task is to remove the build bottleneck and establish a reproducible baseline.

- Create a clear checkpoint of the current source, including new files, without mixing in unrelated user changes.
- Preserve the existing archive, IPA, signing configuration, supplied artwork, and original verification files.
- Establish enough working disk space for CocoaPods, native compilation, Flutter intermediates, a signed app, and an export. The approximately 1.9 GB currently available is still too little for a dependable full build.
- Limit any cleanup to identified disposable project caches and intermediates. Moving or deleting unrelated files would require a separate decision.
- Record the Flutter, Dart, Xcode, CocoaPods, and dependency versions used for verification.
- Run the baseline analyzer, Flutter tests, backend tests, Scripture verifier, and generated-content checks.
- Confirm that the reference repository still matches its recorded source hashes.
- Obtain one successful development build using the existing signing configuration, with provisioning/account changes disabled.
- Arrange physical iPhone and iPad availability for later native testing.

The early build is useful for catching native integration problems before more work accumulates. It is not the final delivery build.

**Acceptance gate:** the source builds reproducibly, the existing checks pass, and the native verification environment is usable. Apple account setup, App Store configuration, uploads, submission, and scheduling remain outside this work.

---

**2. Turn the specification into an executable acceptance checklist.**

The parity matrix needs to become the working record for the rest of the project.

For every screen and shared interaction, record:

| Field | What it must contain |
|---|---|
| Reference | Exact Cognein file and observable behavior |
| HolyHer destination | Screen, component, or service responsible |
| Required behavior | Concrete actions and resulting states |
| Applicable states | Loading, cached, empty, offline, saving, failure, and others |
| Adaptive behavior | Compact phone, tablet, landscape, split view, large text |
| Accessibility | Reading order, focus, labels, motion/transparency alternatives |
| Verification | Automated check, render, recording, native test, or production check |
| Status | Unimplemented, implemented, locally verified, or accepted |

This prevents “the screen exists” from being mistaken for “the screen is finished.”

The checklist should also preserve the locked scope:

- White/blush identity, supplied icon, and Lexend.
- Exactly Learn, Saved, Profile.
- The same 365-day order and original quotations.
- Two understanding questions per lesson.
- No journal, written reflection feature, community, rankings, AI coaching, advertising, or payment flow.
- Daily calendar unlocking and retained free-edition access.
- Account-first authentication and synchronization.

**Acceptance gate:** every requirement has a destination and a defined way to prove it works. Nothing disappears between implementation, testing, and delivery.

---

**3. Harden persistence and synchronization before expanding the curriculum.**

This is the most important engineering work remaining. The current services need focused review and adversarial tests.

**Local persistence and recovery**

- Define which records must be saved together: an answer and its resume checkpoint, a completed attempt and its outbox entry, or a bookmark mutation and its pending operation.
- Assess whether the current preferences-based adapter provides the required atomicity and recovery behavior. Introduce a transactional local repository where related writes cannot safely be separated.
- Version local schemas and make migrations repeatable.
- Preserve unreadable raw records for recovery. A parsing error must not silently turn an existing outbox into an empty one that the next edit overwrites.
- Distinguish unavailable storage, corrupt data, and an ordinary empty account.
- Add failure injection around reads, writes, acknowledgments, and migrations.

**Attempt synchronization**

- Drain the queue until all currently eligible work is acknowledged, including attempts added while an earlier synchronization is running.
- Keep the visible completed-day set consistent with both server-confirmed completions and durably accepted pending attempts.
- Avoid briefly losing locally completed days when an older server response arrives.
- Separate connection failures from permanent rejection, stale journey revisions, unsupported content versions, and authentication failures.
- Give permanent failures an appropriate recovery path instead of retrying them forever.
- Keep the same attempt ID for retries.
- Test the server-accepted/client-acknowledgment-lost case.
- Preserve legacy completion work without inventing quiz results.

**Resume conflicts**

The current reader only adopts some remote checkpoints, and it does not yet have a complete ordering protocol.

- Add explicit checkpoint identity and ordering information.
- Use journey revision to reject pre-reset state.
- Use a server-controlled checkpoint revision or another defined conflict protocol for competing writes within the same journey.
- Define how local and remote checkpoints are reconciled when they belong to different practice attempts.
- Ensure delayed checkpoints cannot overwrite a newer completed or active attempt.
- Apply a selected remote checkpoint only when opening a lesson.
- Preserve semantic step, rendered part, attempt ID, answer selections, and option order.
- Keep an active reader steady when another device changes its checkpoint.
- Ensure an established offline lesson opens promptly from trustworthy local state.

**Bookmark conflicts**

- Give mutations operation IDs or generations, rather than identifying an acknowledgment solely by the saved/unsaved Boolean.
- Test save → remove → save while the first request is still running.
- Preserve removals as tombstones.
- Define how simultaneous changes from two devices resolve.
- Retry new changes added during a synchronization pass.
- Use the canonical server timestamp for settled Recent ordering.

**Account isolation**

- Recheck the UID/generation before applying every asynchronous result.
- Dispose private routes, readers, pending feedback, and loaded state on account changes.
- Keep every local write attached to the account that initiated it.
- Verify that an export cannot combine one account’s server data with another account’s local pending data.

**Acceptance gate:** termination, delayed responses, offline changes, concurrent edits, and account switching do not lose work, duplicate completions, resurrect reset data, or expose another account’s state.

---

**4. Finish backend access, migration, reset, deletion, and rules.**

The backend implementation has useful local tests. It now needs integration verification and a controlled rollout design.

**Retained free-edition access**

- Verify that first journey creation and the retained `holyher365` grant commit atomically.
- Verify that repeated starts preserve the original date, timezone, and completions.
- Keep eligibility, retained edition access, and genuine purchase ownership distinct in responses and UI.
- Test a future enrollment-policy change against previously granted accounts.
- Prove that refunds and billing webhooks cannot remove retained free grants.
- Confirm that all free-flow endpoints operate without contacting RevenueCat.

**Legacy inventory and backfill**

- Run a read-only inventory against the intended project using trusted credentials.
- Establish counts for existing journeys, retained grants, legacy entitlement records, and accounts needing migration.
- Review the distinction between an entitlement record and confirmed purchase history.
- Dry-run the grant backfill.
- Make the backfill resumable and repeatable.
- Record before/after counts and investigate discrepancies.
- Leave Apple product records and genuine legacy billing configuration unchanged.

**Progress reset**

- Add an operation ID so retrying an uncertain reset does not perform a second reset.
- Advance the journey revision atomically.
- Preserve start date, timezone, calendar availability, saved items, preferences, edition access, and retained activity history.
- Clean up obsolete attempts and resumes without deleting new work created after the reset.
- Recover correctly if revision advancement succeeds but cleanup or the response fails.
- Clear both old and new local resume formats so legacy positions cannot reappear.

**Account deletion**

- Verify deletion of every new collection and local account-owned record.
- Audit pending Firestore profile writes during deletion. Server callable guards alone do not establish that a delayed client write cannot recreate deleted profile data.
- Add a rule-enforced, server-owned deletion guard at a path the rules can evaluate.
- Test writes queued before deletion and delivered afterward.
- Make interrupted deletion safely retryable.
- Verify that the legacy cleanup queue is private, bounded per run, observable, and retried.
- Keep a billing outage out of the critical path for deleting a free account.

**Rules and integration tests**

Use Firebase emulators to prove:

- Owners can read their own permitted data.
- Other accounts and unauthenticated clients cannot.
- Clients cannot write grants, journey progress, graded attempts, or server-owned resume records directly.
- Profile fields and values are validated.
- Deletion guards block delayed writes.
- Legacy clients retain the intended compatibility behavior.

**Acceptance gate:** emulator integration passes, migration is repeatable, and the complete free flow is ready for a real-project test. Local transaction-harness results remain clearly distinguished from production evidence.

---

**5. Finish the shared Cognein presentation system.**

This should be completed before polishing every remaining route.

**Backdrop and materials**

- Match the actual reference composition and motion in HolyHer’s white, pearl, and blush palette.
- Confirm that there is one persistent ambient controller.
- Preserve its position across tabs and pushed routes.
- Stop decorative work when backgrounded or otherwise inactive.
- Finish the Reduce Motion and Reduce Transparency variants.
- Verify that the supplied icon artwork remains intact.

**Headers**

- Finish genuine scroll-under composition.
- Match the progressive tint and blur behavior, rather than applying a uniform blur to a separate header row.
- Keep text readable over moving content.
- Use the shared treatment on secondary screens.
- Verify safe-area calculations without double toolbar padding.
- Preserve native back gestures.
- Keep lessons immersive without adding redundant chrome.

**Bottom navigation**

- Finish the native adaptive glass implementation where supported.
- Complete the custom fallback.
- Drive the selected pill continuously from page position during swipes.
- Verify the approximately 300 ms tap transition.
- Finish the approximately 68-point expanded and 52-point compact geometry.
- Distinguish sustained user scrolling from programmatic movement, bounce, and nested scroll views.
- Expand on upward scrolling, tab changes, top return, and compact-bar interaction.
- Preserve labeled navigation for accessibility configurations.
- Retain each tab’s content, search, filters, and scroll position.

**Controls and feedback surfaces**

- Apply the actual shared press mechanics everywhere appropriate.
- Remove duplicate generic and semantic haptics.
- Standardize loading buttons, five-dot loaders, notices, sheets, dialogs, and errors.
- Finish focus states and minimum touch targets.
- Make reduced-motion route transitions consistent.

**Acceptance gate:** representative phone and iPad screens match the reference’s interaction quality, with recordings and accessibility variants. Shared components are then reused across all routes.

---

**6. Make the first five lessons the finished vertical slice.**

The five existing enhanced lessons need a full editorial and interaction review before their structure is propagated.

For each lesson, verify:

| Step | Required finished result |
|---|---|
| Opening | Original title/day and a clear, teachable objective |
| Verse | Exact pinned WEB quotation, reference, and attribution |
| Understand | Accurate context and explanation in simple English |
| Question 1 | Four plausible options, one correct answer, grounded explanation |
| Confidence | Original encouragement connected to the teaching |
| Hope | Practical encouragement with Scripture clearly distinguished |
| Question 2 | Application-understanding check with four plausible options |
| Carry | A concrete takeaway requiring no writing |
| Closing | Summary, result, actual save state, celebration, and Continue |

The review should check that a reader can answer from the lesson itself. It should also catch ambiguous alternatives, accidental second correct answers, unsupported promises, and explanations that merely repeat the correct option.

Use these five lessons to exercise:

- Long passages and teaching.
- Correct and incorrect answers.
- Backtracking.
- Exit and resume.
- Local save failure.
- Pending cloud synchronization.
- Repeated practice.
- Large text, landscape, and VoiceOver.

**Acceptance gate:** these five lessons demonstrate the final content standard and the final end-to-end learning behavior.

---

**7. Complete the learning deck’s presentation and state machine.**

Finish the deck against the real source behavior.

**Cards and pagination**

- Complete card geometry, edge illumination, lift, and transitions.
- Implement the reference water-style progress treatment.
- Paginate ordinary long teaching content without changing semantic step identity.
- Preserve location through text-size changes, rotation, and changed pagination.
- Use natural scrolling for large text, short landscape windows, and long questions.
- Keep cards within an approximately 560-point readable width.
- Ensure previously viewed cards return at rest.

**Navigation and questions**

- Keep Next and forward swipe governed by the same rules.
- Require an answered question before moving forward.
- Allow backward navigation.
- Preserve the first selected option for the attempt.
- Restore the exact saved option ordering.
- Resist and safely settle first/last boundaries.
- Reserve feedback space where practical.
- Make correctness understandable through text and icons as well as color.

**Completion**

Represent completion as explicit states:

`Reading → Closing → Saving locally → Accepted locally → Pending sync / Synced`

Include recoverable local failure and cloud rejection paths.

- Entering Closing initiates one idempotent acceptance.
- No earlier card can complete the lesson.
- Continue waits for local acceptance.
- Continue can interrupt celebration.
- Returning to a completed lesson creates practice without increasing completed-day counts.
- Leaving cancels remaining effects.

**Sound and haptics**

- Finish preload, rapid repeated cues, interruption, and disposal behavior.
- Verify silent-switch handling and mixing with existing audio.
- Keep incorrect answers silent.
- Verify independent preferences and immediate application.
- Drive completion visuals and feedback from one 2.8-second clock.
- Check crest/settle timing on actual hardware.

**Accessibility**

- Announce semantic step, position, selected/correct answer state, and save status.
- Exclude hidden cards from accessibility.
- Make full text available immediately.
- If text reveal is used, provide an immediate finish action.
- Verify keyboard navigation and focus restoration.

**Acceptance gate:** every learning interaction works with real persisted state, including offline use and native feedback.

---

**8. Author and review the remaining 360 lessons and 720 questions.**

This is the largest content workstream and should proceed in bounded batches once the five-day standard is settled.

A practical batch is five units:

- 25 lessons.
- 50 questions.
- Five unit summaries.

The final batch can be smaller.

For each lesson:

1. Read the original message and pinned passage.
2. Write one objective.
3. Deepen context without replacing the original core teaching.
4. Write the verse-understanding question.
5. Connect Confidence and Hope to the teaching.
6. Write the application-understanding question.
7. Replace the writing prompt with a practical takeaway.
8. Write the closing summary.
9. Review all options, explanations, and source links.
10. Run structural and Scripture checks.

Track editorial status separately:

| Status | Meaning |
|---|---|
| Drafted | Content exists |
| Structurally validated | Required fields, IDs, links, and option rules pass |
| Editorially reviewed | Meaning, clarity, and distractors have been checked |
| Revised | Review findings have been addressed |
| Accepted | Ready for the final catalog |

Automated validation must not mark content editorially reviewed.

Additional checks should catch:

- Repeated or formulaic questions.
- Ambiguous answers.
- Correct answers distinguishable mainly by length or tone.
- Questions about feelings or faithfulness.
- Context unsupported by the passage.
- Devotional prose presented as Scripture.
- Unsupported promises about health, money, or outcomes.
- Placeholder text and unfinished explanations.
- Excessive reading burden on a single card.

Review all 73 unit headings and give each unit a concise, accurate teaching summary based on its five messages.

Keep stable question/option IDs. Establish how content versions remain supported for outstanding attempts so a catalog update does not invalidate durable offline work unexpectedly.

**Acceptance gate:** 365 enhanced lessons, 73 reviewed units, exactly 730 reviewed questions, and a passing full-content verifier. The ordinary customer flow then uses the guided format for every day.

---

**9. Complete Learn, the roadmap, and progress/calendar.**

The remaining Learn work should make the whole year understandable and easy to resume.

- Prioritize a valid unfinished lesson resume; otherwise choose the earliest unfinished unlocked lesson.
- Show a truthful Resume destination and location.
- Finish distinct completed, in-progress, available, recommended, and future node states.
- Add the actual winding path, illumination, and checkpoint treatment.
- Auto-reveal the recommended node once after initial layout.
- Preserve browsing position afterward.
- Add Return to current when browsing away.
- Keep the roadmap virtualized, including animation and listener lifetimes.
- Finish unit previews with teaching summary, range, completion count, and available lessons.
- Complete the searchable accessible list.
- Replace the current activity-date presentation with a proper calendar surface using actual recorded dates.
- Finish milestone presentation at 7, 30, 90, 180, and 365 completed lessons.
- Display the actual next unlock date in the journey timezone.
- Distinguish caught up, all available, and all completed.

Test a new journey, missed days, many available lessons, pending completions, resumed lessons, day 365, and the completed year.

**Acceptance gate:** users can find their place, understand availability, and browse the full year without losing context or encountering payment navigation.

---

**10. Finish welcome, authentication, and onboarding.**

**Welcome and authentication**

- Complete the reference-derived choreography in all three genuine scenes.
- Preserve five settled seconds and approximately 680 ms transitions.
- Preserve manual controls and the current scene after authentication cancellation or failure.
- Stop automatic advancement under Reduce Motion.
- Finish validation, visibility, autofill, keyboard, reset, loading, cancellation, failure, and retry states.
- Verify Apple, Google, and email on native devices using the existing configuration.
- Keep About, Help, Privacy, and Terms reachable before authentication.
- Confirm returning users avoid a welcome flash.

**Onboarding**

- Make the preview use the actual four-option question component.
- Finish coordinated progress, backdrop, option entrances, and step transitions.
- Use semantic step IDs as the durable navigation identity.
- Verify immediate draft saving and debounced cloud checkpoints.
- Make local and cloud save states distinguishable.
- Verify summary edits return to Summary.
- Request notification permission only after explicit opt-in.
- Handle denial, changed device permission, scheduling failure, and skip.
- Verify every step with keyboard and 3× text.

Test termination at every step and every finalization boundary:

`Setup saved → Day 1 preview → Journey acknowledged → Profile acknowledged → Day 1 opens`

Also test an existing onboarded account with no journey and an existing journey with interrupted profile finalization.

**Acceptance gate:** fresh, returning, interrupted, offline, denied-permission, and slow-network paths all recover to the correct place.

---

**11. Complete Saved.**

Finish the remaining product behavior:

- A dedicated verse-detail sheet.
- Open full lesson from detail.
- Text sharing and white/blush image sharing.
- Readable image layout for short and long passages.
- Reference and WEB attribution on every shared Scripture artifact.
- Correct iPad share-sheet anchoring.
- Consistent bookmark state in verse cards, actions, previews, detail, and Saved.
- Theme filtering, Recent/Day order, and retained search state.
- Natural-height tablet layouts at actual split-view constraints.
- Clear saving, pending, failed, and retry states.
- Accessible removal with short undo.
- Empty and no-results states.

Test receiving new bookmarks or removals from another device while Saved is already loaded.

**Acceptance gate:** save, synchronize, find, open, share, remove, undo, and retry all work across phone and iPad.

---

**12. Complete Profile, settings, account, and data management.**

**Profile and identity**

- Build the dedicated identity editor with name validation, private initials/brand avatar, save, cancel, and unsaved-change handling.
- Show actual saved count, progress, streak, and milestones.
- Read edition status from authoritative access data, with truthful cached/offline treatment.
- Finish the wide iPad two-column composition.
- Keep learning-setup editing separate from journey creation.

**Preferences**

- Verify immediate sound/haptic changes and previews.
- Finish standard/larger reading text with a representative preview.
- Preserve natural system scaling through 3×.
- Make Tips actually govern contextual guidance.
- Add tutorial replay without changing progress.
- Finish reminder permission status, denial recovery, and return-from-device-settings reconciliation.

**Account and data**

- Show provider-appropriate account actions.
- Finish password validation, recent authentication, success, and failure.
- Export profile, preferences, attempts/history, saved items, and pending local changes in a readable, versioned format.
- Finish reset and deletion progress/retry states.
- Make sign-out handling accurately describe unsynchronized changes.
- Test partial export/reset/deletion failures and account changes during those operations.

**Acceptance gate:** every visible action has a complete destination and an honest success, pending, or failure outcome.

---

**13. Finish help, tutorials, support, legal, and prepared public materials.**

- Build searchable help categories and FAQ.
- Cover cards, questions, unlocking, catch-up, bookmarks, offline use, synchronization, accounts, reset, deletion, and edition access.
- Build short interactive tutorials from the actual card, question, roadmap, and bookmark components.
- Keep tutorials clearly identified and separate from real progress.
- Finish support and feedback submission states, rate limiting, retry, and duplicate-submission handling.
- Verify actual delivery in the intended environment.
- Finish About with publisher, installed version/build, attribution, and working links.
- Keep complete offline policy text synchronized with prepared hosted documents.
- Review website, screenshots, description, promotional copy, review notes, and release notes against the finished app.

The public website should be published only when its statements match the corresponding customer experience.

**Acceptance gate:** support delivery is proven, help answers are accurate, tutorials work, and prepared materials describe shipped behavior.

---

**14. Perform the complete verification pass.**

Use four evidence layers.

| Layer | Required evidence |
|---|---|
| Automated logic | Content, calendar, access, grading, queues, revisions, migration, isolation |
| Emulator integration | Real callable/Firestore behavior, rules, transactions, ownership, deletion |
| Render and interaction | Every route, important states, gestures, reference comparisons |
| Native device | Authentication, notifications, sharing, audio, haptics, accessibility, performance |

The functional scenario set must include:

- Fresh free enrollment with no purchase.
- Existing purchased and unpaid accounts.
- Existing journey and missing-journey recovery.
- Wrong answers and repeated practice.
- Duplicate completion requests.
- Network loss before and after server acceptance.
- Termination on every onboarding and lesson step.
- Two-device resume and bookmark conflicts.
- Reset while another device is offline.
- Deletion while work is queued.
- Account switching during in-flight requests.
- Midnight, timezone boundaries, DST, leap days, catch-up, and day-365 limits.
- Local storage failure and corrupt local records.

The accessibility/adaptive matrix must include:

- Compact and large phones.
- iPad portrait and landscape.
- Narrow and intermediate split view.
- Keyboard open.
- 3× text and larger-reading preference.
- VoiceOver.
- Keyboard focus and activation.
- Reduce Motion.
- Reduce Transparency.

Profile roadmap scrolling, deck movement, and native transitions on the physical iPhone. Investigate sustained missed frame budgets, unnecessary rebuilds, hidden animations, and delayed cues after exit/backgrounding.

**Acceptance gate:** no unresolved critical data-loss, access, account-isolation, completion, or accessibility defect; visual deviations are explicitly resolved or recorded against the agreed specification.

---

**15. Produce complete evidence and the final development delivery.**

Replace partial evidence with a reviewed package:

- Screen/state gallery covering every route and applicable state.
- Welcome recording.
- Full onboarding recording.
- Tab tap/swipe and bar-minimization recording.
- Header scroll-under recording.
- Roadmap browsing/current-node recording.
- Lesson drag, resistance, questions, explanations, resume, and completion recording.
- Saved detail, text/image sharing, removal, and undo recording.
- Settings, support, and destructive-confirmation recordings.
- Relevant side-by-side Cognein comparisons.
- Automated and emulator results.
- Physical-device accessibility and performance results.
- Final parity matrix and migration notes.
- Full catalog and editorial status report.

Build the final signed development app with a build number above uploaded build 1. Verify its signature, identifier, version/build, entitlements, embedded content/assets, installation, launch, and native behavior.

Create the appropriate development distribution artifact using existing signing, verify that artifact, and record its checksum.

**Acceptance gate:** the delivered source, content, evidence, and installable artifact all correspond to the same verified revision. App Store upload, submission, and scheduling remain deferred.

---

**16. Roll out backend and public changes in dependency order.**

The rollout sequence should be:

1. Complete emulator and migration dry-run checks.
2. Finish the real-project read-only inventory.
3. Deploy compatible backend functions and rules.
4. Run and reconcile the retained-grant backfill.
5. Verify free enrollment and completion with a real no-purchase test account.
6. Verify legacy compatibility, reset, deletion, and support delivery.
7. Verify the signed replacement against that backend.
8. Publish aligned website/support/legal content.
9. Deliver the verified development artifact and rollout report.

A rollback plan must preserve newly earned free grants, completed attempts, and existing journeys. A failed deployment must never reactivate a payment requirement for accounts that already received retained access.

Uploaded build 1 remains a separate limitation: it still contains its original client purchase gate until replaced through the later Apple distribution work.

---

**The state checklist that applies throughout**

Every applicable screen should be checked against this catalog:

| State | Required behavior |
|---|---|
| Initial loading | Shared loader describing real work |
| Cached refresh | Existing usable content stays visible |
| Empty | Clear explanation and useful next action |
| No search results | Clear query/filter recovery |
| Offline usable | Previously verified content remains available |
| Connection required | Explain why first start or new unlock needs confirmation |
| Saving | Prevent duplicate action and describe actual persistence |
| Saved locally | Confirm local acceptance accurately |
| Pending sync | Explain what is pending and offer retry where useful |
| Recoverable failure | Preserve work and provide an appropriate retry |
| Authentication cancelled | Return to the same context |
| Permission denied | Keep the flow usable and explain recovery |
| Disabled action | Explain what is required |
| Destructive action | Clear consequence, confirmation, progress, and recovery |
| Future lesson | Calendar explanation with timezone/date; no payment route |

**How to manage the November 15 target**

November 15 should remain a target subject to these gates.

The content arithmetic alone is substantial: 360 lessons and 720 questions across a 15-day window means **24 lessons and 48 questions per calendar day**, before final revision and verification. Reserving three days for final integration and delivery raises that to **30 lessons and 60 questions per authoring day** over the remaining twelve days.

The first complete 25-lesson batch should establish actual drafting, review, revision, and integration throughput. That measurement, together with the first successful native build and the persistence test results, should determine whether the target remains credible.

The immediate execution order is therefore:

1. Restore build capacity and establish the native baseline.
2. Fix persistence, conflict handling, and deletion/reset recovery.
3. Finish shared presentation components.
4. Finish and review the five-day learning slice.
5. Begin reviewed curriculum batches while completing the remaining screens.
6. Integrate all 365 days into one guided format.
7. Complete production verification, device testing, evidence, and signed delivery.

The existing [parity matrix](/Users/amir/Downloads/HolyHer/store/COGNEIN_SCREEN_MAP.md) and [migration report](/Users/amir/Downloads/HolyHer/store/REBUILD_MIGRATION.md) should remain the records updated as each gate is satisfied.