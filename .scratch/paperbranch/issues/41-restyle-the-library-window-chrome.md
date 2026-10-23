# 41: Restyle the Library window chrome

**What to build:** Rebuild the SwiftUI chrome from `components.md`: sidebar, wordmark, section labels, Library rows, the Open now card with Edited, the top bar with status, the reading progress line, and buttons. The Library window follows the macOS appearance.

**Blocked by:** 39: Bring the design tokens into the app.

**Status:** resolved

- [x] Every chrome color comes from `PBColor`, and no `Color(red:green:blue:)` literal remains.
- [x] The Library window follows the system appearance in both presentations.
- [x] Rows are 28 px with a full-width hit area; the selected row has a `--row-selected` fill, `--ink-strong` text, and a 2 px `--accent` bar.
- [x] The Open now card shows the word count and, with unsaved edits, a dot and "Edited". The top bar shows "· Edited" or "· Changed on disk".
- [x] Existing accessibility identifiers and labels keep working.
- [x] Focused tests pass red-to-green, then both suites pass.

## Comments

Created 2026-10-22. Part of the switch to the brand guideline.

Resolved 2026-10-22.

- `PaperbranchComponents.swift` holds the `components.md` parts: `PBWordmark`, `PBSectionLabel`, `PBLibraryRow`, `PBOpenNowCard`, `PBButtonStyle`, `PBDocumentStatus`, `PBTopBar`, and `PBReadingProgress`. They differ from the snippets only where they take the caller's accessibility label, keep the existing identifiers, or (top bar) take a leading inset and labelled toggle. `PaperbranchWindowPresentation.swift` composes them, and both files are now in the Xcode project.
- The Library window no longer forces `.darkAqua` (Ticket 16's choice), so it follows macOS in both presentations.
- Judgment call: the guideline puts the window buttons in the 52 px top bar's row. AppKit centers them there only with a unified toolbar, so the Variant B presentation attaches an empty unified toolbar, with the title bar separator off, and the AppKit fallback gets its own toolbar back on restore.
- The sidebar outline ("On this page") keeps its place under the tree until Ticket 42.

Verified 2026-10-22:

- Red: `testLibraryChromeFollowsTheAppearanceWithTokenColors`, `testChromeUsesTokenColorsOnly`, `testLibraryAndStandaloneWindowsFollowTheSystemAppearance`, and the Edited case of `testLibrarySidebarShowsOpenNowAboveCollapsibleFolders` failed.
- Green: all passed. The sidebar pixel is compared with a `--sidebar` swatch rendered in a window of the same appearance, because the bitmap capture shifts colors (measured: `#161618` reads as `#1D1D20` in both the sidebar and the swatch).
- `./verify-package.sh`: 73 packaged native tests passed. `npx playwright test`: 74 of 74 passed.
- Packaged app, light appearance, throwaway Library in `/tmp`: blue P tile, Open now card, selected row with its 2 px blue bar, window buttons centered in the top bar's row, document name in the top bar.

Implementation commit: `3305bb0`.
