# 47: Read dollar prices as text, not math

**What to build:** Stop blocking documents that contain prices. Inline math detection follows Pandoc's `tex_math_dollars` rule instead of `remark-math`'s pairing of any two dollar signs.

**Blocked by:** none.

**Status:** resolved

- [x] "$650 to $1,000", "$20,000 and $30,000", and tables of prices are admitted.
- [x] Real inline math (`$x$`, `$E = mc^2$`) and display math (`$$`) are still blocked.
- [x] A `$` inside an inline code span or escaped as `\$` never counts.
- [x] Focused tests pass red-to-green, then both suites pass.

## Comments

Found 22 Oct 2026 when Edison opened his UIUC apartment ranking and reports: each was blocked with "Formatted editing is unavailable for this document (math)". `remark-math` paired currency signs such as "$650 to $" into inline math. The old test called this a known trade-off and said Pandoc had the same problem. The Pandoc manual says otherwise: "$20,000 and $30,000 won't parse as math."

Edison chose the Pandoc rule on 22 Oct 2026. ADR 0004 carries a dated amendment.

`src/admission.ts` now takes display math from `remark-math`, and scans each paragraph, heading, and table cell for inline math with the Pandoc rule, with inline code blanked out first. A post-filter on `remark-math`'s inline nodes was not enough: in "$5, and $E = mc^2$" it pairs the first two signs and loses the real math.

Verified 22 Oct 2026:

- Red: `npx playwright test tests/constructs/admission.spec.ts` failed the three currency tests.
- Green: 16 of 16 admission tests passed. Edison's `ranking.md`, both reports, and `project-ideas.md` classify as admitted, and `fixtures/unsupported-math.md` stays blocked.
- `cd editor-proof && npx playwright test`: 81 of 81 passed. `cd editor-proof/native-host && ./verify-package.sh`: 80 native tests passed.

Confirmed by Edison 2026-10-23 in the running app: `ranking.md` and both UIUC apartment reports open as documents instead of the blocked message.
