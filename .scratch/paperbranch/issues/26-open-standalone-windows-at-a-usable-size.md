# 26: Open Standalone windows at a usable size

**What to build:** Open each Standalone window at its intended 800x640 content size, fully on screen, instead of the tiny window it gets now.

**Blocked by:** 06: Open Library and Standalone documents from Finder.

**Status:** ready-for-agent

- [ ] The cause of the tiny window is confirmed and recorded in Comments.
- [ ] A Standalone window opened from the reader's Open button, File > Open, or Finder opens at 800x640 content size and fully on screen.
- [ ] The Standalone window can be resized and keeps its new size.
- [ ] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Created 2026-09-30 from Ticket 20's visual check. A Standalone window opened through the reader's Open button came up at 64x32, positioned at 0,244 on a 1512-wide screen, so only its window buttons showed at the screen's left edge. Screenshot at `/tmp/pb20-standalone.png`, not committed.

Likely cause, not confirmed: `StandaloneDocumentWindow.init` creates an 800x640 window and then assigns `window.contentViewController = presentation`. Ticket 15 found that assigning a content view controller resizes the window to that controller's detached view, and `makeLibraryWindow()` works around it with `setContentSize` after the assignment. The Standalone window has no such step, and the window is never centered.

Unchanged since `50472e3`. Closing this window currently crashes the app (Ticket 25), so fixing Ticket 25 first makes this one easier to check by hand.
