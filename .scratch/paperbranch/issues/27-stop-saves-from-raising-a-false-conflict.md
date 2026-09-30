# 27: Stop saves from raising a false external-change conflict

**What to build:** Saving a Markdown document writes it and leaves it clean. Paperbranch does not treat its own write as an external change, so no "Changes conflict" alert appears after a save.

**Blocked by:** 09: Resolve external changes with unsaved edits.

**Status:** ready-for-agent

- [ ] The cause of the false conflict is confirmed and recorded in Comments.
- [ ] Cmd+S on a dirty Library document writes the file, clears the edited state, and shows no conflict alert.
- [ ] Save from a Standalone window's close alert writes the file and shows no conflict alert.
- [ ] A real external change to a dirty document, made after a save finishes, still raises the conflict alert (ADR 0003).
- [ ] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Created 2026-09-30 from Ticket 25's visual check.

Seen in the packaged app, both on `92da965` and after Ticket 25's fix (`1d37d43`):

- Library window, `/private/tmp/pb15-library/Notes/Note.md`: typing an edit and pressing Cmd+S wrote the edit to disk, then showed "Changes conflict in Note.md. This Markdown document changed on disk while it has unsaved edits." with Keep Editing and Reload Disk. This happened 2 of 2 times. Screenshot at `/tmp/pb27-after-cmd-s.png`, not committed.
- Standalone window, `/tmp/pb25-outside/Outside.md`: choosing Save in the close alert wrote the edit, then showed the same conflict alert. Screenshot at `/tmp/pb25-stuck.png`, not committed.

Likely cause, not confirmed: `DocumentSession.save()` writes the file with `coordinatedWrite`, then awaits `coordinator.saveSucceeded(markdown:)`, and only afterwards sets `lastDiskMarkdown = markdown` and `isDirty = false`. `FileChangeMonitor` watches the document and its folder, so the atomic write signals it right away. If `reconcileFileSystemSignal()` runs during that await, it reads the new bytes, compares them with the old `lastDiskMarkdown`, finds the session still dirty, and calls `setConflict(.externalChange(fileURL))`. Confirm the ordering, for example with temporary logging, before fixing it.

This may also be why Save in the close alert does not close the window (Ticket 28): the conflict sheet may already be attached when the alert's `afterSave` calls `performClose`.
