# 33: Format the meta line word count

**What to build:** Show the meta line's word count with a thousands separator, as the Open now card does.

**Blocked by:** 22: Match Variant B's sidebar navigation.

**Status:** resolved

- [x] A 3,039-word document shows "3,039 words" in both the meta line and the Open now card.
- [x] Focused test passes red-to-green, then the Playwright suite passes.

## Comments

Found 2026-10-22 in the UX audit. The meta line read "3039 words" while the Open now card read "3,039 words" for the same document.

Resolved 2026-10-22. The meta line formats its count with `toLocaleString()`, which groups digits by the system locale as the Open now card's Swift `formatted()` does. The count sent over the bridge stays a plain number.

Verified 2026-10-22:

- Red: `npx playwright test tests/constructs/reader-chrome.spec.ts -g "groups thousands"` failed: the meta line read "3039 words".
- Green: that test passed. `npx playwright test`: 58 of 58 passed (three consecutive runs). `./verify-package.sh`: 67 packaged native tests passed.
- Seen while verifying, not caused by this change: under load, three typing-based Playwright tests fail now and then (`images.spec.ts:36`, `native-bridge.spec.ts:112`, `escaped-links.spec.ts:31`). `--repeat-each=6` gave 345 passed and 3 failed.

Implementation commit: `3d8c691`.
