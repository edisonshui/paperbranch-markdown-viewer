# 41: Restyle the Library window chrome

**What to build:** Rebuild the SwiftUI chrome from `components.md`: sidebar, wordmark, section labels, Library rows, the Open now card with Edited, the top bar with status, the reading progress line, and buttons. The Library window follows the macOS appearance.

**Blocked by:** 39: Bring the design tokens into the app.

**Status:** ready-for-agent

- [ ] Every chrome color comes from `PBColor`, and no `Color(red:green:blue:)` literal remains.
- [ ] The Library window follows the system appearance in both presentations.
- [ ] Rows are 28 px with a full-width hit area; the selected row has a `--row-selected` fill, `--ink-strong` text, and a 2 px `--accent` bar.
- [ ] The Open now card shows the word count and, with unsaved edits, a dot and "Edited". The top bar shows "· Edited" or "· Changed on disk".
- [ ] Existing accessibility identifiers and labels keep working.
- [ ] Focused tests pass red-to-green, then both suites pass.

## Comments

Created 2026-10-22. Part of the switch to the brand guideline.
