# 30: Stay in Variant B while editing, switching, and toggling the sidebar

**What to build:** Keep the Library window in the Variant B presentation for the routine states that now swap it to the AppKit presentation: unsaved edits, a conflict, a document switch, and a collapsed sidebar.

**Blocked by:** 11: Guard SwiftUI Library presentation activation.

**Status:** resolved

- [x] Typing into a clean document and saving it keep the Variant B presentation, and the reader top bar shows that the document has unsaved edits.
- [x] A conflict keeps the Variant B presentation, shows the existing conflict alert, and the top bar shows the conflict.
- [x] Selecting another Library document never shows the AppKit presentation, including while the new document loads.
- [x] Collapsing the Library sidebar hides the Variant B sidebar and keeps the reader. Reopening it brings the sidebar back.
- [x] The AppKit presentation still covers an unavailable Library, an unavailable document, and a Library with no documents.
- [x] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Found 2026-10-22 in the UX audit. This is the main reason the app does not feel smooth.

- Selecting Long essay.md from the Variant B sidebar showed the AppKit presentation (title bar, toolbar, blue-gray sidebar at about half the window) for about three captured frames before Variant B returned.
- The first keystroke in a clean document swapped the whole window to the AppKit presentation, which reflowed the article at a different width. Saving swapped it back, and the article then sat about 38 points lower than before.
- The sidebar toggle swapped to the AppKit presentation with a title bar and toolbar.
- Cause (read in code): Ticket 11 made the Variant B presentation render only clean, expanded, settled states as a migration guard, and `routeFinderOpen` and `toggleLibrarySidebar` restore AppKit before they act. Ticket 11 records no product reason to leave Variant B for these states.

Resolved 2026-10-22.

- `PaperbranchWindowPresentation.render(_:)` now restores AppKit only for a missing or empty Library, an unavailable document, a Standalone snapshot, a selection outside the Library, and (kept from Ticket 18) unsaved work behind the empty reader. Unsaved edits, a conflict, a collapsed sidebar, and a document switch still loading stay in Variant B.
- The reader top bar shows "Edited" or "Changed on disk" after the document name, in the accent color. The window's close button also shows its standard unsaved dot. The wording and color are placeholders until the brand guideline settles them (needs Edison).
- A collapsed sidebar removes the Variant B sidebar column, and the top bar moves clear of the window buttons. `routeFinderOpen` and `toggleLibrarySidebar` no longer restore AppKit first.
- Staying in Variant B exposed a hidden bug: Command-S did nothing there, because WKWebView claims every key equivalent while it has focus and its handback never reached the File menu inside the SwiftUI host (File > Save worked). Before this ticket, a dirty document always switched to AppKit, which hid it. `AppDelegate.handleKeyDown(_:keyWindow:)` now takes Command-S in a local key monitor before the Document view. Saves also update the saved document's own window title instead of whichever window is key.

Verified 2026-10-22:

- Red: `testPresentationStaysInVariantBForRoutineStatesAndRestoresAppKitOnlyForUnavailableOrEmptyStates`, `testReaderTopBarShowsUnsavedEditsAndConflictsAndCollapsedSidebarHidesOnlyTheSidebar`, and `testReaderSidebarToggleKeepsVariantBAndDelegatesToExistingSidebarWorkflow` failed. `testCommandSSavesTheKeyWindowsDocumentBeforeTheDocumentViewSeesTheKey` failed with the handler stubbed to pass the event through.
- Green: all four passed. `./verify-package.sh`: 65 packaged native tests passed. `npx playwright test`: 57 of 57 passed.
- Packaged app, eight window captures per action: selecting Long essay.md never showed the AppKit presentation. Typing showed "Edited" and kept the window size. Command-S wrote the file and cleared "Edited". Collapsing the sidebar stayed in Variant B. A dirty document changed on disk showed "Changed on disk" and the conflict alert in Variant B, and Reload Disk loaded the disk version.

Implementation commit: `a337508`.
