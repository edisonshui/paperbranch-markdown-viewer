# 40: Restyle the Document view from the tokens

**What to build:** Replace the Document view's warm dark stylesheet with `components.md` "Document view" and "Formatting popover", built on `tokens.css`. Remove the forced dark color scheme so the Document view follows the macOS appearance.

**Blocked by:** 39: Bring the design tokens into the app.

**Status:** ready-for-agent

- [ ] The page follows the system appearance: `--paper` and `--ink` in light and in dark.
- [ ] The column is 680 px, body text is 19 px New York at line height 1.7, the title is 40 px and left-aligned, and the meta line is a left-aligned uppercase label above it.
- [ ] Links and inline code use `--accent-text`, block quotes a 2 px `--border` rule, and broken images `--danger`.
- [ ] The formatting popover uses tokens only.
- [ ] Focused tests pass red-to-green, then both suites pass.

## Comments

Created 2026-10-22. Part of the switch to the brand guideline.
