# 35: Protect unsaved edits when switching Library documents

**What to build:** Decide what Paperbranch does with unsaved edits when the user opens another Library document, then make every route that replaces the Library window's document follow that decision.

**Blocked by:** 30: Stay in Variant B while editing, switching, and toggling the sidebar.

**Status:** ready-for-agent

- [ ] The behavior follows the decision recorded in this ticket.
- [ ] Selecting another document in the sidebar, the Open button or File > Open on a Library document, a Finder open of a Library document, and Choose Library all follow it.
- [ ] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Found 2026-10-22 in the UX audit, by reading code. Not reproduced in the app: the audit stopped driving the keyboard once Edison was using the Mac.

- `routeFinderOpen` calls `openLibraryDocument`, which calls `DocumentSession.open(_:)`. That loads the new Markdown into the editor and sets `isDirty = false`. Nothing on this path checks `isDirty`, so unsaved edits in the Library window are discarded without a prompt (inferred).
- Before Ticket 30 this was hard to hit by accident, because a dirty document swapped the window to the AppKit presentation. It is easier now that the Variant B sidebar stays visible while editing.
- The specification says not to write when switching documents (Saving and dirty state) and that closing a dirty window uses the standard unsaved-change flow. It does not say what switching does with unsaved edits.

Needs Edison's decision. Options:

1. Ask first, reusing the close alert: Save, Cancel, Discard. Recommended, because it matches the close flow and the specification's rule against silently discarding work.
2. Keep the edits in memory per document and restore them when the user comes back. More work, and Paperbranch has no per-document buffers today.
3. Block the switch until the user saves.
