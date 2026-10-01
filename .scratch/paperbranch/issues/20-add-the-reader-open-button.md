# 20: Add the reader Open button

**What to build:** Replace the "Reading" label on the right of the reader top bar with Variant B's "Open" button, routed through the existing Open command.

**Blocked by:** 13: Complete Variant B reader chrome in the guarded Library presentation.

**Status:** resolved

- [x] The reader top bar shows an "Open" button where Variant B has one.
- [x] The button runs the existing Open panel and Finder-open routing.
- [x] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Created 2026-09-30 from Ticket 13's visual check.

Resolved 2026-09-30. `PaperbranchWindowPresentation` takes an injected `onOpen` action, and AppDelegate passes its existing `handleOpen()`, which shows the Open panel as a sheet on the Library window and routes the chosen file through `routeFinderOpen`. The top bar's "Reading" label is replaced by an Open button on the right. The button also shows in the Ticket 18 empty reader, since Variant B always has it and Open is useful with nothing selected. Pressing it leaves the SwiftUI reader showing, and the routed open restores AppKit as before.

Verified 2026-09-30:

- Red: `cd editor-proof/native-host && swift test --filter BridgeCoordinatorTests/testReaderTopBarOpenButtonInvokesInjectedOpenAction` first failed to compile on the missing `onOpen` argument. After adding the parameter with no behavior, it failed with 2 failures: the top bar still contained "Reading", and there was no `paperbranch.reader.open` element. For the reading and empty-reader snapshots, the test checks that the top bar has no "Reading" label and has an "Open" button right of the sidebar toggle and the document name. It presses the rendered button through its accessibility node and checks that the injected action runs once per press and the reader stays showing.
- Green: the same focused test passed. The presentation filter `'BridgeCoordinatorTests/(testPresentation|testExpandedLibrary|testReaderSidebar|testReaderPresentation|testReaderTopBar|testRenderedLibrary|testUnchangedLibrary|testReturningToReader|testLibraryToolbar)'` passed 14 of 14.
- `cd editor-proof/native-host && ./verify-package.sh`: Xcode Release build succeeded and all 54 packaged native tests passed.
- `git diff --check`: passed.
- Packaged app, `/private/tmp/pb15-library` at 1300x800, no older Paperbranch process running: the reader showed Open on the right of the top bar. Clicking it opened the Open sheet. Choosing `Notes/Note.md` opened it in the Library reader with the sidebar highlight and outline. Clicking Open again and choosing a Markdown file outside the Library opened a Standalone window.
- Screenshots, not committed: `/tmp/pb20-reader.png`, `/tmp/pb20-open-panel.png`, `/tmp/pb20-library-open.png`, and `/tmp/pb20-standalone.png`.

Differences outside this ticket, not fixed:

- The Standalone window opened at 64x32 at the screen's left edge. `StandaloneDocumentWindow` assigns `window.contentViewController` after creating an 800x640 window, which likely resizes it to the controller's detached view, the same cause as Ticket 15. Unchanged since `50472e3`.
- Closing that Standalone window crashed the app with `EXC_BAD_ACCESS` in `objc_release` from `-[_NSWindowTransformAnimation dealloc]` (`~/Library/Logs/DiagnosticReports/Paperbranch-2026-09-30-165822.ips`). Suspected cause, unconfirmed: the programmatic `NSWindow` keeps `isReleasedWhenClosed = true` while `windowWillClose` drops the last reference. Not reproduced on the build before this ticket.

Implementation commit: `7ea0aa2`.
