# 03: Display local images safely

**What to build:** Make local images referenced by a Markdown document appear in the formatted Document view without giving the web editor unrestricted access to local files.

**Blocked by:** 02: Open, edit, and save one Markdown document.

**Status:** ready-for-agent

- [ ] A relative image reference resolves from the Markdown document's containing folder.
- [ ] Valid local images appear in the Document view without rewriting their Markdown references.
- [ ] The native layer resolves and validates each requested local path before it returns image data to the editor.
- [ ] The editor cannot use the image-loading mechanism to read an arbitrary local file that the document is not authorized to access.
- [ ] A missing, unreadable, or invalid image leaves the document usable and presents a clear broken-image state.
- [ ] Images remain visible after editing, saving, and reopening the document.
- [ ] Automated tests cover a valid relative image, a missing image, a path containing spaces, and a rejected unauthorized path.
