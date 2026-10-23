# 50: Stop rebuilding the hidden sidebar outline on scroll

**What to build:** Scrolling past a heading must not rebuild the AppKit Library sidebar's outline. That sidebar does not mark the current heading, so it rebuilds its buttons only when a heading's id, text, or level changes, and otherwise updates only its progress percentage.

**Blocked by:** 49: Make scrolling and the progress line smooth.

**Status:** resolved

- [x] `LibrarySidebarViewController.showDocumentNavigation` keeps its outline buttons when only `isCurrent` changes, and still rebuilds when a heading changes.
- [x] A focused native test fails before the fix and passes after, then both suites pass.

## Comments

Reported by Edison 2026-10-23 after Ticket 49: medium documents scroll smoothly, but `project-ideas.md` (22 KB, 35 headings) still lags a bit.

Diagnosis, measured 2026-10-23 on throwaway copies of the sample Library:

- Web side (Chromium, full scroll at 30 px per frame): no frame over 17.8 ms in either document. `project-ideas.md` sent 33 navigation messages and `ranking.md` (9 headings) sent 8.
- Native side (release build, 33 updates each): the SwiftUI Library window render took a median 2.9 ms with 35 headings. `AppDelegate`'s navigation handler also calls `LibrarySidebarViewController.showDocumentNavigation`, which removed and recreated every outline button on each update: a median 32.9 ms with 35 headings and 12.6 ms with 12. That AppKit sidebar is off screen while the SwiftUI window shows, so each heading crossing stalled the main thread for about two 60 Hz frames for nothing on screen. The cost grows with the heading count, which matches long documents lagging and medium ones not.

Resolved 2026-10-23. `showDocumentNavigation` updates the progress label first, then compares each entry's id, text, and level with the buttons on screen and returns when they match. After, measured the same way in a release build: a median 1.75 ms, a maximum of 1.99 ms.

Verified 2026-10-23:

- Red: `testLibrarySidebarOutlineIsNotRebuiltWhenOnlyTheCurrentHeadingChanges` failed with "A current-heading change rebuilt the outline buttons".
- Green: that test passed. `./verify-package.sh`: 81 packaged native tests passed. `npx playwright test`: 84 of 84 passed.
- Not measured: frame times in the running app. Whether `project-ideas.md` now scrolls smoothly needs Edison's check by eye.
