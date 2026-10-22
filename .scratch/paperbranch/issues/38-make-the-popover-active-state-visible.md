# 38: Make the popover's active state visible

**What to build:** Give an active formatting-popover button a fill and glyph color that pass the guideline's contrast rule.

**Blocked by:** 36: Show a formatting popover for selected text.

**Status:** ready-for-agent

- [ ] An active button fills with the `--selection` token's dark value `#24385E` and draws its glyph in `--accent-text`'s dark value `#7EA7F5`.
- [ ] Inactive buttons are unchanged.
- [ ] The token comment in `editor-proof/index.html` names `--selection` and `--accent-text`.
- [ ] Focused test passes red-to-green, then the Playwright suite passes.

## Comments

Created 2026-10-22 from Ticket 36. The active fill `#2C2C30` on the container `#26262A` measured 1.08:1, under the guideline's 3:1 for a meaningful shape. New spec from Edison, relayed by the coordinator: glyph `#7EA7F5` on fill `#24385E` measures 4.85:1.
