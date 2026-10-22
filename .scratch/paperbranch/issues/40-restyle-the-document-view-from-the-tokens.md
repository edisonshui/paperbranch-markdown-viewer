# 40: Restyle the Document view from the tokens

**What to build:** Replace the Document view's warm dark stylesheet with `components.md` "Document view" and "Formatting popover", built on `tokens.css`. Remove the forced dark color scheme so the Document view follows the macOS appearance.

**Blocked by:** 39: Bring the design tokens into the app.

**Status:** resolved

- [x] The page follows the system appearance: `--paper` and `--ink` in light and in dark.
- [x] The column is 680 px, body text is 19 px New York at line height 1.7, the title is 40 px and left-aligned, and the meta line is a left-aligned uppercase label above it.
- [x] Links and inline code use `--accent-text`, block quotes a 2 px `--border` rule, and broken images `--danger`.
- [x] The formatting popover uses tokens only.
- [x] Focused tests pass red-to-green, then both suites pass.

## Comments

Created 2026-10-22. Part of the switch to the brand guideline.

Resolved 2026-10-22. `editor-proof/index.html`'s stylesheet is now `components.md` "Document view" and "Formatting popover", all `var(--token)`. The page's own `color-scheme: dark` is gone, so `tokens.css`'s `color-scheme: light dark` makes it follow the system. The popover's link and code buttons draw the skill's `icons/link.svg` and `icons/code.svg`, imported with `?raw`.

Judgment calls (no Edison):

- The meta line joins its two parts with " · ", as in the guideline mockups ("1,240 WORDS · 6 MIN READ"). It is CSS generated content, so the text the tests and the bridge read is unchanged.
- The popover icons render at 16 px inside the 28 by 26 px buttons. The skill draws them on a 24 px grid but gives no display size.
- The popover keeps `top: 0; left: 0; z-index: 10`, which the component snippet omits, so floating-ui's first placement starts from a known corner and the popover stays above the page.

Verified 2026-10-22:

- Red: `document-theme.spec.ts` failed (light, dark, and layout), and the light case of the popover active-state test failed.
- Green: they passed. They check paper, ink, link, inline code, and block quote colors in light and dark, the 680 px column, 19 px body at line height 1.7 in New York, the 40 px left-aligned title, the 27 px h2, the uppercase meta line above the title, and the popover's surface and active colors in both appearances.
- `npx playwright test`: 74 of 74 passed. `./verify-package.sh`: 72 packaged native tests passed. `index.html` has no `e88e68` or `22231f` left.

Implementation commit: `5a30d9f`.
