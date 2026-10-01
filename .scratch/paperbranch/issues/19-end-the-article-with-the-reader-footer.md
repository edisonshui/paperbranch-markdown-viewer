# 19: End the article with the reader footer

**What to build:** Place the reader footer after the last block of the Markdown document, as in Variant B, instead of pinning it to the bottom of the Library window.

**Blocked by:** 13: Complete Variant B reader chrome in the guarded Library presentation.

**Status:** resolved

- [x] The footer appears after the document's last block and scrolls with the document.
- [x] A short document shows the footer directly after its content, not at the window bottom.
- [x] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Created 2026-09-30 from Ticket 13's visual check. The footer is SwiftUI chrome outside the injected `WKWebView`, so ending the article may need the footer inside the web Document view or a scroll-linked layout.

Resolved 2026-09-30. The footer now lives in the Document view. `editor-proof/index.html` wraps `#editor-root` in an `#document` article, and `#document-footer` ("End of document", "Local Markdown") follows the editor root, outside Milkdown, so it never enters the serialized Markdown. `loadMarkdown` hides the footer for a document blocked by admission. The SwiftUI footer pinned under the canvas is removed, so the canvas runs to the window bottom. Because the footer is in the web page, the AppKit fallback and Standalone windows show it too.

Found while checking this ticket: the Xcode "Bundle offline editor" phase listed an output and no inputs, so Xcode skipped it once `Web/index.html` existed. The packaged app and `verify-package.sh` were still using the editor built at 12:30 that day. No committed web change came after that build, so earlier verification was not affected. The phase now sets `alwaysOutOfDate = 1` (commit `f8ee5ad`).

Verified 2026-09-30:

- Red: `cd editor-proof && npx playwright test tests/constructs/reader-chrome.spec.ts` failed 2 of 3 with `element(s) not found` for `#document-footer`. The tests check that the footer starts after the last block, within 120 pixels for a short document and more than 100 pixels above the viewport bottom, that it is out of view at the top of a long document and in view at its end, and that the loaded Markdown is unchanged. The blocked-document test passed before and after.
- Red: `cd editor-proof/native-host && PAPERBRANCH_PACKAGED_APP_PATH="$PWD/.build/Paperbranch.app" swift test --filter BridgeCoordinatorTests/testExpandedLibraryPresentationShowsVariantBReaderChromeAroundInjectedDocumentView` failed on the SwiftUI footer still existing, and on the canvas ending 63 points above the window bottom.
- Green: both focused runs passed. The full Playwright suite passed 54 of 54.
- `cd editor-proof/native-host && ./verify-package.sh`: Xcode Release build succeeded and all 59 packaged native tests passed, with the rebuilt web editor in the bundle.
- `git diff --check`: passed.
- Packaged app, `/private/tmp/pb15-library`: `Note.md` shows the footer directly under "Text.", not at the window bottom. In `Reading.md` the footer is off screen at the top and ends the document after Section 8 when scrolled to the end. The library was unchanged afterwards. Screenshots, not committed: `/tmp/pb19-short-s.png`, `/tmp/pb19-long-end-s.png`.

Implementation commits: `f8ee5ad`, `f1b2d7a`.
