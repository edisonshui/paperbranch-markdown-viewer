# 14: Return to AppKit when toggling the Library sidebar from the reader

**What to build:** Let the guarded SwiftUI reader’s sidebar control restore the existing AppKit Library window and then invoke the existing sidebar toggle. This must make the collapsed Library state reachable without duplicating sidebar, DocumentSession, or workflow behavior.

**Blocked by:** 12: Render Variant B's clean expanded Library reading state.

**Status:** resolved

- [x] The reader’s sidebar control is available while the guarded SwiftUI presentation is visible.
- [x] Toggling it synchronously restores the captured AppKit content and delegates to the existing Library sidebar toggle.
- [x] The Library window's toolbar sidebar item routes through the same Library sidebar toggle, so a collapsed sidebar reopens and stays open across the 1 s Library refresh.
- [x] Returning to the reader after a toggle shows the injected Document view again, not an empty canvas.
- [x] The collapsed, dirty, conflict, unavailable, empty, pending-open, and Standalone states continue to use existing AppKit presentation.
- [x] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Created 2026-09-21 from Ticket 10 visual verification. In the packaged reader at the restored narrow window width, the AppKit toolbar Sidebar item was disabled and the SwiftUI reader icon was not a control, leaving the document canvas unusably narrow and making the required collapsed AppKit state unreachable.

Updated 2026-09-30. Manual use of the packaged app showed that a collapsed sidebar reopened from the toolbar collapsed itself again within a second, and only Choose Library restored it. Two causes, both confirmed:

- The toolbar used AppKit's standard `.toggleSidebar` identifier. AppKit builds its own item for that identifier and never uses the delegate's "Library" item, which the red test below showed. That item toggled the split view directly, so `LibraryWorkflow.sidebarState` stayed collapsed, and the 1 s refresh's `showLibrary()` collapsed the split view again. Choose Library worked only because it resets the sidebar state. While SwiftUI was showing, the split view controller was out of the responder chain, which is why Ticket 10 saw the toolbar item disabled.
- After a toggle, the second visit to the reader showed an empty canvas. `PaperbranchWebViewCanvas` attached the injected `WKWebView` only when SwiftUI created it. SwiftUI reuses the canvas across swaps, and it skips `updateNSView` when its inputs are unchanged, while AppKit restoration moves the web view back to `DocumentPresentationViewController`.

Fix: the toolbar uses a Paperbranch `ToggleLibrarySidebar` identifier whose item targets `toggleLibrarySidebar()`, and the canvas reattaches the web view in `viewDidMoveToWindow()`.

Verified 2026-09-30:

- Red: `cd editor-proof/native-host && swift test --filter testLibraryToolbarSidebarItemRoutesThroughLibrarySidebarToggle` failed because the installed toolbar contained AppKit's `.toggleSidebar` item and no "Library" item.
- Red: `swift test --filter testReturningToReaderAfterAppKitRestoreShowsInjectedWebViewAgain` failed because the web view stayed in the AppKit content after the second SwiftUI render.
- Green: both focused tests passed after the fix.
- `testReaderSidebarToggleRestoresAppKitThenDelegatesToExistingSidebarWorkflow` was committed with its implementation in `6fcbda6`, so its red run was never observed. As a substitute, removing the body of `toggleSidebar()` made it fail with 2 failures, and the file was restored.
- `testPresentationActivatesOnlyForCleanExpandedLibraryDocumentAndOtherwiseRestoresAppKit` covers the ineligible AppKit states and passes unchanged.
- `cd editor-proof/native-host && ./verify-package.sh`: Xcode Release build succeeded and all 48 packaged native tests passed.
- `git diff --check`: passed.
- Packaged app, fixture Library with a clean `First essay.md` at 1300x800: launched with a collapsed sidebar, and the toolbar item reopened it into the Variant B reader, which stayed open. Then three round trips of reader sidebar control, then toolbar item. Each click collapsed the sidebar into AppKit, and each reopen returned to the reader with the document painted.

Implementation commit: `bfd7ddf`.
