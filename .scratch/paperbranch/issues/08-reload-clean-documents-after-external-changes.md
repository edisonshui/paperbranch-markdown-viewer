# 08: Reload clean documents after external changes

**What to build:** Keep a clean open document current when another program changes its file, without reacting twice to Paperbranch's own saves or replacing content on an unreliable notification alone.

**Blocked by:** 02: Open, edit, and save one Markdown document.

**Status:** resolved

- [x] Paperbranch monitors each open Markdown document for external modification, replacement, movement, and deletion.
- [x] A notification causes Paperbranch to re-read and compare disk content before it treats the event as a meaningful change.
- [x] If the Document view is clean and the disk content changed, Paperbranch reloads the new Markdown in the existing document session.
- [x] A clean reload keeps the same window and continues to identify the same document where the file still exists.
- [x] Notifications caused by Paperbranch's own completed save do not trigger a second reload or a conflict.
- [x] A moved or deleted clean document receives a clear unavailable-document state instead of stale or blank content.
- [x] A dirty document is never reloaded by this behavior. It is handed to the conflict behavior in Ticket 9.
- [x] Application-workflow tests use real temporary files and cover external modification, atomic replacement, Paperbranch's own save, movement, deletion, and a dirty document.

## Comments

Verified 2026-09-21:

- TDD seam: an open `DocumentSession` with a real temporary Markdown file, observed through the Document view's serialized content, dirty state, and public availability state.
- Red: `cd editor-proof/native-host && swift test --filter BridgeCoordinatorTests/testCleanDocumentReloadsAfterAnotherProgramModifiesItsRealFile` failed before monitoring existed. The editor did not show the external content after the polling interval.
- Green: the same targeted test passed in 0.314 seconds after the monitor and disk reconciliation were added.
- `cd editor-proof/native-host && swift test --filter BridgeCoordinatorTests/testCleanDocumentReloadsAfterAtomicReplacement`: passed in 0.289 seconds. This test was already green when added because the initial monitor slice watches both the document and parent folder.
- `cd editor-proof/native-host && swift test --filter BridgeCoordinatorTests/testPaperbranchCompletedSaveDoesNotReloadItsOwnContent`: passed in 0.784 seconds.
- `cd editor-proof/native-host && swift test --filter BridgeCoordinatorTests/testCleanDocumentShowsUnavailableStateAfterMovement`: passed in 0.286 seconds.
- `cd editor-proof/native-host && swift test --filter BridgeCoordinatorTests/testCleanDocumentShowsUnavailableStateAfterDeletion`: passed in 0.286 seconds.
- `cd editor-proof/native-host && swift test --filter BridgeCoordinatorTests/testDirtyDocumentPreservesEditsAfterExternalModification`: passed in 0.793 seconds.
- `cd editor-proof/native-host && ./test.sh`: 29 native tests passed.
- `cd editor-proof && npm test`: 51 editor-contract tests passed.
- `git diff --check` passed before the implementation commit.

Implementation commit: `d3478d300aa8bd5417199502043d43f9d3158bfd`.
