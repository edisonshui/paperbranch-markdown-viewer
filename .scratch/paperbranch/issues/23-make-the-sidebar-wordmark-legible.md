# 23: Make the sidebar wordmark legible

**What to build:** Make the "Paperbranch" wordmark in the dark Library sidebar as legible as Variant B's "Folio" wordmark.

**Blocked by:** 13: Complete Variant B reader chrome in the guarded Library presentation.

**Status:** resolved

- [x] The wordmark reads clearly in the dark sidebar in every state where it appears.
- [x] `editor-proof/native-host/verify-package.sh` passes.

## Comments

Created 2026-09-30 from a user report. In Ticket 13's 1300x800 capture (`/tmp/pb13-paperbranch.png`) the wordmark read clearly in the SwiftUI presentation, so reproduce first. It may depend on window focus or on the AppKit fallback sidebar.

Resolved 2026-09-30. The wordmark now has Variant B's explicit sidebar ink `#e8e3d8`, bold weight, 16-point size, and -0.3 tracking. Before, "Paperbranch" was the only sidebar text without an explicit color, so it used SwiftUI's primary color for whatever appearance its window had.

Reproduction, 2026-09-30, packaged build of `20f3c30` with the system in Light mode and `/private/tmp/pb15-library`:

- The report did not reproduce in the running app. The wordmark read clearly in the SwiftUI presentation with the window active and inactive, and in the AppKit fallback (dirty document) active and inactive. The Library window sets `.darkAqua`, so the primary color is light there. Screenshots, not committed: `/tmp/pb23-active-s.png`, `/tmp/pb23-inactive-s.png`, `/tmp/pb23-dirty-s.png`, `/tmp/pb23-dirty-inactive-s.png`.
- It did reproduce in the presentation itself. Rendered in a window with an `.aqua` appearance, the wordmark drew near-black on the dark sidebar. That is the one path where the wordmark was illegible. Which state the original report came from is unconfirmed.

Verified 2026-09-30:

- Red: `cd editor-proof/native-host && PAPERBRANCH_PACKAGED_APP_PATH="$PWD/.build/Paperbranch.app" swift test --filter BridgeCoordinatorTests/testSidebarWordmarkStaysLightOnTheDarkSidebarUnderALightAppearance` failed with `XCTAssertGreaterThan failed: ("0.13249993081241845") is not greater than ("0.8")`. The test renders the presentation in an `.aqua` window, caches the hosting view into a bitmap, and checks the brightest pixel in the wordmark text's accessibility frame. With the window switched to `.darkAqua` and no fix, the same test passed, so it measures the text and not the background.
- Green: the same focused test passed, along with the title bar and expanded Library presentation tests (7 of 7).
- `cd editor-proof/native-host && ./verify-package.sh`: Xcode Release build succeeded and all 59 packaged native tests passed.
- `git diff --check`: passed.
- Packaged app with the fix: the wordmark reads clearly in the dark sidebar with the window active and inactive. Screenshots, not committed: `/tmp/pb23-after-active-c.png`, `/tmp/pb23-after-inactive-c.png`.

The AppKit fallback's "Paperbranch" label uses `labelColor` under the Library window's `.darkAqua` appearance and was left unchanged.

Implementation commit: `14b14b1`.
