# 05: Restore and refresh the Library

**What to build:** Remember the chosen Library across launches and keep its sidebar synchronized with relevant folder changes while preserving valid user context.

**Blocked by:** 04: Choose and browse a Library.

**Status:** ready-for-agent

- [ ] Paperbranch persists access to the chosen Library with a security-scoped bookmark.
- [ ] Relaunching Paperbranch restores the Library without asking the user to choose it again when access remains valid.
- [ ] The restored Library preserves its nested hierarchy and returns to a valid selected document and folder-expansion state when possible.
- [ ] Adding, removing, renaming, or moving Markdown documents and folders on disk refreshes the visible Library hierarchy.
- [ ] Refreshing the Library preserves the current selection and expanded folders when those items still exist.
- [ ] If the Library bookmark no longer resolves, Paperbranch explains that access is unavailable and lets the user reconnect or choose another Library.
- [ ] Losing Library access does not discard unsaved edits in an already open Document view.
- [ ] Application-workflow tests cover relaunch restoration, a folder change, preservation of valid sidebar state, and the unavailable-Library flow.
