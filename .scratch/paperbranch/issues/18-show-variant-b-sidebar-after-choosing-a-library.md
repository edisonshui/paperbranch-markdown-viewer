# 18: Show the Variant B sidebar after choosing a Library

**What to build:** When a Library is chosen or restored with no selected Markdown document, show the SwiftUI Variant B sidebar with an empty reader instead of the AppKit split view and outline sidebar. Selecting a document from that sidebar continues through the existing Finder-open path.

**Blocked by:** 13: Complete Variant B reader chrome in the guarded Library presentation.

**Status:** resolved

- [x] After Choose Library, the Library window shows the Variant B sidebar with the new Library tree and an empty reader, not the AppKit outline sidebar.
- [x] Selecting a Markdown document from that sidebar opens it in the Variant B reader.
- [x] Collapsed, dirty, conflict, unavailable, empty, pending-open, and Standalone states keep their existing presentation.
- [x] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Created 2026-09-30 from a user report after Ticket 13. `handleChooseLibrary` in `AppDelegate.swift` clears the selected document. `PaperbranchWindowPresentation.render(_:)` requires `selectedDocumentURL`, so the window falls back to the AppKit split view (Ticket 16 only made it dark). Variant B has no no-selection state, so the empty reader's design needs a decision. The alternative is to auto-select the first document after Choose Library.

Resolved 2026-09-30. The empty reader was chosen over auto-selecting the first document. With an available, expanded Library that has at least one document, no selection, and clean Library document facts, `PaperbranchWindowPresentation.render(_:)` shows the Variant B sidebar and an empty reader. The reader keeps the top bar with the sidebar toggle and shows "Choose a document from the Library" centered, with no Document view, outline, or footer. The previous document's outline is dropped, because AppDelegate still holds it after Choose Library. A `nil` document snapshot still means a pending open and restores AppKit. Launch restore with no saved selection takes the same path, with no open document.

Verified 2026-09-30:

- Red: `cd editor-proof/native-host && swift test --filter BridgeCoordinatorTests/testExpandedLibraryWithoutSelectionShowsVariantBSidebarAndEmptyReader` failed with 3 failures. `render` returned false, the window kept its AppKit content, and no SwiftUI sidebar was rendered. The test covers both snapshots, the launch restore with no open document and Choose Library with the previous clean document still open. It checks the Library tree, the absence of a selected document and outline, the top bar's sidebar toggle, the empty reader prompt, and the absence of the canvas, footer, and injected `WKWebView`. It checks that selecting a rendered document invokes the injected action. It also checks that the empty-Library, collapsed sidebar, collapsed folder, dirty, conflict, unavailable document, unavailable Library, Standalone, and pending-open snapshots restore AppKit.
- Green: the same focused test passed. The presentation filter `'BridgeCoordinatorTests/(testPresentation|testExpandedLibrary|testReaderSidebar|testRenderedLibrary|testUnchangedLibrary|testReturningToReader)'` passed 11 of 11. The existing guard test `testPresentationActivatesOnlyForCleanExpandedLibraryDocumentAndOtherwiseRestoresAppKit` passed unchanged.
- `cd editor-proof/native-host && ./verify-package.sh`: Xcode Release build succeeded and all 52 packaged native tests passed.
- `git diff --check`: passed.
- Packaged app: `./package.sh` built `.build/Paperbranch.app`, and no older Paperbranch process was running. At 1300x800, the launch restore of `/private/tmp/pb15-library` with no saved selection already showed the Variant B sidebar and empty reader. After Choose Library (Cmd-L) picked the same folder, the window showed the Variant B sidebar with the full nested tree and the empty reader. Selecting `Reading.md` from that sidebar opened it in the Variant B reader, with the selection highlight, the outline, the canvas, and the footer.
- Screenshots, not committed: `/tmp/pb18-panel.png` (launch restore behind the Choose Library panel), `/tmp/pb18-empty-reader.png` (after Choose Library), and `/tmp/pb18-reading.png` (after selecting `Reading.md`).

Implementation commit: `ada4c49`.
