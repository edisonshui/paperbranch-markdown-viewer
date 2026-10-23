# 42: Move the outline to a right panel in wide windows

**What to build:** Show "On this page" as a 220 px panel on the right of the Document view when the window is 1240 px or wider, and under the Library tree below that. Mark the current heading with `--ink-strong` text and a 2 px `--accent` bar.

**Blocked by:** 41: Restyle the Library window chrome.

**Status:** resolved

- [x] At 1240 px and wider the outline is a right panel; below 1240 px it sits under the tree.
- [x] The current heading follows the reading position.
- [x] Focused tests pass red-to-green, then both suites pass.

## Comments

Created 2026-10-22. Part of the switch to the brand guideline.

Resolved 2026-10-22.

- The editor reports `currentOutlineID` with its navigation state: the last heading at or above the top fifth of the Document view, or the first heading before any. `window.editorContract.getCurrentOutlineID()` exposes it. Native code marks that entry `isCurrent` on `DocumentOutlineEntry`, so the navigation callbacks keep their signature.
- `PBOutlineRows` and `PBOutlinePanel` (`components.md` "Outline panel") render the entries. A `GeometryReader` on the window content puts them in a 220 px right panel at 1240 px and wider, and under the Library tree below that. Entries keep their `paperbranch.library.outline.<id>` identifiers in both places, and the current one carries the accessibility value "Current heading".
- Judgment call: "the current heading" is the last one whose top is within the top fifth of the Document view. The skill does not define the threshold.

Verified 2026-10-22:

- Red: Playwright "the current heading follows the reading position" failed (no `getCurrentOutlineID`). `testOutlineMovesToARightPanelInWideWindowsAndMarksTheCurrentHeading` failed to compile (no `isCurrent`).
- Green: both passed. At 1300 px the panel sits on the window's right edge, 220 px wide, with the current heading marked and no outline in the sidebar. At 1100 px there is no panel and the outline is under the tree.
- `./verify-package.sh`: 74 packaged native tests passed. `npx playwright test`: 75 of 75 passed.

Implementation commit: `16f4214`.
