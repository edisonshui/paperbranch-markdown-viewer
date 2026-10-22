# 44: Word the conflict alert from the guideline

**What to build:** Use `screens.md` "Conflict alert": "Keep My Edits" as the default button and "Reload from Disk" second with `hasDestructiveAction`, and the guideline's message. Keep the Ticket 37 overwrite warning and the Ticket 35 save prompt as they are.

**Blocked by:** 37: Warn before saving over a kept conflict.

**Status:** ready-for-agent

- [ ] Title "Changes conflict in <document name>", the guideline message, and the two buttons in order.
- [ ] Return keeps the edits.
- [ ] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Created 2026-10-22. Part of the switch to the brand guideline.
