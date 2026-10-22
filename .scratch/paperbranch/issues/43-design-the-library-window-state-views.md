# 43: Design the Library window state views

**What to build:** Render Choosing a Library, Library unavailable, Document unavailable, and No document selected with `PBStateView` and the wording in `screens.md`, inside the real Library window. Replace the AppKit fallback's plain unavailable label.

**Blocked by:** 41: Restyle the Library window chrome.

**Status:** ready-for-agent

- [ ] First launch shows Choosing a Library with "Open a Document…" and "Choose Library…".
- [ ] An unavailable Library shows the sidebar caption and the state view with "Choose Another Library…" and "Reconnect".
- [ ] A moved or deleted document shows Document unavailable while the tree keeps working.
- [ ] No selection shows "Choose a document from the Library" and no top bar title.
- [ ] Focused tests pass red-to-green, then both suites pass.

## Comments

Created 2026-10-22. Part of the switch to the brand guideline.
