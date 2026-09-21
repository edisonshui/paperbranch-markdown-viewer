# 07: Add the document outline and reading progress

**What to build:** Add the document-navigation behavior shown in Variant B of the approved prototype. The Library window should expose an outline of the current document and show the reader's progress through it.

**Blocked by:** 04: Choose and browse a Library.

**Status:** resolved

- [x] The Library sidebar shows an outline derived from the current document's headings.
- [x] The outline preserves heading order and represents heading levels clearly.
- [x] Choosing an outline entry moves the Document view to the corresponding heading.
- [x] Editing, adding, or removing a heading updates the outline without requiring the document to close and reopen.
- [x] The reading-progress indicator responds to document length and the current scroll position.
- [x] Progress updates after a different document opens or an edit changes the document's length.
- [x] A document with no headings has a deliberate empty-outline state and remains fully usable.
- [x] Tests cover nested headings, duplicate heading text, live heading edits, long-document scrolling, document switching, and a document without headings.

## Comments

Verified 2026-09-21:

- `cd editor-proof && npm test -- --grep 'Document view exposes|selecting a duplicate|outline updates after live|reading progress follows'`: 4 navigation tests passed.
- `cd editor-proof/native-host && ./test.sh`: 23 native tests passed, including the real temporary-file Library document switch workflow.
- `cd editor-proof && npm test`: 51 editor-contract tests passed.
- `git diff --check` passed.

Implementation commit: `992ec281b5656707ebbd45b30d0bfd3c1233a66d`.
