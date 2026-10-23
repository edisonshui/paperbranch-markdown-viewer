# 45: Restyle Standalone windows

**What to build:** Give each Standalone window the guideline's chrome: a top bar holding the window buttons and the document name with its status, the reading progress line, and the Document view, with no sidebar toggle and no Open button.

**Blocked by:** 41: Restyle the Library window chrome.

**Status:** resolved

- [x] The top bar names the document and shows "· Edited" or "· Changed on disk".
- [x] No Library parts: no sidebar, no toggle, no Open button, no Open now card.
- [x] The progress line follows the reading position.
- [x] Close, save, and conflict behavior is unchanged.
- [x] Focused test passes red-to-green, then both suites pass.

## Comments

Created 2026-10-22. Part of the switch to the brand guideline.

Resolved 2026-10-22.

- `PaperbranchStandalonePresentation` (new, in `PaperbranchBridgeCore`) renders `PBTopBar` with the document name and status, no sidebar toggle, and no Open button, then `PBReadingProgress` and the Document view, with `PBOutlinePanel` at 1240 px and wider. The window runs its content under a transparent title bar with an empty unified toolbar, as the Library window does, so the window buttons sit in the 52 px row, and the top bar starts 64 px in to clear them.
- `StandaloneDocumentWindow` uses it in place of the AppKit `DocumentPresentationViewController`, and `AppDelegate` now passes the session's dirty, conflict, availability, and navigation changes to it. Close, save, and conflict handling are unchanged.
- Judgment call: a Standalone document that moves or is deleted shows `PBStateView` "Document unavailable" with "<name> may have been moved or deleted." The skill's sentence ends "Choose another document from the Library", which does not apply without a Library.
- Test helper fix: the accessibility walk in the tests now skips nodes that do not answer `accessibilityChildren`. A loaded Document view has such nodes, and the exception aborted the async test inside XCTest (measured with an `objc_exception_throw` breakpoint).

Verified 2026-10-22:

- Red: `testStandaloneWindowShowsTheGuidelineChromeWithoutLibraryParts` failed (no full-size content, top bar, progress line, or canvas).
- Green: it passed. It checks the top bar label clean and Edited, the progress line, the canvas, and the absence of the toggle, Open, sidebar, and Open now card. The existing Standalone size, close, discard, and Command-S tests still pass.
- `./verify-package.sh`: 77 packaged native tests passed. `npx playwright test`: 75 of 75 passed.
- Not seen in the running app: Edison was back at the Mac, so the Standalone window needs his visual check in light and dark.

Implementation commit: `1324b7c`.
