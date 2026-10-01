# 28: Close Standalone windows after Save or Discard in the close alert

**What to build:** When a dirty Standalone window is closed and the user chooses Save or Discard in the alert, the window closes. Cancel keeps it open with its edits.

**Blocked by:** 25: Stop closing a Standalone window from crashing Paperbranch; 27: Stop saves from raising a false external-change conflict.

**Status:** resolved

- [x] The cause of each window staying open is confirmed and recorded in Comments.
- [x] Discard closes the window and leaves the file on disk unchanged.
- [x] Save writes the file and then closes the window.
- [x] Cancel keeps the window open with its edits, and a later close shows the alert again.
- [x] After each close, Paperbranch keeps running, the Library window is unchanged, `finderOpenWorkflow.documentWindowDidClose` still runs, and no crash report appears.
- [x] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

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

Resolved 2026-09-30. The Discard branch of `AppDelegate.windowShouldClose(_:)` still adds the window to `windowsAllowedToClose`, then calls `sender.performClose(nil)` on the next main-queue turn with `DispatchQueue.main.async`. By then the alert sheet has ended, so the close goes through `windowShouldClose` and `windowWillClose`, which still calls `finderOpenWorkflow.documentWindowDidClose`. Save needed no change. Cancel is unchanged. The test reaches the real path, so `openStandaloneDocument(at:)` is now internal and `standaloneWindows` is `private(set)` instead of private.

Confirmed causes, 2026-09-30:

- Discard: temporary `NSLog` calls in `windowShouldClose(_:)` and its Discard branch, in a packaged build of `9b1a0c1`. Closing a dirty `/tmp/pb25-outside/Outside.md` and clicking Discard with a real click logged "windowShouldClose: allowed=0", then "discard: attachedSheet=Optional(<_NSAlertPanel ...>) visible=1", then "discard: after performClose visible=1". No second "windowShouldClose" line followed. So the alert's sheet was still attached inside its completion handler, and AppKit dropped the `performClose` without asking the delegate. The file stayed unchanged. A second close click logged "allowed=1" and closed the window. The logging was removed before commit.
- Save: on the same build, which has Ticket 27's fix, choosing Save in the close alert wrote the edit and closed the window. The log showed the second "windowShouldClose: allowed=1" from `afterSave`. `save()` is async, so `afterSave` runs after the sheet has ended. The window stayed open before only because Ticket 27's false conflict sheet was attached by then. Ticket 27's fix (`ad82a57`) resolved it.

Verified 2026-09-30:

- Red: `cd editor-proof/native-host && PAPERBRANCH_PACKAGED_APP_PATH="$PWD/.build/Paperbranch.app" swift test --filter BridgeCoordinatorTests/testDiscardInCloseAlertClosesDirtyStandaloneWindow` failed 3 of 3 runs with "Discard left the Standalone window open" and "windowWillClose did not run for the discarded window". The test opens a real file through `AppDelegate.openStandaloneDocument(at:)`, edits it through the editor until the session is dirty, calls `performClose` on the window, waits for the close alert sheet, and clicks its Discard button with `performClick`. It then checks that the window is hidden, that `windowWillClose` removed it from `standaloneWindows`, and that the file is unchanged. Cancel and Save were not given unit tests. Save already worked, and Cancel was checked in the packaged app.
- Green: the same focused test passed 3 of 3 runs. The presentation filter from Ticket 20 passed 14 of 14.
- `cd editor-proof/native-host && ./verify-package.sh`: Xcode Release build succeeded and all 57 packaged native tests passed.
- `git diff --check`: passed.
- Packaged app built with `./package.sh`, `/private/tmp/pb15-library` at 1300x800, no older Paperbranch process running. `Note.md` and `/tmp/pb25-outside/Outside.md` were backed up first and restored afterwards. `Outside.md` was opened with the reader's Open button each time, resized to 900x650 with System Events, made dirty, and closed with a real click on its close button. Alert buttons were also clicked for real.
  - Cancel: the window stayed open with the edit showing. A second close showed the alert again.
  - Discard, from that second alert: the window closed and `Outside.md` on disk was unchanged.
  - Save: the edit was written ("Save check. Saved.") and the window closed with no conflict alert.
  - After each step, Paperbranch kept running (same process), the Library window stayed at (60, 33) 1300x800 on the clean `Note.md` reader, and no new crash report appeared.
- Screenshots, not committed: `/tmp/pb28-after-discard-logged.png` (before the fix), `/tmp/pb28-library-before.png`, `/tmp/pb28-close-alert.png`, `/tmp/pb28-after-cancel.png`, `/tmp/pb28-after-discard.png`, and `/tmp/pb28-after-save.png`.

Differences outside this ticket, not fixed:

- On one try, right after the Discard check, the click on the reader's Open button did not open the file panel. My helper kept going, so the typed text went into the Library's `Note.md` and a close-button click hit "Choose Library...". The in-memory edit was undone with Cmd+Z and nothing was saved. The disk file stayed unchanged. The cause is unconfirmed. It may be that the first click only made the Library window key after the Standalone window closed. The next try opened the panel normally.

Implementation commit: `f38e349`.
