# 31: Let the whole reader scroll the Document view

**What to build:** Make the Document view fill the Variant B reader column so scrolling anywhere over the reader scrolls the document and the scroll bar sits at the window's edge.

**Blocked by:** 13: Complete Variant B reader chrome in the guarded Library presentation.

**Status:** ready-for-agent

- [ ] The Document view spans the reader column's full width, and the article stays a centered 710-point column.
- [ ] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Found 2026-10-22 in the UX audit. The reader showed a scroll bar track in the middle of the window, at the right edge of the 710-point canvas. The SwiftUI canvas clips the `WKWebView` to 710 points, while the editor's own CSS (`#document { max-width: 710px; margin: auto }`) already centers the article. So the margins on either side of the article are outside the web view and do not scroll it (inferred from the measured 710-point web view frame; synthetic scroll events could not confirm it).
