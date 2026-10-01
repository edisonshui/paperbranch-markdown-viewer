# 22: Match Variant B's sidebar navigation

**What to build:** Decide how Variant B's sidebar sections (All documents, Favorites, Recently opened, Open now) map onto Paperbranch's nested Library tree, then render the chosen sections.

**Blocked by:** 13: Complete Variant B reader chrome in the guarded Library presentation.

**Status:** ready-for-agent

- [ ] The sidebar sections follow the decision recorded in this ticket.
- [ ] The nested Library hierarchy stays visible and navigable, as the specification requires.
- [ ] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Created 2026-09-30 from Ticket 13's visual check. The specification requires the sidebar to mirror the Library's folders, and Variant B shows flat navigation items instead, so this needs a design decision before implementation.
