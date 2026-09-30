# 14: Return to AppKit when toggling the Library sidebar from the reader

**What to build:** Let the guarded SwiftUI reader’s sidebar control restore the existing AppKit Library window and then invoke the existing sidebar toggle. This must make the collapsed Library state reachable without duplicating sidebar, DocumentSession, or workflow behavior.

**Blocked by:** 12: Render Variant B's clean expanded Library reading state.

**Status:** claimed

- [ ] The reader’s sidebar control is available while the guarded SwiftUI presentation is visible.
- [ ] Toggling it synchronously restores the captured AppKit content and delegates to the existing Library sidebar toggle.
- [ ] The collapsed, dirty, conflict, unavailable, empty, pending-open, and Standalone states continue to use existing AppKit presentation.
- [ ] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Created 2026-09-21 from Ticket 10 visual verification. In the packaged reader at the restored narrow window width, the AppKit toolbar Sidebar item was disabled and the SwiftUI reader icon was not a control, leaving the document canvas unusably narrow and making the required collapsed AppKit state unreachable.
