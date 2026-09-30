# 18: Show the Variant B sidebar after choosing a Library

**What to build:** When a Library is chosen or restored with no selected Markdown document, show the SwiftUI Variant B sidebar with an empty reader instead of the AppKit split view and outline sidebar. Selecting a document from that sidebar continues through the existing Finder-open path.

**Blocked by:** 13: Complete Variant B reader chrome in the guarded Library presentation.

**Status:** ready-for-agent

- [ ] After Choose Library, the Library window shows the Variant B sidebar with the new Library tree and an empty reader, not the AppKit outline sidebar.
- [ ] Selecting a Markdown document from that sidebar opens it in the Variant B reader.
- [ ] Collapsed, dirty, conflict, unavailable, empty, pending-open, and Standalone states keep their existing presentation.
- [ ] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Created 2026-09-30 from a user report after Ticket 13. `handleChooseLibrary` in `AppDelegate.swift` clears the selected document. `PaperbranchWindowPresentation.render(_:)` requires `selectedDocumentURL`, so the window falls back to the AppKit split view (Ticket 16 only made it dark). Variant B has no no-selection state, so the empty reader's design needs a decision. The alternative is to auto-select the first document after Choose Library.
