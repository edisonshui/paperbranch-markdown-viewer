# Paperbranch

Paperbranch is a personal macOS app for reading and editing local Markdown documents. It restores a folder-based library when it launches.

## Language

**Library**:
The folder Paperbranch remembers and restores as the user's persistent collection of Markdown documents. Paperbranch preserves its nested folder structure in the sidebar.
_Avoid_: Workspace, vault

**Markdown document**:
A `.md` or `.markdown` file that Paperbranch can render and edit.
_Avoid_: Note, page

**Standalone document**:
A Markdown document opened directly from Finder outside the Library. Paperbranch edits it in place without adding it to the Library.
_Avoid_: Imported document, temporary document

**Document view**:
The main pane that renders a Markdown document as formatted content and allows the user to edit that content directly.
_Avoid_: Preview, source editor

**Library window**:
The single window that contains the Library sidebar and the selected Library document's Document view.
_Avoid_: Main window, workspace window

**Standalone window**:
A separate window containing one Standalone document.
_Avoid_: Tab, temporary window
