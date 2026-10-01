# 26: Open Standalone windows at a usable size

**What to build:** Open each Standalone window at its intended 800x640 content size, fully on screen, instead of the tiny window it gets now.

**Blocked by:** 06: Open Library and Standalone documents from Finder.

**Status:** resolved

- [x] The cause of the tiny window is confirmed and recorded in Comments.
- [x] A Standalone window opened from the reader's Open button, File > Open, or Finder opens at 800x640 content size and fully on screen.
- [x] The Standalone window can be resized and keeps its new size.
- [x] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Created 2026-09-30 from Ticket 20's visual check. A Standalone window opened through the reader's Open button came up at 64x32, positioned at 0,244 on a 1512-wide screen, so only its window buttons showed at the screen's left edge. Screenshot at `/tmp/pb20-standalone.png`, not committed.

Likely cause, not confirmed: `StandaloneDocumentWindow.init` creates an 800x640 window and then assigns `window.contentViewController = presentation`. Ticket 15 found that assigning a content view controller resizes the window to that controller's detached view, and `makeLibraryWindow()` works around it with `setContentSize` after the assignment. The Standalone window has no such step, and the window is never centered.

Unchanged since `50472e3`. Closing this window currently crashes the app (Ticket 25), so fixing Ticket 25 first makes this one easier to check by hand.

Resolved 2026-09-30. `StandaloneDocumentWindow.init` now calls `window.setContentSize(NSSize(width: 800, height: 640))` and `window.center()` after assigning `window.contentViewController`, the same way `makeLibraryWindow()` does. The Ticket 25 and 28 close behavior is unchanged.

Confirmed cause, 2026-09-30: temporary `NSLog` calls in `StandaloneDocumentWindow.init` and `AppDelegate.openStandaloneDocument(at:)`, in a packaged build of `524cb16` run from its executable so stderr went to a file. Opening `/tmp/pb25-outside/Outside.md` with `open -a` logged:

- Before `contentViewController`: frame `{{0, 66}, {800, 672}}`, content 800x640.
- After `contentViewController`: frame `{{0, 706}, {1, 32}}`, content 1x0.
- Before and after `makeKeyAndOrderFront`: frame `{{0, 706}, {64, 32}}` on a `{{0, 66}, {1512, 883}}` visible screen.

So assigning the content view controller shrank the window to the presentation's detached view, and nothing restored the size or centered it. AppKit's minimum made it 64x32. The logging was removed before commit.

Verified 2026-09-30:

- Red: `cd editor-proof/native-host && PAPERBRANCH_PACKAGED_APP_PATH="$PWD/.build/Paperbranch.app" swift test --filter BridgeCoordinatorTests/testStandaloneWindowOpensAtDefaultContentSizeOnScreen` failed 3 of 3 runs with `XCTAssertEqual failed: ("Optional((64.0, 0.0))") is not equal to ("Optional((800.0, 640.0))")`. The test opens a real file through `AppDelegate.openStandaloneDocument(at:)`, then checks the window's content view size and that its frame is inside a screen's visible frame.
- Green: the same focused test passed 3 of 3 runs. `testDiscardInCloseAlertClosesDirtyStandaloneWindow` passed. The presentation filter from Ticket 20 passed 14 of 14.
- `cd editor-proof/native-host && ./verify-package.sh`: Xcode Release build succeeded and all 58 packaged native tests passed.
- `git diff --check`: passed.
- Packaged app built with `./package.sh`, no older Paperbranch process running, `/private/tmp/pb15-library` with the Library window at (60, 33) 1300x800. The library and `/tmp/pb25-outside/Outside.md` were backed up first and restored afterwards. `Outside.md` was opened three ways: the reader's Open button, File > Open, and `open -a` on the packaged app. Panel clicks were real clicks.
  - Each time, the window opened at (356, 86) with an 800x672 frame, which is 800x640 content plus the 32-point title bar, centered and fully on screen. Nothing resized it by script.
  - Each time, dragging the bottom-right corner by +100, +50 with real mouse events made it 900x722, and it was still 900x722 two seconds later.
  - After each, Paperbranch kept running (same process), the Library window stayed at (60, 33) 1300x800 on the clean `Note.md`, both fixture files were unchanged, and no new crash report appeared.
- Screenshots, not committed: `/tmp/pb26-library-before.png`, `/tmp/pb26-panel.png`, `/tmp/pb26-open-button.png`, `/tmp/pb26-open-button-resized.png`, `/tmp/pb26-file-open-panel.png`, `/tmp/pb26-file-open-selected.png`, `/tmp/pb26-file-open.png`, `/tmp/pb26-file-open-resized.png`, `/tmp/pb26-finder.png`, and `/tmp/pb26-finder-resized.png`.

Differences outside this ticket, not fixed:

- The Standalone window has a light title bar over the dark reader. The Library window sets `.darkAqua`, and the Standalone window sets no appearance.
- At launch, the Library window came up 1300x883 from its saved frame, not 1300x800. It was set to 1300x800 with System Events before the check. The cause is unconfirmed. It may be the frame saved by an earlier session.

Implementation commit: `6c7bc7a`.
