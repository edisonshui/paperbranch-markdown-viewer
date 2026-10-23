# 46: Slide the sidebar and keep the reading position

**What to build:** Collapse and reopen the Library sidebar in one 200 ms slide (none under Reduce Motion), with the toggle beside the window buttons when collapsed, and keep the reading position on the same line.

**Blocked by:** 41: Restyle the Library window chrome.

**Status:** resolved

- [x] The sidebar and the column move in one `--duration-medium` slide.
- [x] The line at the top of the Document view stays there after the slide.
- [x] Focused tests pass red-to-green, then both suites pass.

## Comments

Created 2026-10-22. Part of the switch to the brand guideline.

Resolved 2026-10-22.

- The sidebar's collapsed state lives in `PaperbranchChromeLayout`, an observed object the rebuilt root view keeps, and `render(_:)` changes it inside `withAnimation(.easeInOut(duration: PBMotion.medium))`. There is no animation under Reduce Motion, or when the window comes back from the AppKit presentation. The sidebar leaves with `.move(edge: .leading)` while the reader widens in the same transaction, so the centered column moves with it. With the sidebar collapsed, the toggle sits 64 px in, beside the window buttons (Ticket 41).
- The editor keeps the reading position on any width change: it records the first block whose top edge is in view, and on resize scrolls by however far that block drifted. `html { overflow-anchor: none }` makes this the only mechanism, so Chromium in the tests behaves as WebKit in the app.
- Judgment call: the slide uses ease-in-out. The skill gives the duration but not the curve for native animation, and its CSS `--ease` curve has no SwiftUI equivalent here.

Verified 2026-10-22:

- Red: `reading-position.spec.ts` failed (the target paragraph moved from 100 to -546 px). `testSidebarSlidesInOneMediumDurationAndNotUnderReduceMotion` failed to compile.
- Green: both passed, the Playwright one 5 of 5 with `--repeat-each=5`, keeping the paragraph on the same line from 600 to 1000 px wide and back.
- `./verify-package.sh`: 78 packaged native tests passed. `npx playwright test`: 76 of 76 passed.
- Not seen in the running app: Edison was back at the Mac, so the slide itself needs his visual check.

Implementation commit: `505635a`.
