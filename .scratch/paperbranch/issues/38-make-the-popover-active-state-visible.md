# 38: Make the popover's active state visible

**What to build:** Give an active formatting-popover button a fill and glyph color that pass the guideline's contrast rule.

**Blocked by:** 36: Show a formatting popover for selected text.

**Status:** resolved

- [x] An active button fills with the `--selection` token's dark value `#24385E` and draws its glyph in `--accent-text`'s dark value `#7EA7F5`.
- [x] Inactive buttons are unchanged.
- [x] The token comment in `editor-proof/index.html` names `--selection` and `--accent-text`.
- [x] Focused test passes red-to-green, then the Playwright suite passes.

## Comments

Created 2026-10-22 from Ticket 36. The active fill `#2C2C30` on the container `#26262A` measured 1.08:1, under the guideline's 3:1 for a meaningful shape. New spec from Edison, relayed by the coordinator: glyph `#7EA7F5` on fill `#24385E` measures 4.85:1.

Resolved 2026-10-22. `#formatting-popover button[aria-pressed="true"]` now uses background `#24385E` and color `#7EA7F5`. The token comment names `--selection` and `--accent-text` in place of `--row-selected`.

Verified 2026-10-22:

- Red: `npx playwright test tests/constructs/formatting-popover.spec.ts -g "active button fills"` failed on the old `#2C2C30` fill and `#E6E6E8` glyph.
- Green: that test passed. The popover spec passed 55 of 55 with `--repeat-each=5`. `npx playwright test`: 69 of 69 passed. `./verify-package.sh`: 70 packaged native tests passed.
- Contrast, measured with the brand skill's `contrast.py`: `#7EA7F5` on `#24385E` is 4.85:1.

Implementation commit: `7d32f2e`.
