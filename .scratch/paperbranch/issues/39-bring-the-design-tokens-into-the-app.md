# 39: Bring the design tokens into the app

**What to build:** Make the design skill's `tokens.css` the single source of every value. The Document view imports it directly, with no copy, in the dev server and in the packaged app. The SwiftUI chrome gets the Swift mirror from `components.md` "Theme" as one file in `PaperbranchBridgeCore`.

**Blocked by:** none.

**Status:** resolved

- [x] The Document view loads `.claude/skills/paperbranch-design/tokens.css` itself, in Vite dev and in the packaged bundle, and the token values resolve on the page.
- [x] `PaperbranchTheme.swift` in `PaperbranchBridgeCore` holds `PBColor`, `PBSize`, and `PBMotion` as `components.md` writes them.
- [x] A test fails if a Swift color differs from its `tokens.css` value in either appearance.
- [x] Focused tests pass red-to-green, then the Playwright suite and `editor-proof/native-host/verify-package.sh` pass.

## Comments

Created 2026-10-22 from the design skill's "Where the app disagrees today". Part of the switch to the brand guideline.

Resolved 2026-10-22.

- Import route: `editor-proof/src/harness.ts` imports `../../.claude/skills/paperbranch-design/tokens.css` as a module. Vite serves it in dev and bundles it into the packaged editor's CSS asset at build, so the app reads the skill's file with no copy. A `<link>` in `index.html` would point outside the bundle in the packaged app, so it was not used.
- `PaperbranchTheme.swift` holds `PBColor`, `PBSize`, and `PBMotion` from `components.md`, made `public` for the host target, plus `PBColor.tokens`, a list of each color under its CSS name for the parity test.

Verified 2026-10-22:

- Red: `design-tokens.spec.ts` failed (no token values on the page). `PaperbranchThemeTests` failed to compile (no `PBColor`).
- Green: both passed. `PaperbranchThemeTests` parses every `light-dark()` pair in `tokens.css` and checks all 17 Swift colors in light and dark, plus eight sizes.
- Packaged: the bundled `assets/index-*.css` contains `--measure`. `./verify-package.sh`: 72 packaged native tests passed. `npx playwright test`: 70 of 70 passed. One earlier run had a single `document-navigation.spec.ts:42` failure, which passed 32 of 32 alone, like the known typing flakes.

Implementation commit: `716bbfd`.
