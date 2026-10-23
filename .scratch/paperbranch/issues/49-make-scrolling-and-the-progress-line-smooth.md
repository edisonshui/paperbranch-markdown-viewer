# 49: Make scrolling and the progress line smooth

**What to build:** Make scrolling a long document smooth. All scroll work runs once per animation frame and only reads layout. The editor tells native code only when the current heading changes, and the Document view draws the reading progress line itself instead of re-rendering the native chrome to move it.

**Blocked by:** 42: Move the outline to a right panel in wide windows.

**Status:** resolved

- [x] Scroll work (navigation, current heading, reading anchor, progress line) runs in one `requestAnimationFrame` callback per frame, with no DOM writes except the progress line's own style.
- [x] The outline is computed and sent on load and on content change, never on scroll. On scroll, navigation goes to native only when the current heading changes.
- [x] The reading progress line is a fixed, 2 px `--accent` element at the top of the Document view, scaled with `transform: scaleX(progress)`, with `role="progressbar"` and `aria-valuenow`. The native line is removed from the Library and Standalone presentations, so it is drawn once.
- [x] The design skill says the line lives in the Document view and updates per animation frame, and the hex check passes.
- [x] Focused tests pass red-to-green, then both suites pass.

## Comments

Reported by Edison 2026-10-22: scrolling and the progress line feel laggy on his long UIUC apartment reports. Diagnosis by the coordinator from reading `editor-proof/src/harness.ts` (inferred): every scroll event ran `reportNavigation()`, whose `getOutline()` wrote `data-paperbranch-outline-id` on every heading before `getCurrentOutlineID()` read every heading's position (a write-then-read layout thrash), posted the whole outline to native, and made native re-render the whole SwiftUI chrome to move a 2 px line. `recordReadingAnchor()` also ran on every event.

Before, measured 2026-10-22 with `tests/constructs/scroll-work.spec.ts` (Chromium, 31 headings, 120 frames with two scroll events each): 240 navigation messages to native and 7,440 heading attribute writes.

Resolved 2026-10-22.

- `editor-proof/src/harness.ts`: a scroll event only schedules `runScrollFrame` with `requestAnimationFrame`, at most once per frame. The callback reads the progress, the current heading, and the reading anchor (Ticket 46), with binary searches over the cached headings and top-level blocks. It then writes only the progress line, and posts navigation only when the current heading changed. `refreshOutline()` rebuilds the outline and tags headings, writing an attribute only when it differs, on load and on content change only. `getOutline()` for the editor contract now reads without writing.
- The progress line is `#reading-progress` in `editor-proof/index.html`: fixed, 2 px, `var(--accent)`, `transform: scaleX(progress)`, `role="progressbar"` with `aria-valuenow` updated only when the whole percent changes. `PBReadingProgress` is removed from the Library and Standalone presentations, and from the components file. Navigation messages still carry `progress`, so the AppKit fallback's percentage keeps working.
- The design skill's `components.md` "Reading progress line" and `SKILL.md` motion bullet now say the line lives in the Document view and updates per animation frame. `check-hex.py` passes.

Before and after, measured with `tests/constructs/scroll-work.spec.ts` (Chromium, 31 headings, 120 frames, two scroll events each):

| | Before | After |
|---|---|---|
| Navigation messages to native | 240 | 13 (one per change of current heading) |
| Heading attribute writes | 7,440 | 0 |

Judgment call: at 1240 px and wider the line spans the Document view only, stopping at the 220 px outline panel. Before, the native line also ran above the panel. The Document view cannot draw over native chrome, and a full-width line would need the native re-render this ticket removes.

Verified 2026-10-22:

- Red: the scroll-work test failed (240 messages for 120 frames, 7,440 heading writes), the two progress-line tests failed (no progress bar in the Document view), and the two native tests changed to expect no native line failed.
- Green: all passed. `npx playwright test`: 84 of 84 passed. `./verify-package.sh`: 80 packaged native tests passed, and the bundled `index.html` contains `#reading-progress`.
- Not measured: frame times in WebKit inside the app. Edison is using the Mac, so whether scrolling now feels smooth on a long report needs his check by eye.

Implementation commit: `a7e71ac`.

Confirmed by Edison 2026-10-23 in the running app, light and dark: medium documents scroll smoothly and the progress line keeps up. `project-ideas.md` still lagged, which Ticket 50 fixed.
