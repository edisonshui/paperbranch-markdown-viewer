# 05: Restore and refresh the Library

**What to build:** Remember the chosen Library across launches and keep its sidebar synchronized with relevant folder changes while preserving valid user context.

**Blocked by:** 04: Choose and browse a Library.

**Status:** resolved

- [x] Paperbranch persists access to the chosen Library with a security-scoped bookmark.
- [x] Relaunching Paperbranch restores the Library without asking the user to choose it again when access remains valid.
- [x] The restored Library preserves its nested hierarchy and returns to a valid selected document and folder-expansion state when possible.
- [x] Adding, removing, renaming, or moving Markdown documents and folders on disk refreshes the visible Library hierarchy.
- [x] Refreshing the Library preserves the current selection and expanded folders when those items still exist.
- [x] If the Library bookmark no longer resolves, Paperbranch explains that access is unavailable and lets the user reconnect or choose another Library.
- [x] Losing Library access does not discard unsaved edits in an already open Document view.
- [x] Application-workflow tests cover relaunch restoration, a folder change, preservation of valid sidebar state, and the unavailable-Library flow.

## Comments

Verified 2026-09-21:

- `cd editor-proof/native-host && ./test.sh`: 19 native tests passed, including real security-scoped bookmark restoration, filesystem refresh with preserved selection and folder state, and unavailable-Library handling that retains dirty Document view edits.
- `cd editor-proof && npm test`: 47 editor-contract tests passed.
- `git diff --check` passed.

Implementation commit: `cdcf393633b5c5feb60a9d7084edf4f805c7ea2a`.
