# 44: Word the conflict alert from the guideline

**What to build:** Use `screens.md` "Conflict alert": "Keep My Edits" as the default button and "Reload from Disk" second with `hasDestructiveAction`, and the guideline's message. Keep the Ticket 37 overwrite warning and the Ticket 35 save prompt as they are.

**Blocked by:** 37: Warn before saving over a kept conflict.

**Status:** resolved

- [x] Title "Changes conflict in <document name>", the guideline message, and the two buttons in order.
- [x] Return keeps the edits.
- [x] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Created 2026-10-22. Part of the switch to the brand guideline.

Resolved 2026-10-22. `AppDelegate.presentConflict` now uses the `screens.md` message, "Keep My Edits" first and "Reload from Disk" second with `hasDestructiveAction`. The Library window and Standalone windows share it. As with the Ticket 37 overwrite warning, AppKit leaves Return unassigned when a destructive button is present and settles key equivalents when the sheet appears (measured: no button had Return), so Return is set on Keep My Edits after the sheet begins. The overwrite warning and the Ticket 35 save prompt are unchanged.

Verified 2026-10-22:

- Red: the conflict checks added to `testSwitchingAwayFromUnsavedEditsAsksToSaveCancelOrDiscard` failed on the message, the button titles, the Return key, and the destructive flag. The title already matched.
- Green: that test passed, and it still drives Keep My Edits through the Ticket 37 overwrite path.
- `./verify-package.sh`: 76 packaged native tests passed. `npx playwright test`: 75 of 75 passed.

Implementation commit: `5fd580d`.
