# 21: Show the document meta line

**What to build:** Show Variant B's meta line above the document with the word count and read time for the selected Markdown document.

**Blocked by:** 13: Complete Variant B reader chrome in the guarded Library presentation.

**Status:** ready-for-agent

- [ ] The reader shows the word count and read time above the document.
- [ ] Both values update after an edit and after an external reload.
- [ ] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Created 2026-09-30 from Ticket 13's visual check. Variant B shows "149 words · 1 min read · Rendered locally". Which items to keep, and whether the count comes from the editor or the native layer, is open.
