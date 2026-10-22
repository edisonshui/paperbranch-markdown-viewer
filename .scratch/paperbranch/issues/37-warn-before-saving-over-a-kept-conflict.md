# 37: Warn before saving over a kept conflict

**What to build:** After a conflict where the user keeps their edits, make the next save ask before it replaces the disk version, whether it comes from Command-S, File > Save, or Save in the Ticket 35 switch prompt.

**Blocked by:** 35: Protect unsaved edits when switching Library documents.

**Status:** resolved

- [x] After Keep Editing, the next save shows the existing "Overwrite newer disk version" alert (Overwrite, Cancel) before writing.
- [x] Cancel writes nothing and keeps the document dirty.
- [x] Overwrite writes the in-memory version and clears the conflict.
- [x] Save in the Ticket 35 switch prompt follows the same rule, and Cancel in the overwrite alert keeps the current document.
- [x] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Decision

Decided by Edison 2026-10-22, relayed by the coordinator: specification user story 28 applies. Keeping edits after a conflict never authorizes a silent overwrite, so the next save always asks.

## Comments

Found 2026-10-22 while testing Ticket 35. When a dirty document changes on disk, `DocumentSession.reconcileFileSystemSignal()` makes the changed file the new baseline (`lastDiskMarkdown`). After Keep Editing, `save()` compares the disk with that baseline, finds them equal, and writes with no warning. The warning appeared only when the file changed again before the monitor saw it.

Resolved 2026-10-22. `DocumentSession.keepEditing()` now marks the in-memory edits as kept over the disk version when a conflict is open. Until an overwrite, a disk reload, a clean external reload, or a new open clears that mark, `save()` throws `overwriteConfirmationRequired`, which every save path already turns into the "Overwrite newer disk version" alert. Cancel writes nothing and the document stays dirty. Overwrite writes, clears the mark, and clears the conflict.

Verified 2026-10-22:

- Red: `testSaveAfterKeepingASingleConflictAsksBeforeOverwriting` failed: the save after Keep Editing wrote without asking. The overwrite branch added to `testSwitchingAwayFromUnsavedEditsAsksToSaveCancelOrDiscard` failed: no overwrite alert appeared.
- Green: both passed. In the switch test, Save then Cancel kept A open, dirty, and selected, with the disk version untouched. Save then Overwrite wrote A and opened B.
- `./verify-package.sh`: 70 packaged native tests passed. `npx playwright test`: 68 of 68 passed three times. One earlier run had a single `strikethrough.spec.ts:31` failure, a typing-based test like the known flaky ones; this ticket changed no web code.

Implementation commit: `cd0b1c9`.
