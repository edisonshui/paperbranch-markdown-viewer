# 22: Match Variant B's sidebar navigation

**What to build:** Map Variant B's sidebar sections onto Paperbranch's nested Library tree as decided below, and make the tree's folders expand and collapse in the Variant B presentation.

**Blocked by:** 13: Complete Variant B reader chrome in the guarded Library presentation.

**Status:** resolved

## Decision

Decided 2026-10-01 in a grilling session.

- **All documents** is not a separate item. The nested tree under the "LIBRARY" label already shows every document, so a row that does nothing would be noise.
- **Favorites** and **Recently opened** are dropped for the first version and listed in the specification's "Out of scope." Each needs a new saved concept and its own rules, which makes it a feature rather than a visual match.
- **Open now** is a single card for the selected Library document, placed above the tree, right under the wordmark, so a long tree can't push it out of view. It shows the document name and its word count ("1,240 words"), with no other text. It is small and muted, with no heavy border or accent, so it doesn't compete with the tree's selected row.
- The card's word count comes from the editor over the bridge, next to outline and progress messages. It reuses Ticket 21's count so the card and the meta line never disagree. Native code does not count words itself.
- The card is hidden when no Library document is selected, and clicking it does nothing.
- It shows no unsaved-changes marker. A dirty document switches the window to the AppKit fallback, so the Variant B sidebar never shows a dirty document.
- Open now covers only the Library window. Standalone windows are not listed (ADR 0001).
- Folders expand and collapse using the existing `LibrarySidebarState`, whose collapsed folders are already saved and restored. Paperbranch respects a collapse even when the selected document is inside the collapsed folder, and never expands folders automatically.

- [x] The sidebar has no All documents, Favorites, or Recently opened items.
- [x] An Open now card above the tree shows the selected document's name and word count, and is hidden when nothing is selected.
- [x] The card's word count matches the Document view's meta line, including after an edit is saved and after an external reload.
- [x] Folders in the Variant B sidebar expand and collapse, and their state persists across launches.
- [x] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Created 2026-09-30 from Ticket 13's visual check. The specification requires the sidebar to mirror the Library's folders, and Variant B shows flat navigation items instead, so this needs a design decision before implementation.

2026-10-01: Decision recorded above. Folder expand and collapse moved into this ticket because the Variant B view drew folders as static headers and ignored `LibrarySidebarState`, which falls short of specification story 6.

Resolved 2026-10-01.

- The editor adds `wordCount` to its existing `navigationStateChanged` message. It is the same number `showDocumentStats` puts in the meta line, and null for a blocked document. The listener now refreshes the count before it reports navigation, and a blocked load also reports navigation, so a blocked document clears the previous document's outline and count.
- `PaperbranchWindowPresentationState` carries `wordCount`. The sidebar shows "OPEN NOW" with the name and count above "LIBRARY" only when a document is selected.
- Folder rows are buttons with a chevron. `PaperbranchWindowPresentation.setFolder(_:expanded:)` dispatches only for folders in the rendered Library, and the app routes it to `LibraryWorkflow.setFolder` and then refreshes both sidebars.
- The presentation no longer falls back to AppKit when a folder is collapsed. That guard existed only because the Variant B tree could not show a collapse (Tickets 11 and 12). A collapsed whole sidebar still uses AppKit.

Verified 2026-10-01:

- Red: `cd editor-proof/native-host && swift test --filter BridgeCoordinatorTests/testLibrarySidebarShowsOpenNowAboveCollapsibleFolders` failed to compile because the presentation had no `onSetFolderExpanded` action, no `wordCount` state, and a two-argument `navigationStateDidChange`.
- Green: that test passed. It checks that the flat items are absent, the card label is "Open now: Selected.md, 1,240 words" and sits above the first folder, a collapsed folder still renders in Variant B and hides its documents, folder presses report the right expansion, and the card is hidden with no selection. The presentation filter `'BridgeCoordinatorTests/(testPresentation|testExpandedLibrary|testReaderSidebar|testRenderedLibrary|testReaderTopBar|testSidebarWordmark)'` passed after collapsed-folder states were removed from the two AppKit fallback lists.
- Green: `testNavigationWordCountMatchesTheMetaLineThroughEditSaveAndExternalReload`, against the packaged editor, passed. The bridge count equals the meta line at 1 word on open, 3 after an edit and after save, and 5 after an external atomic replacement. An in-place external write right after a save is not detected, which is the existing limitation noted in `testSavingDirtyDocumentReportsNoConflictButLaterExternalChangeDoes`.
- `cd editor-proof/native-host && ./verify-package.sh`: all 62 packaged native tests passed. `cd editor-proof && npx playwright test`: 57 of 57 passed. `git diff --check`: passed.
- Packaged app: the card read "Note.md, 2 words", matching the meta line. Clicking Essays collapsed it and the window stayed in Variant B. After quitting and relaunching, Essays was still collapsed. Clicking it again restored the original expanded state. Screenshots were deleted.

Re-verified 2026-10-22: `./verify-package.sh` passed 62 packaged native tests and `npx playwright test` passed 57 of 57.

Implementation commit: `57796a5`.
