# 07: Add the document outline and reading progress

**What to build:** Add the document-navigation behavior shown in Variant B of the approved prototype. The Library window should expose an outline of the current document and show the reader's progress through it.

**Blocked by:** 04: Choose and browse a Library.

**Status:** ready-for-agent

- [ ] The Library sidebar shows an outline derived from the current document's headings.
- [ ] The outline preserves heading order and represents heading levels clearly.
- [ ] Choosing an outline entry moves the Document view to the corresponding heading.
- [ ] Editing, adding, or removing a heading updates the outline without requiring the document to close and reopen.
- [ ] The reading-progress indicator responds to document length and the current scroll position.
- [ ] Progress updates after a different document opens or an edit changes the document's length.
- [ ] A document with no headings has a deliberate empty-outline state and remains fully usable.
- [ ] Tests cover nested headings, duplicate heading text, live heading edits, long-document scrolling, document switching, and a document without headings.
