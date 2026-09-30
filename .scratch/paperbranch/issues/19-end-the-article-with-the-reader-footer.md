# 19: End the article with the reader footer

**What to build:** Place the reader footer after the last block of the Markdown document, as in Variant B, instead of pinning it to the bottom of the Library window.

**Blocked by:** 13: Complete Variant B reader chrome in the guarded Library presentation.

**Status:** ready-for-agent

- [ ] The footer appears after the document's last block and scrolls with the document.
- [ ] A short document shows the footer directly after its content, not at the window bottom.
- [ ] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Created 2026-09-30 from Ticket 13's visual check. The footer is SwiftUI chrome outside the injected `WKWebView`, so ending the article may need the footer inside the web Document view or a scroll-linked layout.
