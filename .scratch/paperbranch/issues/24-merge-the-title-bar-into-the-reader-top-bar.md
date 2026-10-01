# 24: Merge the title bar into the reader top bar

**What to build:** Remove the separate macOS title bar and toolbar above the reader, so the window controls sit in the reader top bar as in Variant B and the document name appears once.

**Blocked by:** 13: Complete Variant B reader chrome in the guarded Library presentation.

**Status:** resolved

- [x] In the Variant B presentation, there is no separate title bar row, and the window controls sit at the window's top left over the sidebar header. (Changed 2026-09-30 from "sit in the reader top bar". See Comments.)
- [x] The document name appears once.
- [x] The sidebar toggle and Choose Library remain reachable, and AppKit fallback states still have their controls.
- [x] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Created 2026-09-30 from Ticket 13's visual check. The packaged window shows "Reading.md" in both the title bar and the reader top bar, with the toolbar's sidebar and Choose Library buttons in the title bar row.

Resolved 2026-09-30. The first criterion was changed by user decision. A spike (`/tmp/pb24-spike`, not committed) showed that moving the native window buttons into the reader top bar is fragile. AppKit put buttons moved with `setFrameOrigin` back at x=9 on the next window resize. With the toolbar hidden, the title bar is 32 pt tall, so centering the buttons in the 66 pt top bar would put them below the title bar's hit area. Their x position would also have to follow SwiftUI's 240 to 280 pt sidebar. The user chose the fallback over repositioning the native buttons or drawing custom SwiftUI buttons.

While SwiftUI is showing, `PaperbranchWindowPresentation.render(_:)` makes the content full size under a transparent title bar with the title hidden, and hides the toolbar. `restoreAppKitPresentation()` puts the title bar and toolbar back, so every AppKit fallback state keeps its controls. Both swaps keep the window frame, since changing the title bar keeps the content size. The toolbar is hidden after the hosting view becomes the content view, because hiding it first left it visible. `window.title` is still set. The window buttons stay where AppKit puts them, and the sidebar wordmark moves 20 pt down to clear them. The transparent title bar only covers the top 32 pt of the reader top bar, so an AppKit drag area behind the top bar calls `performDrag(with:)` for the rest. That drag area has no unit test, because it needs real mouse events. It was checked in the packaged app. Choose Library stays on File > Choose Library (Cmd-L) and the AppKit toolbar.

Verified 2026-09-30:

- Red: `cd editor-proof/native-host && swift test --filter BridgeCoordinatorTests/testReaderPresentationDropsTheTitleBarRowAndRestoreBringsItBack` failed with 16 failures, 8 for each of the reading and Ticket 18 empty-reader snapshots. The window was not full size, the title bar was opaque, the title was visible, the toolbar was visible, the content was 1300x734 in a 1300x800 window, the top bar sat below the close button, the close button was outside the sidebar, and there was no wordmark element. The test checks each snapshot, then checks that `restoreAppKitPresentation()` restores the title bar, toolbar, title, content view controller, and frame. The top bar check was first written against the window's top edge. That was wrong, because a containing accessibility element's frame spans its children. It now asserts that the top bar shares the window buttons' row. Rerunning the final test against the old source still failed the same way (top bar 717 vs close button 767).
- Green: the same focused test passed. The presentation filter `'BridgeCoordinatorTests/(testPresentation|testExpandedLibrary|testReaderSidebar|testReaderPresentation|testRenderedLibrary|testUnchangedLibrary|testReturningToReader|testLibraryToolbar)'` passed 13 of 13, including Ticket 14's `testLibraryToolbarSidebarItemRoutesThroughLibrarySidebarToggle` and Ticket 15's `testPresentationSwapsKeepTheLibraryWindowFrame` and `testUnchangedLibraryRefreshDoesNotSwapPresentations`, all unchanged.
- `cd editor-proof/native-host && ./verify-package.sh`: Xcode Release build succeeded and all 53 packaged native tests passed.
- `git diff --check`: passed.
- Packaged app: `./package.sh` built `.build/Paperbranch.app`, and no older Paperbranch process was running. At 1300x800 with `/private/tmp/pb15-library`, the reader with `Reading.md` had no title bar row, the name once in the top bar, and the buttons over the sidebar header. Minimize minimized the window. The green button entered full screen, and leaving full screen returned the window to 1300x800 with the buttons in place. Close quit the app. Dragging moved the window from the title bar strip, from the lower half of the top bar, and from over the sidebar header, in the reader and in the empty reader. The reader sidebar toggle collapsed the sidebar into AppKit with the title bar ("Reading.md") and toolbar back at 1300x800, and the toolbar's Library item reopened the reader. Cmd-L opened the Choose Library sheet, and choosing the same folder showed the empty reader without a title bar row.
- Screenshots, not committed: `/tmp/pb24-reading.png`, `/tmp/pb24-fullscreen.png`, `/tmp/pb24-after-fullscreen.png`, `/tmp/pb24-collapsed-appkit.png`, `/tmp/pb24-reopened.png`, `/tmp/pb24-choose-library.png`, and `/tmp/pb24-empty-reader.png`.
- Not verified: clicking the window buttons while Paperbranch is inactive (a Finder window covered them during that try), and double-clicking the top bar to zoom.

Differences outside this ticket, not fixed:

- The window buttons sit at about 16 pt from the top and the top bar content at about 33 pt, so they are not in one row as in Variant B.
- The top bar's right side shows "Reading". Variant B has an Open button there (Ticket 20).
- After Choose Library, `window.title` stays "Reading.md" with no document selected, because AppDelegate keeps the previous document open (Ticket 18). It shows in the AppKit title bar and Mission Control.
- Paperbranch has no Window menu (only Paperbranch, File, and View), so `window.title` reaches Mission Control and the Dock only.

Implementation commit: `7db4a84`.
