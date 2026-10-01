# 23: Make the sidebar wordmark legible

**What to build:** Make the "Paperbranch" wordmark in the dark Library sidebar as legible as Variant B's "Folio" wordmark.

**Blocked by:** 13: Complete Variant B reader chrome in the guarded Library presentation.

**Status:** ready-for-agent

- [ ] The wordmark reads clearly in the dark sidebar in every state where it appears.
- [ ] `editor-proof/native-host/verify-package.sh` passes.

## Comments

Created 2026-09-30 from a user report. In Ticket 13's 1300x800 capture (`/tmp/pb13-paperbranch.png`) the wordmark read clearly in the SwiftUI presentation, so reproduce first. It may depend on window focus or on the AppKit fallback sidebar.
