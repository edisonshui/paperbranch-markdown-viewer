# 02: Open, edit, and save one Markdown document

**What to build:** Build the first complete Paperbranch workflow. The user opens one local Markdown document in a native Mac window, reads and edits it as formatted content, sees whether it has unsaved changes, and saves it back to the same file with `Command-S`.

**Blocked by:** 01: Prove formatted Markdown editing.

**Status:** ready-for-agent

- [ ] Paperbranch launches as a native macOS application and can open one `.md` or `.markdown` file through an Open command.
- [ ] The Document view uses the selected editor and follows the reading layout and visual direction of Variant B of the approved prototype.
- [ ] The user edits formatted content directly. Paperbranch provides no raw Markdown mode or split view.
- [ ] The window indicates when the document has unsaved edits.
- [ ] Typing does not write to disk, and the original file remains unchanged until the user invokes `Command-S`.
- [ ] `Command-S` works while focus is inside the Document view, writes serialized Markdown to the original file, and clears the dirty state only after the write succeeds.
- [ ] Equivalent syntax may normalize, but saving preserves the semantic structure covered by the editor contract.
- [ ] A failed serialization or file write leaves the document dirty and shows an error for the affected document.
- [ ] Closing a dirty document asks the user whether to save, discard, or cancel.
- [ ] An application-workflow test opens a temporary Markdown file, edits it, proves the file remains unchanged before `Command-S`, saves it, and verifies the resulting file content.
