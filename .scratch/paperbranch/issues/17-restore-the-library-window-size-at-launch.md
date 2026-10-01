# 17: Restore the Library window size at launch

**What to build:** Open the Library window at the size and position it had when Paperbranch last closed. With no saved frame, open it at the intended 960x720 content size instead of the split view controller's small fitting size.

**Blocked by:** 15: Preserve the Library window size across presentation swaps.

**Status:** resolved

- [x] With no saved frame, the Library window opens at a 960x720 content size.
- [x] With a saved frame, the Library window opens at that frame.
- [x] Moving or resizing the Library window saves its frame for the next launch.
- [x] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Created 2026-09-30 from Ticket 15. The packaged Library window opened at about 340x216 because assigning `splitController` as the content view controller resized the 960x720 window to the controller's fitting size.

Verified 2026-09-30:

- Red: `cd editor-proof/native-host && swift test --filter 'testLibraryWindowOpensAtDefaultContentSizeWithoutSavedFrame|testLibraryWindowSavesItsFrameAndRestoresItAtNextLaunch'` failed. With no saved frame the content was 500x532, no frame was saved, and the next window opened at 500x584 instead of the chosen 1100x700 frame.
- Green: both tests passed after `makeLibraryWindow()` set a 960x720 content size after assigning the split view controller, then set and applied the `PaperbranchLibraryWindow` frame autosave name.
- `cd editor-proof/native-host && ./verify-package.sh`: Xcode Release build succeeded and all 51 packaged native tests passed.
- `git diff --check`: passed.
- Packaged app: with no saved frame, the window opened at 960x772 (960x720 content plus title bar and toolbar). After moving it to (150, 90), resizing to 1200x780, and quitting, the next launch opened at (150, 90) and 1200x780.

Implementation commit: `e7dbf62`.
