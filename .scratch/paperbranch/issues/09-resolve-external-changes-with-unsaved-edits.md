# 09: Resolve external changes with unsaved edits

**What to build:** Protect unsaved edits when another program changes the same file. Let the user choose whether to reload the disk version or keep editing, and require explicit confirmation before a kept version overwrites newer disk content.

**Blocked by:** 08: Reload clean documents after external changes.

**Status:** ready-for-agent

- [ ] An external content change while the Document view is dirty leaves the in-memory edits intact.
- [ ] Paperbranch enters a visible conflict state that identifies the affected document.
- [ ] Choosing to reload replaces the in-memory version with the current disk version and clears the conflict and dirty states.
- [ ] Choosing to keep editing retains the in-memory version and does not write it to disk.
- [ ] A later `Command-S` compares against the external disk version again and asks for explicit confirmation before overwriting it.
- [ ] Canceling the overwrite leaves both the disk version and the in-memory edits unchanged.
- [ ] Closing a dirty or conflicted window asks the user to save, discard, or cancel without silently losing either version.
- [ ] Repeated external changes update the known disk version without replacing the retained in-memory edits.
- [ ] Application-workflow tests cover both resolution choices, a canceled overwrite, a confirmed overwrite, closing while conflicted, and repeated external changes.
