# 04: Choose and browse a Library

**What to build:** Let the user choose one folder as the Library and browse its Markdown documents in the Paperbranch Library window during the current application session.

**Blocked by:** 02: Open, edit, and save one Markdown document.

**Status:** resolved

- [x] A first-time user can choose a folder as the Library.
- [x] The Library sidebar mirrors the chosen folder's nested hierarchy.
- [x] The sidebar includes regular files with `.md` and `.markdown` extensions using case-insensitive matching and excludes unrelated files.
- [x] The user can expand and collapse folders in the hierarchy.
- [x] The user can collapse and reopen the entire Library sidebar as shown in Variant B of the approved prototype.
- [x] Selecting a Markdown document opens it in the Library window's Document view and clearly marks the selection.
- [x] Switching between Library documents does not write either document unless the user invokes `Command-S`.
- [x] Paperbranch does not copy, import, move, rename, or delete Library contents.
- [x] An application-workflow test chooses a temporary nested Library, verifies its visible hierarchy, selects documents, and exercises the collapsed sidebar state.

## Comments

Verified 2026-09-21:

- `cd editor-proof/native-host && ./test.sh`: 16 native tests passed, including the temporary nested-Library workflow, extension filtering, sidebar collapse state, document selection, and no-write-on-switch behavior.
- `cd editor-proof && npm test`: 47 editor-contract tests passed.
- `git diff --check` passed.

Implementation commit: `c6aadcdab8eb27d400d35733a626ed76035d083a`.
