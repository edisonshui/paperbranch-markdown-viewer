# 12: Render Variant B's clean expanded Library reading state

**What to build:** Present the clean, available, selected Markdown document in a fully expanded Library with Variant B's reader layout, while continuing to use the existing Library window, Document view, navigation behavior, and AppKit-owned workflows.

**Blocked by:** 11: Guard SwiftUI Library presentation activation.

**Status:** resolved

- [x] The guarded SwiftUI presentation renders Variant B's expanded Library reading layout with the existing injected Document view.
- [x] The existing Library hierarchy, selected Markdown document, document outline, and reading progress appear in that SwiftUI presentation.
- [x] Document selection and outline selection continue through the existing Finder-open and BridgeCoordinator paths.
- [x] Dirty, conflict, unavailable, empty, collapsed, pending-open, document-unavailable, and Standalone states restore AppKit synchronously before display.
- [x] The original Library window, DocumentSession, injected WKWebView, AppDelegate window delegate, menus, save flow, close flow, and conflict flow remain in use.
- [x] Focused tests cover presentation eligibility, injected view reuse, navigation data and actions, and the preserved AppKit workflow paths.
- [x] `editor-proof/native-host/verify-package.sh` passes.

## Comments

Verified 2026-09-21:

- Red: `cd editor-proof/native-host && swift test --filter BridgeCoordinatorTests/testExpandedLibraryPresentationShowsNavigationStateAndRoutesOutlineSelection` failed because the guarded presentation accepted neither navigation state nor an outline-selection action.
- Green: the same focused test passed after `PaperbranchWindowPresentationState` gained semantic outline and reading-progress facts, and the presentation routed a rendered outline selection through its injected action.
- `cd editor-proof/native-host && ./verify-package.sh`: Xcode Release build succeeded and all 42 packaged native tests passed. This includes guarded activation and synchronous AppKit restoration, injected `WKWebView` reuse, Finder routing, explicit Save, conflict handling, and the standard close workflow.
- `git diff --check`: passed.

Implementation commit: `6fcbda6` (shared with in-progress Tickets 13 and 14).
