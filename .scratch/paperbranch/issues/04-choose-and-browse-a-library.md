# 04: Choose and browse a Library

**What to build:** Let the user choose one folder as the Library and browse its Markdown documents in the Paperbranch Library window during the current application session.

**Blocked by:** 02: Open, edit, and save one Markdown document.

**Status:** ready-for-agent

- [ ] A first-time user can choose a folder as the Library.
- [ ] The Library sidebar mirrors the chosen folder's nested hierarchy.
- [ ] The sidebar includes regular files with `.md` and `.markdown` extensions using case-insensitive matching and excludes unrelated files.
- [ ] The user can expand and collapse folders in the hierarchy.
- [ ] The user can collapse and reopen the entire Library sidebar as shown in Variant B of the approved prototype.
- [ ] Selecting a Markdown document opens it in the Library window's Document view and clearly marks the selection.
- [ ] Switching between Library documents does not write either document unless the user invokes `Command-S`.
- [ ] Paperbranch does not copy, import, move, rename, or delete Library contents.
- [ ] An application-workflow test chooses a temporary nested Library, verifies its visible hierarchy, selects documents, and exercises the collapsed sidebar state.
