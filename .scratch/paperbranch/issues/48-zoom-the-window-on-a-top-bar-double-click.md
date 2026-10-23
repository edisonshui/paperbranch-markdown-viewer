# 48: Zoom the window on a top bar double-click

**What to build:** A double-click on the top bar does what a double-click on the macOS title bar does, following System Settings ("Double-click a window's title bar to"): zoom by default, or minimize, or nothing.

**Blocked by:** none.

**Status:** resolved

- [x] A double-click on the top bar zooms the window when the setting is Zoom or unset.
- [x] Minimize and Do Nothing settings are followed.
- [x] A single click still drags the window.
- [x] Focused tests pass red-to-green, then both suites pass.

## Comments

Found 22 Oct 2026 by Edison: double-clicking the top bar did nothing. The top bar covers the transparent title bar, and `PBWindowDragView.mouseDown` sent every click, including a double-click, to `performDrag`.

AppKit registers its own value for `AppleActionOnDoubleClick` once it has windows, so the older `AppleMiniaturizeOnDoubleClick` key is never consulted. A fallback to it was dropped after it failed in the full suite.

Verified 22 Oct 2026:

- Red: `swift build --build-tests` failed because `PBTitleBarDoubleClickAction` did not exist.
- Green: `swift test --filter TitleBarDoubleClickTests` passed 2 of 2.
- `cd editor-proof/native-host && ./verify-package.sh`: 80 native tests passed. `cd editor-proof && npx playwright test`: 81 of 81 passed.
- Not yet checked by hand in the running app.

Confirmed by Edison 2026-10-23 in the running app: double-clicking the empty top bar zooms the window to fill the screen, and a second double-click returns it to its earlier size.
