# 35: Protect unsaved edits when switching Library documents

**What to build:** Decide what Paperbranch does with unsaved edits when the user opens another Library document, then make every route that replaces the Library window's document follow that decision.

**Blocked by:** 30: Stay in Variant B while editing, switching, and toggling the sidebar.

**Status:** resolved

- [x] The behavior follows the decision recorded in this ticket.
- [x] Selecting another document in the sidebar, the Open button or File > Open on a Library document, and a Finder open of a Library document all follow it. (Choose Library keeps the open document, per Ticket 18, so it replaces nothing and does not ask.)
- [x] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Found 2026-10-22 in the UX audit, by reading code. Not reproduced in the app: the audit stopped driving the keyboard once Edison was using the Mac.

- `routeFinderOpen` calls `openLibraryDocument`, which calls `DocumentSession.open(_:)`. That loads the new Markdown into the editor and sets `isDirty = false`. Nothing on this path checks `isDirty`, so unsaved edits in the Library window are discarded without a prompt (inferred).
- Before Ticket 30 this was hard to hit by accident, because a dirty document swapped the window to the AppKit presentation. It is easier now that the Variant B sidebar stays visible while editing.
- The specification says not to write when switching documents (Saving and dirty state) and that closing a dirty window uses the standard unsaved-change flow. It does not say what switching does with unsaved edits.

Needs Edison's decision. Options:

1. Ask first, reusing the close alert: Save, Cancel, Discard. Recommended, because it matches the close flow and the specification's rule against silently discarding work.
2. Keep the edits in memory per document and restore them when the user comes back. More work, and Paperbranch has no per-document buffers today.
3. Block the switch until the user saves.

## Decision

Decided by Edison 2026-10-22, relayed by the coordinator.

- Switching Library documents with unsaved edits shows the existing close alert: Save, Cancel, Discard.
- Save writes the file, then switches. It uses the conflict-aware save path, so a document that changed on disk goes through the existing overwrite warning instead of being overwritten silently.
- Cancel keeps the current document. The sidebar selection snaps back to it.
- Discard switches without saving.

Resolved 2026-10-22.

- `AppDelegate.routeFinderOpen(_:)` is the one entry point for sidebar selections (both presentations), Open, File > Open, and Finder opens. When the Library document has unsaved edits and the request includes a different Library document, it shows the close alert first. Save calls the same `save(_:in:afterSave:afterCancel:)` as Command-S, then switches. Cancel, a cancelled overwrite warning, or a failed save keeps the current document, puts the AppKit sidebar's selection back on it, and still opens any Standalone documents in the same request. Discard switches without writing. The close alert's text now comes from one shared `unsavedChangesAlert(for:)`.
- Test seam: `AppDelegate` takes its `LibraryWorkflow` in `init`, and `setUpLibraryWindow()` builds the Library window without the menu, key monitor, Library restore, or refresh timer. `applicationDidFinishLaunching` calls it, then does the rest in the same order as before.
- Also fixed: two Swift 6 warnings from Tickets 30 and 34 (the key monitor's `NSEvent` crossing the main actor, and the frame key's isolation).
- Needs Edison (found while testing, behavior from Ticket 09, not changed here): when a dirty document changes on disk, the conflict makes the changed file the new baseline. After Keep Editing, Save then overwrites that version with no further warning. The overwrite warning appears only if the file changes again before the file monitor sees it. The specification says a later save must "require explicit confirmation before replacing" the external version, which reads as asking every time.

Verified 2026-10-22:

- Red: `swift test --filter BridgeCoordinatorTests/testSwitchingAwayFromUnsavedEditsAsksToSaveCancelOrDiscard` failed: no alert appeared, and the switch went through.
- Green: that test passed. It drives the real Library window: Cancel keeps A dirty with A selected in the workflow and the AppKit sidebar; Discard opens B and leaves A unchanged on disk; Save writes A and opens B. The overwrite-warning branch is not exercised, because the test cannot reliably change the file without the monitor noticing first.
- `./verify-package.sh`: 69 packaged native tests passed. `npx playwright test`: 68 of 68 passed.

Implementation commit: `c6e3c61`.
