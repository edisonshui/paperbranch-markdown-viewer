# 28: Close Standalone windows after Save or Discard in the close alert

**What to build:** When a dirty Standalone window is closed and the user chooses Save or Discard in the alert, the window closes. Cancel keeps it open with its edits.

**Blocked by:** 25: Stop closing a Standalone window from crashing Paperbranch; 27: Stop saves from raising a false external-change conflict.

**Status:** ready-for-agent

- [ ] The cause of each window staying open is confirmed and recorded in Comments.
- [ ] Discard closes the window and leaves the file on disk unchanged.
- [ ] Save writes the file and then closes the window.
- [ ] Cancel keeps the window open with its edits, and a later close shows the alert again.
- [ ] After each close, Paperbranch keeps running, the Library window is unchanged, `finderOpenWorkflow.documentWindowDidClose` still runs, and no crash report appears.
- [ ] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Created 2026-09-30 from Ticket 25's visual check. The behavior is the same on `92da965` and after Ticket 25's fix (`1d37d43`). Before that fix, it hid the close crash until the next close click.

Seen in the packaged app with `/tmp/pb25-outside/Outside.md` in a Standalone window:

- Discard: the alert went away and the file stayed unchanged, but the window stayed open with the edit showing. A second close click closed it without an alert, so `windowsAllowedToClose` did contain the window. Screenshot at `/tmp/pb25-after-discard.png`, not committed.
- Save: the edit was written, the window stayed open, and a false "Changes conflict" alert appeared (Ticket 27).

Both paths in `AppDelegate.windowShouldClose(_:)` end with `sender.performClose(nil)`. Discard calls it from inside the `NSAlert` sheet's completion handler. Save calls it from `afterSave` after an async save.

Likely causes, not confirmed:

- Discard: `performClose` runs while the alert sheet is still attached to the window, so AppKit refuses the close.
- Save: the Ticket 27 conflict sheet is attached by the time `afterSave` runs. Recheck Save after Ticket 27 is fixed, because it may already work.

Note for testing: the `performClose` calls were triggered by pressing the alert buttons through accessibility, not with a real mouse click. Confirm the behavior with a real click too before relying on it.
