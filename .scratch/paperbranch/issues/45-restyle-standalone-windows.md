# 45: Restyle Standalone windows

**What to build:** Give each Standalone window the guideline's chrome: a top bar holding the window buttons and the document name with its status, the reading progress line, and the Document view, with no sidebar toggle and no Open button.

**Blocked by:** 41: Restyle the Library window chrome.

**Status:** ready-for-agent

- [ ] The top bar names the document and shows "· Edited" or "· Changed on disk".
- [ ] No Library parts: no sidebar, no toggle, no Open button, no Open now card.
- [ ] The progress line follows the reading position.
- [ ] Close, save, and conflict behavior is unchanged.
- [ ] Focused test passes red-to-green, then both suites pass.

## Comments

Created 2026-10-22. Part of the switch to the brand guideline.
