# Rendered design review

Selected direction: **A — Pearl light**. B and C are deliberate development studies, never additional product themes. See the nine-frame comparison in the gallery. B uses an open paper edge and ribbon composition; C uses broad opaque surfaces and a sculpted seal. A keeps layered reading objects and directional pearl material.

## Reference evidence and limits

The reference source is Cognein commit `633680c84cec9a1b509f5092e8e2129562a6e047`. A separate temporary checkout was built and rendered on the same 393 × 852 iOS simulator. The user's dirty reference repository was not edited.

`reference/cognein-welcome-393.png` is its actual welcome route. `reference/cognein-name-393.png` uses its original name stage and onboarding scaffold. `reference/cognein-surface-393.png` renders its original lesson surface with explicit comparison copy; it is a component specimen, not a captured authenticated lesson. The fixture source is retained as `reference/preview_main.dart.txt`.

The comparison establishes rendered spatial/material references for welcome, setup shell, and lesson surface. It does **not** establish full screen-by-screen Cognein motion or performance parity. No numerical parity score is assigned.

## Defects found and revisions made

| Visible or behavioral defect | Revision |
|---|---|
| Physical startup attempted to mutate a read-only system font table | Allocated writable copies of CoreText tables before metric/checksum adaptation; rebuilt and reinstalled on the actual iPhone. |
| A rounded family name alone rendered the wrong advances | Resolved the actual UIKit design, corrected system tracking and semibold variation mapping in memory, and measured Flutter against a native specimen. |
| Welcome objects overflowed compact and 2× text layouts | Measured content and available stage height. Compact product objects keep identity without shrinking text; provider actions and links remain reachable by scrolling. |
| Authentication branding/segmented labels clipped at large text | Reflowed the brand row and replaced the fixed segmented control with measured flexible choices. |
| Roadmap rows clipped long titles at 2× text | Calculated row height from actual scaled title/reference text and kept the winding route aligned to node centers. |
| Returning-reader captures concealed the first-day progress composition | Separated first-day and resumed fixtures; retained the real one-time current-node reveal behavior. |
| Ruler labels wrapped inside narrow ticks | Gave tick labels their own overflow width while preserving the 20-point tick rhythm and semantic increment/decrement actions. |
| iPad welcome left a large unused lower field | Let the product stage use the tablet viewport budget while keeping the 290-point physical page and narrow action column. |
| Standard secondary header titles inherited a pale foreground | Applied the ink action role explicitly to shared header titles. |
| Calendar app visits looked like lesson completion evidence | Added durable actual completion dates and a genuine month grid; older unknown dates remain unmarked. |
| Future milestone rows inherited a success check | Assigned explicit lock/check states with readable remaining counts. |
| Navigation did not observe nested user scrolls correctly | Restricted the listener to the correct PageView child depth; tests distinguish user movement from programmatic scrolling. |
| Zero-duration scroll animations asserted under Reduced Motion | Used immediate jumps for reselection, current-node return, and ruler adjustments. |
| Selected answer could advance after a failed local save | Kept the selected identity, blocked advance, and exposed Retry until persistence succeeds. |
| Saved verse custom semantics concealed overflow actions | Kept independent child semantics and added an accessibility action regression check. |
| Legacy completion failure could discard reading position | Awaited accepted completion before clearing the saved position. |
| Signup completion rebuilt progress and briefly lost enrolled state | Updated the completion flag without replacing the journey notifier. |

## Composition decisions

Welcome shows actual Day 1 pages, a physical route and a ribbon-marked kept verse. Learn uses one compact progress instrument and an open winding route. Saved gives the verse excerpt priority on an open library canvas. Profile uses one identity object, equal statistics and quiet grouped navigation. Settings and legal/help surfaces keep open typography and dividers rather than repeating featured cards. The reader makes Scripture, explanation, question, confidence, practical hope and carry distinct through hierarchy and spacing.

The background owns one ambient paint layer. Featured objects have directional shading, fine top edges and layered shadows; input/option rows use quiet inset material. Floating chrome has blur that falls off alongside its tint, plus the native iOS glass path where available. Large lists remain lazy and contain no individual backdrop blur per row.

## Acceptance still requiring a person/device

Physical gesture feel, VoiceOver traversal/announcements, silent-switch audio, native autofill/provider sheets, notification transitions, native share-sheet placement, actual iPad system Split View, and profile-mode performance remain release gates. Simulator movies demonstrate the implemented mechanics; they do not prove on-device frame pacing or full reference parity. See `VERIFICATION.md` for measured coverage and the remaining gates.


## Second design pass, following the user's rejection of the initial result

The first gallery is retained as historical evidence. It is not presented as proof of the revised design. The current review entry is `index.html`, with physical-device evidence and offscreen composition review explicitly distinguished.

| Visible or behavioral defect | Corresponding revision |
|---|---|
| Featured surfaces read as plain white cards | Added directional pearl shading, an optical rim, top highlight, restrained rose edge illumination, and softer layered shadows. |
| Roadmap nodes looked like flat stock-icon circles | Built sculpted medallions with a lit face and base, engraved book geometry, current halo, actual progress arc, and distinct completed/future states. |
| Book previews and the Saved empty state lacked a meaningful object | Drew layered reading pages with a spine and satin ribbon; no substitute Scripture is painted into the illustration. |
| Profile identity looked generic and email wrapped poorly at large text | Added a pearl identity medallion and a reflowing identity composition. Large text gives the email its own full-width line region. |
| Onboarding options repeated unrelated stock icons | Added a consistent line vocabulary for familiarity, obstacles, and focus. Returning and regular reading have distinct symbols. |
| Reminder time label inherited an unreadable foreground | Set explicit ink for chip labels and a distinguishable interactive outline. |
| Guided conversation content appeared simultaneously | Added one-shot guide, option, response and feedback reveal timing while retaining the real selection and authored explanation. |
| Plan reveal placed Day 1 behind later lessons | Put Day 1 in front and reserved different saved/saving fan positions. |
| Saved controls clipped at 2× text | Replaced the underlined theme dropdown with a wrapping menu capsule; filters and sorting reflow. |
| Calendar repeated a generic headline and clipped milestone numbers | Composed around the month, actual completion count and open statistics; measured milestone discs to fit scaled numerals. |
| Learn's return action scrolled away; late journeys used approximate offsets | Kept Return to today above the navigation, and shared measured unit geometry between lazy rendering and current-node scrolling. |
| Caught-up and completed years scrolled past their state message | Kept the state composition at the top and added direct revisit/Saved actions for the completed year. |
| The two reader formats had different chrome and redundant progress UI | Shared one close/count/bookmark header and progress tube; removed the extra legacy header and bottom progress dots. |
| Fixed portrait proportions became too narrow on short phones | Kept the 9:16 stage on spacious screens; short screens and large text use full-width natural pages with independent scrolling and visible actions. Extreme text can scroll the complete composition. |
| Legacy completion could clear reading position after rejection | Required accepted completion before clearing the durable position; added a focused regression test. |
| Restore errors lacked a visible exit | Added consistent recovery chrome and preserved unreadable positions while leaving. |
| Help and legal content repeated small text inside cards | Used open headings, readable body typography, question accordions and dividers. |
| A custom accessibility label hid the navigation tap action | Exposed the action on the labeled semantics node and tested actual accessibility activation. |
| A future-node material branch supplied incompatible gradient stops | Corrected the future-state gradient; late-journey rendering and tests cover it. |

Composition review used real Flutter widgets with system rounded tables resolved on macOS and streamed only in memory. It is explicitly **not native iOS font or performance evidence**. The iPhone installation uses the actual UIKit rounded adapter. Physical finger feel, VoiceOver traversal, and an actual iPad review remain separate checks.
