# 13: Complete Variant B reader chrome in the guarded Library presentation

**What to build:** Make the already-guarded clean, available, selected Markdown document in a fully expanded Library visually follow Variant B's reader layout: a reader top bar, centered constrained reading canvas, and footer. Keep the existing Library window, injected WebKit Document view, AppKit workflows, and guard policy unchanged.

**Blocked by:** 12: Render Variant B's clean expanded Library reading state.

**Status:** claimed

- [ ] The eligible SwiftUI Library presentation visibly contains Variant B reader chrome with the selected Markdown document name.
- [ ] The injected WebKit Document view sits in the centered, constrained reader canvas with a reader footer.
- [ ] The existing sidebar, document selection, outline selection, progress, and all ineligible AppKit states remain unchanged.
- [ ] Focused tests pass red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Created 2026-09-21 from Ticket 10 visual verification. The packaged clean expanded Library state had the dark palette and sidebar but lacked Variant B's reader top bar, constrained document canvas, and footer, so the visual acceptance criterion cannot yet pass.
