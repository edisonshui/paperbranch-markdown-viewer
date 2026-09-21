# 09: Resolve external changes with unsaved edits

**What to build:** Protect unsaved edits when another program changes the same file. Let the user choose whether to reload the disk version or keep editing, and require explicit confirmation before a kept version overwrites newer disk content.

**Blocked by:** 08: Reload clean documents after external changes.

**Status:** resolved

- [x] An external content change while the Document view is dirty leaves the in-memory edits intact.
- [x] Paperbranch enters a visible conflict state that identifies the affected document.
- [x] Choosing to reload replaces the in-memory version with the current disk version and clears the conflict and dirty states.
- [x] Choosing to keep editing retains the in-memory version and does not write it to disk.
- [x] A later `Command-S` compares against the external disk version again and asks for explicit confirmation before overwriting it.
- [x] Canceling the overwrite leaves both the disk version and the in-memory edits unchanged.
- [x] Closing a dirty or conflicted window asks the user to save, discard, or cancel without silently losing either version.
- [x] Repeated external changes update the known disk version without replacing the retained in-memory edits.
- [x] Application-workflow tests cover both resolution choices, a canceled overwrite, a confirmed overwrite, closing while conflicted, and repeated external changes.

## Comments

Verified 2026-09-21:

- TDD seams: real temporary Markdown files observed through the public `DocumentSession` conflict, dirty, serialized Document view, and disk-byte workflow. AppKit presents document-named conflict and overwrite-confirmation sheets from that state.
- Red and green: each new resolution command and conflict state first failed because its public API or behavior did not exist. The canceled-overwrite test also demonstrated the original silent overwrite before the disk comparison was added. Targeted green checks covered visible conflict preservation, reload, keep editing, canceled and confirmed overwrite, repeated external changes, and conflicted close.
- `cd editor-proof/native-host && swift test --filter BridgeCoordinatorTests/testDirtyDocumentShowsConflictForExternalModificationWithoutReplacingEdits`: passed in 0.577 seconds.
- `cd editor-proof/native-host && swift test --filter BridgeCoordinatorTests/testReloadDiskVersionReplacesConflictedEditsAndClearsStates`: passed in 0.582 seconds.
- `cd editor-proof/native-host && swift test --filter BridgeCoordinatorTests/testKeepEditingRetainsConflictedEditsWithoutWritingDisk`: passed in 0.574 seconds.
- `cd editor-proof/native-host && swift test --filter BridgeCoordinatorTests/testSaveAfterKeepingConflictRequiresConfirmationAndLeavesBothVersionsUnchanged`: passed in 0.528 seconds.
- `cd editor-proof/native-host && swift test --filter BridgeCoordinatorTests/testConfirmedSaveAfterKeepingConflictOverwritesLatestDiskVersion`: passed in 0.547 seconds.
- `cd editor-proof/native-host && swift test --filter BridgeCoordinatorTests/testRepeatedExternalChangesKeepEditsAndReloadTheLatestDiskVersion`: passed in 0.585 seconds.
- `cd editor-proof/native-host && swift test --filter BridgeCoordinatorTests/testConflictedDocumentRemainsDirtyForTheStandardCloseWorkflow`: passed in 0.513 seconds.
- `cd editor-proof/native-host && ./test.sh`: 36 native tests passed.
- `cd editor-proof && npm test`: 51 editor-contract tests passed. The first full run had one unrelated flaky document-navigation timeout. Its targeted rerun passed, then the repeated full run passed all 51 tests.
- `git diff --check` passed before the implementation commit.

Implementation commit: `30975a123a342371215bf029137abbac81891817`.
