# 36: Show a formatting popover for selected text

**What to build:** When text is selected in an editable document, show a small popover centered 6 px above the selection with five buttons: link, bold, italic, strikethrough, inline code. Each button toggles its mark and shows when the mark already covers the selection.

**Blocked by:** 30: Stay in Variant B while editing, switching, and toggling the sidebar.

**Status:** resolved

- [x] A non-empty selection in an editable document shows the popover, centered 6 px above the selection, with the five buttons in order.
- [x] Bold, italic, strikethrough, and inline code toggle their marks, show an active state when the mark covers the selection, and round-trip through the saved Markdown.
- [x] The link button removes an existing link from the selection, or asks for a URL and adds a link. There is no link editor UI.
- [x] The popover hides when the selection collapses, on Escape, when the editor loses focus, and never shows for a blocked document.
- [x] The popover never takes focus from the editor, and Command-S, undo, and redo keep working.
- [x] Showing the popover moves, resizes, and reflows nothing else on screen.
- [x] It fades in and out over 120 ms, and does not animate under reduced motion.
- [x] Focused tests pass red-to-green, then the Playwright suite and `editor-proof/native-host/verify-package.sh` pass.

## Comments

Created 2026-10-22. Edison approved the popover on 22 Oct 2026. The look comes from the brand guideline, page 9 ("Formatting popover") and the editing mockup on page 11, in `.scratch/paperbranch-brand/paperbranch-brand-guideline.pdf`. The app is dark-only, so the popover uses the guideline's dark values, hardcoded like the rest of `editor-proof/index.html`:

- Container: background `#26262A`, 1 px border `#3A3A40`, radius 10 px, padding 3 px, gap 2 px, shadow `0 4px 16px rgba(0,0,0,0.45)`.
- Buttons: 28 by 26 px, radius 4 px, transparent, text `#E6E6E8`, 13 px system sans. B is bold, I is italic serif, S is struck through, and link and code are stroked inline SVG icons.
- Active button: background `#2C2C30`.

Color change 2026-10-22: Edison replaced the guideline's warm palette with cool grays and blue. The values above are the new dark values. The first brief's warm values (`#2B2C27`, `#3F403A`, `#E8E3D8`, `#2E2B26`) were never committed.

Mechanism: Milkdown 7.22.1's own `@milkdown/plugin-tooltip` (`tooltipFactory` and `TooltipProvider`), which positions with floating-ui and already hides for an empty selection, an unfocused editor, and a read-only view.

Link approach: if any of the selection is already a link, the button removes the link. Otherwise it asks for a URL with `window.prompt` and adds a link when the answer is not empty. WKWebView returns no answer to `window.prompt` unless its UI delegate implements the text input panel, so the native host adds one that shows a sheet with a text field.

Resolved 2026-10-22.

- `editor-proof/src/formatting-popover.ts` builds the popover on `tooltipFactory` and `TooltipProvider` (offset 6, placement top, appended to `body` and absolutely positioned). Its show rule is the provider's own plus Escape: Escape hides it until the selection changes, and the key still reaches the editor. Blur hides it. Buttons cancel `mousedown`, so the editor keeps focus and its selection. Active state is `aria-pressed`, true when every selected text node has the mark.
- Command-S is untouched: the native key monitor from Ticket 30 takes it before the Document view. Undo and redo go through Milkdown's history, so popover changes are ordinary transactions.
- Native: `BridgeCoordinator` is now the web view's `WKUIDelegate` and answers `window.prompt` with a sheet ("Add Link", "Cancel") holding one text field.
- Contrast, measured with the brand skill's `contrast.py`: the active button background `#2C2C30` on the container `#26262A` is 1.08:1, under the guideline's 3:1 for a meaningful shape. Built as specified; needs Edison.

Verified 2026-10-22:

- Red: `npx playwright test tests/constructs/formatting-popover.spec.ts` failed all 10 tests before the module existed. `swift test --filter BridgeCoordinatorTests/testLinkPromptShowsASheetAndReturnsTheTypedURL` failed: no sheet.
- Green: the 10 popover tests passed 100 of 100 with `--repeat-each=10`. Early runs failed now and then because ProseMirror writes its own selection back to the DOM just after focus. That was a race in the test helper, not the popover, and the helper now waits two frames after focus. The prompt test passed.
- Full suites: `npx playwright test` passed 68 of 68 (twice, and again after the color change). `./verify-package.sh` passed 68 packaged native tests.
- Look: a Chromium screenshot of the harness matched the guideline's page 9 popover (five buttons, B active) and was deleted. Not checked in the packaged app, because the audit does not send keystrokes while Edison is using the Mac.

Implementation commit: `8d02de8`.
