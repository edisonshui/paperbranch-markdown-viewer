# 39: Bring the design tokens into the app

**What to build:** Make the design skill's `tokens.css` the single source of every value. The Document view imports it directly, with no copy, in the dev server and in the packaged app. The SwiftUI chrome gets the Swift mirror from `components.md` "Theme" as one file in `PaperbranchBridgeCore`.

**Blocked by:** none.

**Status:** ready-for-agent

- [ ] The Document view loads `.claude/skills/paperbranch-design/tokens.css` itself, in Vite dev and in the packaged bundle, and the token values resolve on the page.
- [ ] `PaperbranchTheme.swift` in `PaperbranchBridgeCore` holds `PBColor`, `PBSize`, and `PBMotion` as `components.md` writes them.
- [ ] A test fails if a Swift color differs from its `tokens.css` value in either appearance.
- [ ] Focused tests pass red-to-green, then the Playwright suite and `editor-proof/native-host/verify-package.sh` pass.

## Comments

Created 2026-10-22 from the design skill's "Where the app disagrees today". Part of the switch to the brand guideline.
