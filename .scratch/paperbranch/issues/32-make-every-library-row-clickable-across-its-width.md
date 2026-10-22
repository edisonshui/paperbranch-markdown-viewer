# 32: Make every Library row clickable across its width

**What to build:** Make each Library document row in the Variant B sidebar respond to a click anywhere on the row, as folder rows already do.

**Blocked by:** 12: Render the Variant B Library reading state.

**Status:** ready-for-agent

- [ ] A document row's clickable frame spans the sidebar's row width, matching folder rows.
- [ ] The selected row's highlight spans the same width.
- [ ] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Found 2026-10-22 in the UX audit. Accessibility frames showed document rows 63 to 99 points wide (the text only) while folder rows were 216 to 248 points wide. Document rows lack the `.contentShape(Rectangle())` folder rows have, and they sit in folder `VStack`s that do not stretch.
