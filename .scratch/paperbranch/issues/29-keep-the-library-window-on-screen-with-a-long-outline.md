# 29: Keep the Library window on screen with a long outline

**What to build:** Stop the AppKit Library sidebar's document outline from growing the Library window past the screen and from hiding the Library tree.

**Blocked by:** 07: Add the document outline and reading progress.

**Status:** resolved

- [x] With a document of 60 headings, the AppKit Library window keeps its frame and the Library tree stays visible.
- [x] Outline entries are left-aligned and scroll inside the sidebar.
- [x] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Found 2026-10-22 in the UX audit, against a test Library with a 30-section essay (60 headings).

- After one keystroke the window swapped to the AppKit presentation and grew from 1300x935 to 1300x1360, past the 949-point screen. It stayed 1344 tall after saving and after toggling the sidebar.
- The AppKit sidebar showed only a centered column of outline buttons. The Library tree was squeezed out of view.
- Cause (read in code): `LibrarySidebarViewController` adds one `NSButton` per heading to a vertical `NSStackView` with no scroll view, so the stack's required height becomes the window's minimum content height.

Resolved 2026-10-22. The outline stack now sits in its own scroll view, capped at 40% of the sidebar's height and shrinking to fit a short outline. Its entries are left-aligned. The Library tree takes the rest.

Verified 2026-10-22:

- Red: `swift test --filter BridgeCoordinatorTests/testLongOutlineKeepsTheAppKitLibraryWindowFrameAndTreeVisible` failed. With 60 headings the Library tree was 0 points tall and the first heading sat 102 points from the sidebar's edge.
- Green: that test passed.
- `./verify-package.sh`: 63 packaged native tests passed. `npx playwright test`: 57 of 57 passed.

Implementation commit: `f2a5747`.
