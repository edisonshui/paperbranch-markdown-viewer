# 13: Complete Variant B reader chrome in the guarded Library presentation

**What to build:** Make the already-guarded clean, available, selected Markdown document in a fully expanded Library visually follow Variant B's reader layout: a reader top bar, centered constrained reading canvas, and footer. Keep the existing Library window, injected WebKit Document view, AppKit workflows, and guard policy unchanged.

**Blocked by:** 12: Render Variant B's clean expanded Library reading state.

**Status:** claimed

- [ ] The eligible SwiftUI Library presentation visibly contains Variant B reader chrome with the selected Markdown document name.
- [x] The injected WebKit Document view sits in the centered, constrained reader canvas with a reader footer.
- [x] The existing sidebar, document selection, outline selection, progress, and all ineligible AppKit states remain unchanged.
- [x] Focused tests pass red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Created 2026-09-21 from Ticket 10 visual verification. The packaged clean expanded Library state had the dark palette and sidebar but lacked Variant B's reader top bar, constrained document canvas, and footer, so the visual acceptance criterion cannot yet pass.

Verified 2026-09-30:

- Red: `cd editor-proof/native-host && swift test --filter BridgeCoordinatorTests/testExpandedLibraryPresentationShowsVariantBReaderChromeAroundInjectedDocumentView` failed on the hardcoded root accessibility value and the missing document canvas container. The rewritten test reads SwiftUI's rendered accessibility tree and checks that the top bar shows the selected document name, the injected `WKWebView` sits inside the canvas, and the canvas is narrower than and centered in the reader column, between the top bar and footer.
- Green: the same focused test passed after the fake value was removed and the top bar, document canvas, progress, and footer got real accessibility labels. The presentation filter `'BridgeCoordinatorTests/(testPresentation|testExpandedLibrary|testReaderSidebar|testRenderedLibrary)'` also passed.
- `cd editor-proof/native-host && ./verify-package.sh`: Xcode Release build succeeded and all 44 packaged native tests passed.
- `git diff --check`: passed.
- Visual check, blocked: the packaged Library window stays at about 340x220 and snaps back when resized, so the reader chrome could not be compared to Variant B at a usable size. The swap assigns `window.contentViewController`, which resizes the window, and the 1 s Library refresh appears to trigger it repeatedly. This predates Ticket 13 and is left open, so the first checkbox stays unchecked.
- Gaps against Variant B outside this ticket: the footer is pinned to the window bottom instead of ending the article; the top bar shows "Reading" instead of an "Open" button; there is no words and read-time meta line; the sidebar shows the Library tree instead of Variant B's navigation items.

Implementation commit: `be61b12`.
