# 11: Guard SwiftUI Library presentation activation

**What to build:** Activate ADR 0005's SwiftUI Library presentation only for a clean, available Markdown document in a fully expanded Library, while retaining the existing AppKit Library window and every existing workflow path.

**Blocked by:** 09: Resolve external changes with unsaved edits.

**Status:** resolved

- [x] The SwiftUI presentation reuses the original Library window and injected `WKWebView`; it never creates a second Library window.
- [x] One presentation module accepts a semantic window snapshot and either renders the eligible clean, expanded Library state or synchronously restores the AppKit presentation.
- [x] A rendered Markdown document selection enters the existing Finder-open workflow.
- [x] Dirty, conflict, unavailable, collapsed, empty, document-unavailable, Standalone, and pending-open snapshots retain or restore AppKit before display.
- [x] Existing close handling, menu Save, and conflict handling remain AppKit paths.
- [x] The packaged verifier passes.

## Comments

Design seam: `PaperbranchWindowPresentation.render(_:) -> Bool`. The AppDelegate maps its existing Library workflow and DocumentSession facts into one semantic snapshot. The module owns the guard policy, SwiftUI hosting, and synchronous restoration of the saved AppKit content, keeping callers unaware of individual eligibility conditions.

Verified 2026-09-21:

- Red: `cd editor-proof/native-host && swift test --filter BridgeCoordinatorTests/testPresentationActivatesOnlyForCleanExpandedLibraryDocumentAndOtherwiseRestoresAppKit` failed because the prior presentation constructor created its own window and exposed no guarded semantic state.
- Green: `cd editor-proof/native-host && swift test --filter 'BridgeCoordinatorTests/(testPresentationActivatesOnlyForCleanExpandedLibraryDocumentAndOtherwiseRestoresAppKit|testExpandedLibraryPresentationShowsSelectedDocumentAndInjectedWebView|testExpandedLibraryPresentationIgnoresSelectionOutsideItsLibrary|testRenderedLibraryDocumentSelectionInvokesInjectedAction)'` passed after the guarded presentation module was added.
- `cd editor-proof/native-host && ./verify-package.sh`: Xcode Release build succeeded and all 41 packaged native tests passed, including the guarded activation, Finder routing, explicit Save, conflict, and standard close-flow coverage.
- `git diff --check` passed.

Implementation commit: `6fcbda6` (shared with in-progress Tickets 13 and 14).
