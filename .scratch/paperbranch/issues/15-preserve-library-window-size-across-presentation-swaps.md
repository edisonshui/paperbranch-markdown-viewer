# 15: Preserve the Library window size across presentation swaps

**What to build:** Keep the Library window at the size the user chose when `PaperbranchWindowPresentation` swaps between the AppKit and SwiftUI presentations, and stop the swap from repeating when nothing about the document or Library has changed. Keep the guard policy, the injected `WKWebView`, synchronous AppKit restoration, and every AppKit workflow unchanged.

**Blocked by:** 12: Render Variant B's clean expanded Library reading state.

**Status:** resolved

- [x] The cause of the repeated swap in the packaged app is identified and recorded in Comments.
- [x] Swapping from AppKit to SwiftUI and back leaves the Library window frame unchanged.
- [x] With the Library, document, and sidebar unchanged, the 1 s Library refresh does not swap presentations.
- [x] In the packaged app, a clean document in a fully expanded Library can be resized, and the window keeps its new size.
- [x] Focused tests pass red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Created 2026-09-30 from the Ticket 13 visual check. The packaged Library window stayed at about 340x220 and snapped back right after every resize, so Variant B's reader chrome could not be compared at a usable size. This blocks the Ticket 13 visual checkbox and likely explains the narrow window described in Ticket 14.

Findings so far, not all confirmed:

- Assigning `window.contentViewController` resizes the window to that view controller's view frame. `restoreAppKitPresentation()` does this, and it reset a 1440-wide test window to 340x230.
- The first SwiftUI render grows the window only to SwiftUI's minimum size, about 340x230.
- An lldb breakpoint showed `restoreAppKitPresentation()` being entered from a main-thread `Task`, which fits the 1 s `libraryRefreshTimer` path (`refreshLibraryIfNeeded()` then `showLibrary()` then `refreshWindowPresentation()`).
- Unconfirmed guess: `LibrarySidebarViewController.show(_:)` reloads the detached outline view, which may post collapse notifications through `folderExpansionChanged`. That would fail the every-folder-expanded check and restore AppKit each second.

Confirmed cause, 2026-09-30, from temporary file logging in the packaged app (removed before commit). There were two faults, and together they produced the snap-back:

- Every 1 s tick, `refreshLibraryIfNeeded()` calls `showLibrary()`, which calls `LibrarySidebarViewController.show(_:)`. Its `reloadData()` and `select(url:)` post `outlineViewSelectionDidChange`, which routed the reselected document through `selectDocument`, then `routeFinderOpen`, then `restoreAppKitPresentation()`. The reopen then rendered SwiftUI again. The log showed this restore-then-swap cycle each second with every guard condition passing (`allExpanded=true`, no collapse notifications), so the collapse-notification guess above was wrong.
- `restoreAppKitPresentation()` assigns `window.contentViewController`, which resized the window to the split view controller's detached view. The log showed a 924x682 user resize reset to 747x320 by the next restore. Assigning `window.contentView` for the SwiftUI swap kept the frame.

Fix: `restoreAppKitPresentation()` keeps the window frame across the controller assignment, and the sidebar ignores selection notifications it posts itself during `show(_:)` and `select(url:)`. User clicks in the sidebar still route through `selectDocument`. The guard policy, injected `WKWebView`, synchronous AppKit restoration, and ineligible AppKit states are unchanged. The test target now depends on `PaperbranchEditorProofHost` so the sidebar can be tested.

Verified 2026-09-30:

- Red: `cd editor-proof/native-host && swift test --filter 'testPresentationSwapsKeepTheLibraryWindowFrame|testUnchangedLibraryRefreshDoesNotSwapPresentations'` failed with 5 failures. After a 1440x900 resize, each AppKit restore returned the window to 340x252. The unchanged sidebar refresh routed `Reading.md` twice and left AppKit showing before the next render.
- Green: the same command passed with 0 failures after the fix.
- `cd editor-proof/native-host && ./verify-package.sh`: Xcode Release build succeeded and all 46 packaged native tests passed.
- `git diff --check`: passed.
- Packaged app: with a clean `Reading.md` open in a fully expanded fixture Library, the SwiftUI Variant B presentation was showing. A resize to 1300x820 held through 4 refresh ticks, and a resize to 1432x855 held through 10 ticks. Screenshot at `/tmp/pb15-resize.png`, not committed.

Implementation commit: `914df55`.
