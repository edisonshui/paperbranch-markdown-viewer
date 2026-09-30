# 27: Stop saves from raising a false external-change conflict

**What to build:** Saving a Markdown document writes it and leaves it clean. Paperbranch does not treat its own write as an external change, so no "Changes conflict" alert appears after a save.

**Blocked by:** 09: Resolve external changes with unsaved edits.

**Status:** resolved

- [x] The cause of the false conflict is confirmed and recorded in Comments.
- [x] Cmd+S on a dirty Library document writes the file, clears the edited state, and shows no conflict alert.
- [x] Save from a Standalone window's close alert writes the file and shows no conflict alert.
- [x] A real external change to a dirty document, made after a save finishes, still raises the conflict alert (ADR 0003).
- [x] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Created 2026-09-30 from Ticket 25's visual check.

Seen in the packaged app, both on `92da965` and after Ticket 25's fix (`1d37d43`):

- Library window, `/private/tmp/pb15-library/Notes/Note.md`: typing an edit and pressing Cmd+S wrote the edit to disk, then showed "Changes conflict in Note.md. This Markdown document changed on disk while it has unsaved edits." with Keep Editing and Reload Disk. This happened 2 of 2 times. Screenshot at `/tmp/pb27-after-cmd-s.png`, not committed.
- Standalone window, `/tmp/pb25-outside/Outside.md`: choosing Save in the close alert wrote the edit, then showed the same conflict alert. Screenshot at `/tmp/pb25-stuck.png`, not committed.

Likely cause, not confirmed: `DocumentSession.save()` writes the file with `coordinatedWrite`, then awaits `coordinator.saveSucceeded(markdown:)`, and only afterwards sets `lastDiskMarkdown = markdown` and `isDirty = false`. `FileChangeMonitor` watches the document and its folder, so the atomic write signals it right away. If `reconcileFileSystemSignal()` runs during that await, it reads the new bytes, compares them with the old `lastDiskMarkdown`, finds the session still dirty, and calls `setConflict(.externalChange(fileURL))`. Confirm the ordering, for example with temporary logging, before fixing it.

This may also be why Save in the close alert does not close the window (Ticket 28): the conflict sheet may already be attached when the alert's `afterSave` calls `performClose`.

Resolved 2026-09-30. `DocumentSession.save()` sets `lastDiskMarkdown = markdown` right after `coordinatedWrite` and before it awaits `coordinator.saveSucceeded(markdown:)`. A file-system signal for Paperbranch's own write now finds the disk equal to the baseline. A later external change still differs from the baseline and raises the conflict while the document is dirty.

Confirmed cause, 2026-09-30:

- Temporary `NSLog` calls in `save()` and `reconcileFileSystemSignal()`, in a packaged build of `ecee216` with the Library at `/private/tmp/pb15-library`. Typing in `Notes/Note.md` and pressing Cmd+S logged, in order: "wrote file, awaiting saveSucceeded, isDirty=1", then "reconcile: isDirty=1", then "disk differs from baseline while dirty, setting conflict", and about 300 ms later "saveSucceeded returned, updating baseline". The conflict alert appeared (`/tmp/pb27-red-after-cmd-s.png`). So the monitor's signal for the save's own write ran `reconcileFileSystemSignal()` during the `saveSucceeded` await, while the baseline was still the old content and the session was still dirty. The logging was removed before commit.
- The Standalone close alert's Save calls the same `save()`, so it hit the same race.

Verified 2026-09-30:

- Red: `cd editor-proof/native-host && PAPERBRANCH_PACKAGED_APP_PATH="$PWD/.build/Paperbranch.app" swift test --filter BridgeCoordinatorTests/testSavingDirtyDocumentReportsNoConflictButLaterExternalChangeDoes` failed 3 of 3 runs with "Saving reported a conflict for Paperbranch's own write": the session reported `[externalChange(saved.md), nil]` during one save. The test opens a real file in a `DocumentSession` with its `FileChangeMonitor` running, edits it through the editor, saves it, and records every value passed to `conflictDidChange`, the callback AppDelegate uses to show the alert. It then edits again, replaces the file from outside, and checks that the conflict is reported. `PAPERBRANCH_PACKAGED_APP_PATH` points the test at the packaged app's bundled editor, as `verify-package.sh` does. Without it, or without the Vite server `test.sh` starts, the harness does not load.
- Green: the same focused test passed 3 of 3 runs. The presentation filter from Ticket 20 passed 14 of 14.
- `cd editor-proof/native-host && ./verify-package.sh`: Xcode Release build succeeded and all 56 packaged native tests passed.
- `git diff --check`: passed.
- Packaged app, `/private/tmp/pb15-library` at 1300x800, no older Paperbranch process running. `Note.md` and `/tmp/pb25-outside/Outside.md` were backed up first and restored afterwards.
  - Library, Cmd+S twice on a dirty `Note.md`: each wrote the edit ("Text. one", then "Text. One two") with no sheet on the window and no conflict alert.
  - Library, a dirty `Note.md` whose file was then atomically replaced from outside: the "Changes conflict in Note.md" alert appeared and the title read "Note.md (Conflict)". Reload Disk cleared it.
  - Standalone, `Outside.md` opened with the reader's Open button, made dirty, closed, and Save chosen in the close alert with a real click: the edit was written, no conflict alert appeared, and the window closed. Paperbranch kept running, the Library window stayed at (60, 33) 1300x800 on `Note.md`, and no new crash report appeared.
- Screenshots, not committed: `/tmp/pb27-red-after-cmd-s.png` (before the fix), `/tmp/pb27-green-after-cmd-s-1.png`, `/tmp/pb27-green-after-cmd-s-2.png`, `/tmp/pb27-green-external-conflict.png`, `/tmp/pb27-standalone-close-alert.png`, `/tmp/pb27-standalone-after-save.png`, and `/tmp/pb27-library-after-standalone-save.png`.

Differences outside this ticket, not fixed:

- An in-place external write after a Paperbranch save raises no conflict and no reload. The save's atomic write replaces the file, so `FileChangeMonitor`'s file watch stays on the old inode, and an in-place write does not change the folder. The focused test failed at the conflict check with an in-place write and passed with an atomic replacement. It failed the same way on the code before this fix, so it predates it. The test uses an atomic replacement and says why.
- After a save swaps the Library window back to the SwiftUI reader, the caret still shows but typed keys are dropped until the text is clicked again.
- macOS capitalized a word typed right before Cmd+S ("one" became "One") after the save, so the next save wrote the capitalized word.

Implementation commit: `ad82a57`.
