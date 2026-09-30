# 25: Stop closing a Standalone window from crashing Paperbranch

**What to build:** Closing a Standalone window closes only that window. Paperbranch keeps running, and the Library window and its document stay open.

**Blocked by:** 06: Open Library and Standalone documents from Finder.

**Status:** resolved

- [x] The cause of the crash is confirmed and recorded in Comments.
- [x] Closing a clean Standalone window leaves Paperbranch running with the Library window unchanged.
- [x] Closing a dirty Standalone window through the existing Save, Cancel, and Discard alert still works, and neither Save nor Discard crashes.
- [x] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Created 2026-09-30 from Ticket 20's visual check. In the packaged app, the reader's Open button opened a Markdown file outside the Library in a Standalone window. Clicking that window's close button crashed Paperbranch while the Library window was still open.

The crash report is `~/Library/Logs/DiagnosticReports/Paperbranch-2026-09-30-165822.ips`: `EXC_BAD_ACCESS` (`KERN_INVALID_ADDRESS`) in `objc_release`, called from `-[_NSWindowTransformAnimation dealloc]` while an autorelease pool drained during a Core Animation commit. So the window's close animation released an object that had already been freed.

Suspected cause, not confirmed: `StandaloneDocumentWindow` creates its `NSWindow` in code, where `isReleasedWhenClosed` defaults to `true`, while `AppDelegate.windowWillClose(_:)` also drops the last strong reference with `standaloneWindows[entry.key] = nil`. Confirm this before fixing, for example by setting `isReleasedWhenClosed = false` and checking that the crash stops, rather than assuming it.

Not yet known: whether the crash reproduces on the build before Ticket 20 (`81bde36`). Ticket 20 did not change Standalone window code, which has been unchanged since `50472e3`.

Resolved 2026-09-30. `StandaloneDocumentWindow` sets `window.isReleasedWhenClosed = false`. AppDelegate stays the only owner and drops the window in `windowWillClose(_:)` as before. The dirty-document alert and `finderOpenWorkflow.documentWindowDidClose` are unchanged.

Confirmed cause, 2026-09-30:

- The crash reproduced in the packaged HEAD build (`92da965`): the Library at `/private/tmp/pb15-library`, `/tmp/pb25-outside/Outside.md` opened in a Standalone window, and its close button clicked. Same `objc_release` from `-[_NSWindowTransformAnimation dealloc]` stack (`Paperbranch-2026-09-30-170612.ips`).
- The same build run with `NSZombieEnabled=YES` logged `-[NSKVONotifying_NSWindow release]: message sent to deallocated instance`, so the over-released object was the Standalone `NSWindow` itself (`Paperbranch-2026-09-30-170634.ips`).
- Adding only `window.isReleasedWhenClosed = false` to the same build stopped the crash across 4 open-and-close cycles. So the programmatic window released itself on close, and dropping AppDelegate's last reference released it again.
- The crash also reproduced on `81bde36`, before Ticket 20, with the same stack (`Paperbranch-2026-09-30-170759.ips`). It predates Ticket 20.

Verified 2026-09-30:

- Red: `cd editor-proof/native-host && swift test --filter BridgeCoordinatorTests/testClosingStandaloneWindowLeavesItAliveForItsOwner` failed 3 of 3 runs with "Closing the Standalone window freed it while its owner still held it". The test shows a real `StandaloneDocumentWindow` with an `AppDelegate` as its window delegate, closes it with `performClose(_:)`, spins the run loop for 1 s, and checks that the window is still alive while the test holds the owner reference, as `standaloneWindows` does. Each step runs in its own autorelease pool, as the app's event loop does. Without that, XCTest's outer pool kept the window alive past the check and the runner crashed with SIGSEGV after the test. If the window is freed, the test leaks the owner on purpose so the runner does not crash.
- Green: the same focused test passed 3 of 3 runs. The presentation filter `'BridgeCoordinatorTests/(testPresentation|testExpandedLibrary|testReaderSidebar|testReaderPresentation|testReaderTopBar|testRenderedLibrary|testUnchangedLibrary|testReturningToReader|testLibraryToolbar)'` passed 14 of 14.
- `cd editor-proof/native-host && ./verify-package.sh`: Xcode Release build succeeded and all 55 packaged native tests passed.
- `git diff --check`: passed.
- Packaged app, `/private/tmp/pb15-library` at 1300x800, no older Paperbranch process running. The reader's Open button opened `/tmp/pb25-outside/Outside.md` in a Standalone window, resized with System Events because of Ticket 26. After each close below, Paperbranch was still running, the Library window stayed at (60, 33) 1300x800 on `Note.md`, and no new Paperbranch crash report appeared.
  - Clean close: the window closed.
  - Dirty, Cancel: the alert showed Save, Discard, and Cancel. Cancel kept the window open with the edit.
  - Dirty, Discard: the file on disk was unchanged. The window stayed open (see below). A second close click closed it without an alert.
  - Dirty, Save: the edit was written to disk. The window stayed open and a "Changes conflict" alert appeared (see below). After Keep Editing, a close click closed it.
- Screenshots, not committed: `/tmp/pb25-standalone-clean.png`, `/tmp/pb25-after-clean-close.png`, `/tmp/pb25-dirty-cancel.png`, `/tmp/pb25-after-cancel.png`, `/tmp/pb25-after-discard.png`, `/tmp/pb25-dirty-save.png`, `/tmp/pb25-after-save.png`, and `/tmp/pb25-stuck.png` (the conflict alert after Save).

Differences outside this ticket, not fixed:

- Save and Discard in the close alert do not close the Standalone window. Both call `sender.performClose(nil)` after the alert, and the window stays open. The same happened on the pre-fix build of `92da965`, so this predates the fix. Before the fix, it only hid the crash until the next close click.
- After Save from the close alert, Paperbranch shows "Changes conflict in Outside.md" for its own save, as if the document were still dirty. Same on the pre-fix build of `92da965`.
- The Library window saved its frame at 1300x800 on quit and relaunched at 1300x852, and an earlier relaunch grew it to 1300x883.
- Standalone windows still open at 64x32 at the screen's left edge (Ticket 26).

Implementation commit: `1d37d43`.
