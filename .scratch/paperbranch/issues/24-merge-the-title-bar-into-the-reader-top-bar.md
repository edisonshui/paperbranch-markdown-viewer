# 24: Merge the title bar into the reader top bar

**What to build:** Remove the separate macOS title bar and toolbar above the reader, so the window controls sit in the reader top bar as in Variant B and the document name appears once.

**Blocked by:** 13: Complete Variant B reader chrome in the guarded Library presentation.

**Status:** ready-for-agent

- [ ] In the Variant B presentation, the window controls sit in the reader top bar and there is no separate title bar row.
- [ ] The document name appears once.
- [ ] The sidebar toggle and Choose Library remain reachable, and AppKit fallback states still have their controls.
- [ ] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Created 2026-09-30 from Ticket 13's visual check. The packaged window shows "Reading.md" in both the title bar and the reader top bar, with the toolbar's sidebar and Choose Library buttons in the title bar row.
