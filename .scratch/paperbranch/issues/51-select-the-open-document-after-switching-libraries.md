# 51: Select the open document after switching Libraries

**What to build:** After choosing another Library and switching back, clicking the document still open in the Library window selects and shows it, the same as any other document.

**Blocked by:** none.

**Status:** resolved

- [x] Focusing a document already open in the Library window selects it when it is in the current Library, and the window redraws with it selected.
- [x] A focused native test fails before the fix and passes after, then both suites pass.

## Comments

Reported by Edison 2026-10-23: after switching from the empty Library back to the Sample Library, clicking `project-ideas.md` did nothing. Clicking `report-2026-10-15-3br.md` first, then `project-ideas.md`, worked.

Cause, read from the code and reproduced in a test: `LibraryWorkflow.chooseLibrary` clears the selection, but `FinderOpenWorkflow` still lists `project-ideas.md` as open in the Library window. Clicking it returned `.focused`, which only brought the window forward and never called `selectDocument`, so the document stayed unselected and the Document view kept saying "Choose a document from the Library". Opening another document replaced the Library window's entry, so the next click on `project-ideas.md` opened it normally.

Resolved 2026-10-23. `FinderOpenWorkflow.focus` selects a focused Library window's document again when it is in the current Library. `AppDelegate.showFocusedLibraryDocument` selects the sidebar row and redraws the window before bringing it forward. The document is not reloaded, so unsaved edits stay.

Verified 2026-10-23:

- Red: `testSelectingTheOpenDocumentAfterSwitchingLibrariesSelectsItAgain` failed, with the selection nil after the click.
- Green: that test passed. `./verify-package.sh`: 82 packaged native tests passed. `npx playwright test`: 83 passed and 1 failed on the first run, then 84 of 84 passed on six reruns. This ticket changed no web code, and the failure did not come back, so which test flaked is not known.
- Not measured: the fix in the running app. It needs Edison's check by eye.
