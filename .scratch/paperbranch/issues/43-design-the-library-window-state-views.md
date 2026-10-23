# 43: Design the Library window state views

**What to build:** Render Choosing a Library, Library unavailable, Document unavailable, and No document selected with `PBStateView` and the wording in `screens.md`, inside the real Library window. Replace the AppKit fallback's plain unavailable label.

**Blocked by:** 41: Restyle the Library window chrome.

**Status:** resolved

- [x] First launch shows Choosing a Library with "Open a Document…" and "Choose Library…".
- [x] An unavailable Library shows the sidebar caption and the state view with "Choose Another Library…" and "Reconnect".
- [x] A moved or deleted document shows Document unavailable while the tree keeps working.
- [x] No selection shows "Choose a document from the Library" and no top bar title.
- [x] Focused tests pass red-to-green, then both suites pass.

## Comments

Created 2026-10-22. Part of the switch to the brand guideline.

Resolved 2026-10-22.

- `LibraryWorkflow.availability` is `.notChosen`, `.available`, or `.unavailable(name:)`. The name comes from the saved bookmark without resolving it (`LibraryBookmarkCodec.libraryName(fromBookmark:)`, which defaults to the bookmark's name resource value), or from the Library that was just lost.
- `PBStateView` (`components.md` "State view") renders Choosing a Library, Library unavailable, and Document unavailable with the `screens.md` wording. Choose Library… and Choose Another Library… run the existing chooser, Open a Document… runs Open, and Reconnect runs the Library restore again. With no Library, the top bar keeps only the sidebar toggle, as in the guideline's mockups.
- The presentation renders every Library window state in Variant B. It returns to AppKit only when a state view or the empty reader would hide unsaved work (Ticket 18's rule, now also for a missing Library), for a Standalone snapshot, before any document session, and for a selection outside the Library. The AppKit fallback's caption now reads "<Library name> is unavailable." with "Choose Another Library…".
- Fixed while checking it in the app: the state view's paper background reached into the title bar area and covered the top bar, because a SwiftUI `Color` background ignores the safe area by default.

Judgment calls (no Edison):

- An empty Library shows the No document selected line with the "Library" label and no rows. The skill names no empty-Library state.
- Reconnect retries the saved Library and leaves the window as it is if the folder is still missing. The skill says only "Reconnect".
- Document unavailable keeps the document name in the top bar, so the window still says which document is gone.

Verified 2026-10-22:

- Red: `testLibraryWorkflowReportsWhetherALibraryWasChosenAndWhichIsUnavailable` and `testLibraryWindowShowsTheDesignedStateViews` failed to compile. The top-bar check then failed on the background bleed (state view bottom 898 against top bar 847, in flipped screen coordinates).
- Green: both passed, with the state titles, messages, sidebar caption, buttons, and actions checked. The guard tests now list these states as Variant B.
- `./verify-package.sh`: 76 packaged native tests passed. `npx playwright test`: the first run had one failure in `document-navigation.spec.ts:42`, a keyboard-driven test that also failed once in Ticket 39 before this work. It passed 12 of 12 alone, and the next two full runs passed 75 of 75. This ticket changed no web code.
- Packaged app, Library folder moved away: Library unavailable matched guideline page 13 (screenshot deleted).

Implementation commit: `950b5fa`.

Follow-up 2026-10-22, found in the visual pass: deleting the selected document showed No document selected instead of Document unavailable. The one-second Library refresh drops the missing document from the tree and clears the selection. The presentation now keeps Document unavailable while the open, unavailable document is inside the current Library, even with no selection. Red: the deleted-document case added to `testLibraryWindowShowsTheDesignedStateViews` failed; green after the change. `./verify-package.sh`: 76 packaged native tests passed. `npx playwright test`: 75 of 75 passed. Follow-up commit: `ec0d236`.
