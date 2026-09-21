# 03: Display local images safely

**What to build:** Make local images referenced by a Markdown document appear in the formatted Document view without giving the web editor unrestricted access to local files.

**Blocked by:** 02: Open, edit, and save one Markdown document.

**Status:** resolved

- [x] A relative image reference resolves from the Markdown document's containing folder.
- [x] Valid local images appear in the Document view without rewriting their Markdown references.
- [x] The native layer resolves and validates each requested local path before it returns image data to the editor.
- [x] The editor cannot use the image-loading mechanism to read an arbitrary local file that the document is not authorized to access.
- [x] A missing, unreadable, or invalid image leaves the document usable and presents a clear broken-image state.
- [x] Images remain visible after editing, saving, and reopening the document.
- [x] Automated tests cover a valid relative image, a missing image, a path containing spaces, and a rejected unauthorized path.

## Comments

Verified 2026-09-21:

- `cd editor-proof && npm test`: 47 browser editor-contract tests passed, including the broken-image state.
- `cd editor-proof && ./native-host/test.sh`: 13 native `WKWebView` tests passed. `LocalImageResolverTests` covers valid relative images, missing files, paths with spaces, invalid image data, and rejected traversal outside the Markdown document's folder. The native workflow test confirms an image remains visible through editing, save, and reopen without changing its Markdown reference.
- `git diff --check` passed.

Implementation commit: `11b9988835333362c4ea3582199eec6b25493364`.
