# 32: Make every Library row clickable across its width

**What to build:** Make each Library document row in the Variant B sidebar respond to a click anywhere on the row, as folder rows already do.

**Blocked by:** 12: Render the Variant B Library reading state.

**Status:** resolved

- [x] A document row's clickable frame spans the sidebar's row width, matching folder rows.
- [x] The selected row's highlight spans the same width.
- [x] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Found 2026-10-22 in the UX audit. Accessibility frames showed document rows 63 to 99 points wide (the text only) while folder rows were 216 to 248 points wide. Document rows lack the `.contentShape(Rectangle())` folder rows have, and they sit in folder `VStack`s that do not stretch.

Resolved 2026-10-22. Document row labels now have `.contentShape(Rectangle())`, as folder rows do. The selected row's highlight already spanned the row, because its background sits on the full-width frame.

Verified 2026-10-22:

- Red: `swift test --filter BridgeCoordinatorTests/testLibraryDocumentRowsAreClickableAcrossTheRowLikeFolderRows` failed: an unselected top-level document row was 32 points wide against its sibling folder row's 248.
- Green: that test passed. `./verify-package.sh`: 67 packaged native tests passed. `npx playwright test`: 57 of 57 passed.
- Packaged app: Draft 3.md's row reported 216 points wide (63 before), and a real click 130 points right of its text selected it.

Implementation commit: `d6da1e7`.
