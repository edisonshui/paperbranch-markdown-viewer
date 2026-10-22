# 30: Stay in Variant B while editing, switching, and toggling the sidebar

**What to build:** Keep the Library window in the Variant B presentation for the routine states that now swap it to the AppKit presentation: unsaved edits, a conflict, a document switch, and a collapsed sidebar.

**Blocked by:** 11: Guard SwiftUI Library presentation activation.

**Status:** ready-for-agent

- [ ] Typing into a clean document and saving it keep the Variant B presentation, and the reader top bar shows that the document has unsaved edits.
- [ ] A conflict keeps the Variant B presentation, shows the existing conflict alert, and the top bar shows the conflict.
- [ ] Selecting another Library document never shows the AppKit presentation, including while the new document loads.
- [ ] Collapsing the Library sidebar hides the Variant B sidebar and keeps the reader. Reopening it brings the sidebar back.
- [ ] The AppKit presentation still covers an unavailable Library, an unavailable document, and a Library with no documents.
- [ ] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Found 2026-10-22 in the UX audit. This is the main reason the app does not feel smooth.

- Selecting Long essay.md from the Variant B sidebar showed the AppKit presentation (title bar, toolbar, blue-gray sidebar at about half the window) for about three captured frames before Variant B returned.
- The first keystroke in a clean document swapped the whole window to the AppKit presentation, which reflowed the article at a different width. Saving swapped it back, and the article then sat about 38 points lower than before.
- The sidebar toggle swapped to the AppKit presentation with a title bar and toolbar.
- Cause (read in code): Ticket 11 made the Variant B presentation render only clean, expanded, settled states as a migration guard, and `routeFinderOpen` and `toggleLibrarySidebar` restore AppKit before they act. Ticket 11 records no product reason to leave Variant B for these states.
