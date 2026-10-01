# 16: Use a dark Library window

**What to build:** Give the Library window a dark appearance in every presentation, so the AppKit fallback states (no selected document, collapsed sidebar, dirty, conflict, unavailable) match Variant B's dark reader instead of following the system's light appearance. Standalone windows are unchanged.

**Blocked by:** 14: Return to AppKit when toggling the Library sidebar from the reader.

**Status:** resolved

- [x] The Library window uses the dark Aqua appearance.
- [x] Standalone windows keep the system appearance.
- [x] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Created 2026-09-30. After Choose Library, the selected document is cleared, so the window falls back to the AppKit presentation, whose sidebar followed the light system appearance while the reader is dark.

Verified 2026-09-30:

- Red: `cd editor-proof/native-host && swift test --filter testLibraryWindowIsDarkWhileStandaloneWindowsFollowTheSystem` failed because the Library window's appearance was `nil`.
- Green: the same test passed after `makeLibraryWindow()` set `NSAppearance(named: .darkAqua)`. The Standalone window's appearance stays `nil`.
- `cd editor-proof/native-host && ./verify-package.sh`: Xcode Release build succeeded and all 51 packaged native tests passed.
- `git diff --check`: passed.
- Packaged app: after Choose Library cleared the selected document, the AppKit fallback's title bar, toolbar, sidebar, and outline panel were dark.

Implementation commit: `be5b137`. `makeLibraryWindow()` was extracted in `e7dbf62` (Ticket 17) so the window setup is testable.
