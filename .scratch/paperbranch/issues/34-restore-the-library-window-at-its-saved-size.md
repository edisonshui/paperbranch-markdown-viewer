# 34: Restore the Library window at its saved size

**What to build:** Open the Library window at the exact frame it had when Paperbranch quit, instead of growing it at each launch.

**Blocked by:** 17: Restore the Library window size at launch.

**Status:** resolved

- [x] Quitting and relaunching keeps the Library window's frame, in both the Variant B and the AppKit presentation.
- [x] The cause is confirmed and recorded in Comments.
- [x] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Found 2026-10-22 in the UX audit. The saved frame was `60 66 1300 883` and the window opened at 1300x935, taller than the screen. Tickets 25 and 26 recorded the same growth: 800 to 852, then 883. Each launch adds 52 points, the height of the title bar plus toolbar (inferred).

Resolved 2026-10-22.

- Cause (measured in a throwaway test): with a visible toolbar, AppKit's frame autosave saves the frame minus the toolbar's height and adds it back when restoring. With the toolbar hidden it saves and restores the true frame. Variant B hides the toolbar, so frames were saved there and restored at launch with the toolbar visible, adding 52 points each time. A frame saved as 760 tall restored as 812.
- Fix: `makeLibraryWindow()` no longer uses frame autosave. AppDelegate saves the window's full frame under `Paperbranch.libraryWindowFrame` on every move and resize (not in full screen) and restores it at launch when it is on a screen. The old autosave entry is ignored, so the first launch after this change opens at the default size once.

Verified 2026-10-22:

- Red: `swift test --filter BridgeCoordinatorTests/testLibraryWindowRestoresTheFrameItHadInEitherPresentation` failed: a 1180x760 frame saved in Variant B restored as 1180x812.
- Green: that test and the three other `testLibraryWindow` tests passed. `./verify-package.sh`: 66 packaged native tests passed. `npx playwright test`: 57 of 57 passed.
- Packaged app: resized to 1200x760, then quit and relaunched twice. Both relaunches opened at 1200x760.

Implementation commit: `0466e83`.
