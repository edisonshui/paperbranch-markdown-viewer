# 02: Open, edit, and save one Markdown document

**What to build:** Build the first complete Paperbranch workflow. The user opens one local Markdown document in a native Mac window, reads and edits it as formatted content, sees whether it has unsaved changes, and saves it back to the same file with `Command-S`.

**Blocked by:** 01: Prove formatted Markdown editing.

**Status:** resolved

- [x] Paperbranch launches as a native macOS application and can open one `.md` or `.markdown` file through an Open command.
- [x] The Document view uses the selected editor and follows the reading layout and visual direction of the Paperbranch brand guideline and design skill, which replaced Variant B of the approved prototype on 22 Oct 2026.
- [x] The user edits formatted content directly. Paperbranch provides no raw Markdown mode or split view.
- [x] The window indicates when the document has unsaved edits.
- [x] Typing does not write to disk, and the original file remains unchanged until the user invokes `Command-S`.
- [x] `Command-S` works while focus is inside the Document view, writes serialized Markdown to the original file, and clears the dirty state only after the write succeeds.
- [x] Equivalent syntax may normalize, but saving preserves the semantic structure covered by the editor contract.
- [x] A failed serialization or file write leaves the document dirty and shows an error for the affected document.
- [x] Closing a dirty document asks the user whether to save, discard, or cancel.
- [x] An application-workflow test opens a temporary Markdown file, edits it, proves the file remains unchanged before `Command-S`, saves it, and verifies the resulting file content.

## Comments

Reopened 2026-09-21 after the complete implementation review found that the current Document view does not yet match Variant B's visual direction.

Verified 2026-09-21:

- `cd editor-proof && ./native-host/test.sh` passed 7 native `WKWebView` tests, including real temporary-file no-write-before-save, save-after-edit, and failed-save-dirty workflows.
- `cd editor-proof && npm test` passed 46 Milkdown semantic editor-contract tests.
- `git diff --check` passed.

Implementation commit: `3060421ea50535a3c9cf7bb13d92d11157bf0da8`.

Resolved 2026-10-22 against the brand guideline. Edison decided on 22 Oct 2026 that the guideline and its design skill replace Variant B as the visual source (spec commit `5ff52fc`), so this criterion now reads against them. Evidence: `library-reading-light.png`, `library-reading-dark.png`, `library-editing-light.png`, and `library-editing-dark.png` in `.scratch/paperbranch-brand/switch-over/` (gitignored), taken in the packaged app after Tickets 39 to 44. Compared with guideline pages 10 and 11 and the skill's checklist: New York body text at 19 px on a 680 px column, a 40 px left-aligned title under an uppercase meta line, links and inline code in `--accent-text`, block quotes on a `--border` rule, and the formatting popover above a selection. Ticket 40's list-spacing follow-up (`4428a05`) landed after the screenshots, so their lists still show the old, looser spacing. Tests: `document-theme.spec.ts`.
