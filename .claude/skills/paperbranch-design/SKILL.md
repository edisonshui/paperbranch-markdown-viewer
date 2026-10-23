---
name: paperbranch-design
description: Paperbranch brand rules (the macOS Markdown app with the Library window, Library sidebar, Document view, and Standalone windows). Use when designing, building, restyling, or reviewing any Paperbranch screen or UI part, or when picking a Paperbranch color, font, or size.
---

# Paperbranch design

Paperbranch is a quiet paper page for the Markdown you already keep in folders. The app follows the macOS appearance: white and cool gray in light mode, near-black in dark mode, with one blue accent that marks where you are. The source is version 1 of the "Paperbranch brand guideline", dated 22 Oct 2026. It is built from Mobbin screens Edison picked: hilos (sidebar), Substack (reading), Superlist (editing), Plane (outline), Grok (choosing a Library), Coinbase (unavailable), Lindy (alert wording), and Microsoft Copilot (sidebar collapsed). Edison confirmed every choice in it on 22 Oct 2026. Use the app's words from `CONTEXT.md`: Library, Markdown document, Standalone document, Document view, Library window, Standalone window.

Every value lives in [tokens.css](tokens.css). The Document view links it and uses `var(--token)`. The SwiftUI chrome uses the Swift mirror in [components.md](components.md#theme), which carries the same names.

## Steps

1. **Find the screen** in [screens.md](screens.md). Read its layout and its one hard rule.
2. **Build from the parts** in [components.md](components.md). Every color, font, size, space, radius, and duration is a token: `var(--token)` in the Document view, `PBColor`, `PBSize`, and `PBMotion` in Swift.
3. **Use the app's words.** Labels, titles, and messages follow "Voice" below, and state names match it word for word.
4. **Design every state the screen has**: clean, Edited, Changed on disk, empty, and unavailable, whichever apply.
5. **Check both appearances.** Build the screen in light and dark. Run `contrast.py` from the brand-guideline skill on any color pair this skill does not already list.
6. **Run the checklist** at the bottom. The screen is done when every line passes.

## Principles

In priority order. When two rules conflict, the higher one wins.

1. **The document comes first.** Chrome, labels, and color step back whenever they compete with the text. When in doubt, remove the element.
2. **Nothing jumps.** Switching documents, collapsing the sidebar, and typing the first character change only what the user asked to change. Steady layout is what makes the app feel smooth.
3. **Behave like a Mac app.** System fonts, the window buttons, standard shortcuts, native alerts, and the system appearance.
4. **One accent, used sparingly.** Blue marks where you are: the reading progress line, the selected row's bar, the current outline heading, links, and focus. Red marks warnings only.
5. **Every state has a home.** Empty, unavailable, Edited, and Changed on disk each have one designed place and wording.

## Color

Each color has one job. Text pairs reach 4.5:1 and shape pairs reach 3:1 in both appearances. A "shape only" color never carries text.

| Token | Light | Dark | Job |
|---|---|---|---|
| `--paper` | #FFFFFF | #1C1C1E | Document view background: the page you read on |
| `--sidebar` | #F7F7F8 | #161618 | Library sidebar |
| `--surface` | #FFFFFF | #26262A | Things raised above the page: dialogs, popovers, the Open now card, empty-state icon tile |
| `--row-hover` | #EFEFF1 | #222225 | Sidebar and outline row under the pointer |
| `--row-selected` | #E7E7EA | #2C2C30 | The selected Library document's row |
| `--code-bg` | #F3F3F5 | #2A2A2E | Inline code and fenced code blocks |
| `--selection` | #DCE7FD | #24385E | Text selection inside the Document view |
| `--rule` | #EBEBEE | #2E2E33 | Decorative hairlines: sidebar edge, under the top bar, table rows, the footer rule |
| `--border` | #DDDDE1 | #3A3A40 | Outline of a secondary button, popover, or card. Decorative: the label carries meaning |
| `--ink` | #1D1D1F | #E6E6E8 | Body text. 16.8:1 on paper light, 13.7:1 dark |
| `--ink-strong` | #111113 | #FAFAFA | Headings, wordmark, selected row text, primary button fill |
| `--ink-muted` | #5E5E64 | #9C9CA3 | Meta line, labels, outline items, word count, secondary text. 6.4:1 light, 6.2:1 dark on paper |
| `--ink-icon` | #808087 | #7C7C84 | Chevrons and glyph icons. Shape only: 3.2:1 or better on every surface |
| `--ink-on-strong` | #FFFFFF | #161618 | Text on a --ink-strong fill (primary button) |
| `--accent` | #2563EB | #5B8DEF | Shape only: reading progress line, selected-row bar, current outline mark, focus ring. 4.2:1 or better on every surface |
| `--accent-text` | #1D4ED8 | #7EA7F5 | Links and inline code text. 6.7:1 light, 7.1:1 dark on paper |
| `--mark-bg` | #2563EB | #5B8DEF | Wordmark "P" tile |
| `--mark-ink` | #FFFFFF | #0F1115 | The "P" on the tile. 5.2:1 light, 5.9:1 dark |
| `--danger` | #C4291C | #FF7B6E | Warnings only: "Changed on disk", destructive buttons, missing-image outline. 5.7:1 on surface light, 6.0:1 dark |
| `--danger-ink` | #FFFFFF | #161618 | Text on a --danger fill |

## Typography

| Font | Job |
|---|---|
| New York (`--font-reading`) | Document body text and block quotes |
| SF Pro (`--font-ui`) | Document headings and all app chrome |
| SF Mono (`--font-mono`) | Inline code and code blocks |

| Token | px | Use |
|---|---|---|
| `--text-h1` | 40 | Document title, left-aligned |
| `--text-h2` | 27 | Section heading |
| `--text-h3` | 21 | Subheading |
| `--text-body` | 19 | Body text, line height 1.7 |
| `--text-h4` | 17 | Minor heading |
| `--text-ui-large` | 15 | Alert and state titles |
| `--text-code` | 14 | Code blocks |
| `--text-ui` | 13 | Sidebar rows, buttons, top bar |
| `--text-caption` | 12 | Outline items, word count, footer |
| `--text-label` | 11 | Uppercase section labels and the meta line, tracking 0.06em |

Headings are bold SF Pro with -0.02em tracking and line height 1.2.

## Spacing and shape

- Space comes in 4 px steps: 4, 8, 12, 16, 24, 32, 48, 72 (`--space-1` to `--space-8`).
- The text column is 680 px at most, centered in the Document view.
- The Library sidebar is 260 px. Folders indent 16 px per level. Rows are 28 px tall.
- The top bar is 52 px and holds the window buttons' row. The reading progress line sits under it, 2 px tall.
- The outline panel is 220 px, on the right, when the window is 1240 px wide or wider.
- Radius: 4 px for inline code and popover buttons, 6 px for rows and buttons, 10 px for popovers, cards, code blocks, and images.

## Texture, light, and motion

- **Texture:** none. The page is plain `--paper`. The sidebar is one step darker so the page reads as a sheet beside it.
- **Light:** only the formatting popover has a shadow (`--shadow-popover`). Alerts are native sheets, and macOS draws their shadow. Everything else is flat.
- **Motion:** hover and selection fills fade in `--duration-fast` (120 ms). The sidebar slides and folder chevrons turn in `--duration-medium` (200 ms). Switching documents is instant. The progress line lives in the Document view and follows the scroll directly, updated once per animation frame. Reduce Motion sets every duration to zero.

## Icons

Native chrome uses SF Symbols, which follow the system's weight and size: `sidebar.left` (sidebar toggle), `chevron.right` (folder, turned 90 degrees when expanded), `folder` (choosing a Library), `folder.badge.questionmark` (Library unavailable), `doc.text` (Document unavailable). The Document view draws the SVG files in [icons/](icons/): `link.svg` and `code.svg` in the formatting popover. They are 24 px grids stroked at 1.7 with `currentColor`.

## Voice

- Buttons and menu items use title case, as macOS does: "Open a Document…", "Choose Another Library…". Titles, labels, and messages use sentence case. This was a judgment call on 22 Oct 2026: the guideline mockups mixed the two, and principle 3 picks the Mac convention.
- Use the `CONTEXT.md` words. A folder of documents is the Library, never a vault or workspace. A file is a Markdown document, never a note or page.
- State words are fixed: "Edited", "Changed on disk", "Choose a Library", "Library unavailable", "Document unavailable".
- An alert title names the consequence, and one sentence says what each choice does. Button labels are verbs: "Keep My Edits", "Reload from Disk", "Reconnect", "Choose Library…". A button that opens a picker ends in an ellipsis.

## Do and instead of

| Do | Instead of |
|---|---|
| Mark position with a 2 px `--accent` bar | Filling a row, card, or button with blue |
| Use `--danger` only for warnings and destructive actions | Red for emphasis or decoration |
| Give a window one ink-filled primary button | Two filled buttons side by side |
| Show unsaved edits as "· Edited" after the name | Swapping the window's layout when the document changes |
| Use a native `NSAlert` sheet for questions | A custom modal card |
| Keep block quotes on a 2 px `--border` rule in muted italic | An accent-colored bar |
| Put the outline on the right at 1240 px and wider | Stacking it under a long Library tree in wide windows |

## Open decisions

None as of 22 Oct 2026. For anything this skill does not settle, ask Edison or pick, and say so in your report.

To change a color, font, size, rule, or component, use the brand-guideline skill's change flow.

## Decisions made while building

The switch-over (Tickets 39 to 46, 22 Oct 2026) moved the whole app onto this skill. These judgment calls came out of that work. Each one is recorded in its ticket under `.scratch/paperbranch/issues/`.

- The Library window uses an empty unified toolbar, so the window buttons sit inside the 52 px top bar.
- The current outline heading is the last heading inside the top fifth of the Document view.
- An empty Library shows the "No document selected" screen.
- "Reconnect" retries the saved Library.
- In a Standalone window, the "Document unavailable" message drops the pointer back to the Library, because there is none.
- Popover icons draw at 16 px.
- The meta line separates its parts with " · ".
- The sidebar slide uses an ease-in-out curve. Fills and fades keep `--ease`.

## Checklist

- [ ] Every color, size, space, radius, shadow, and duration comes from a token.
- [ ] The screen works in light and dark, and every text pair reaches 4.5:1.
- [ ] Body text is New York at 19 px with line height 1.7, in a column no wider than 680 px.
- [ ] Blue appears only on the progress line, the selected row's bar, the current outline heading, links, the popover's active button, and focus.
- [ ] Red appears only on warnings and destructive actions.
- [ ] Only the formatting popover draws its own shadow.
- [ ] The window has at most one primary button.
- [ ] Switching documents, collapsing the sidebar, and typing the first character change only what the user asked to change.
- [ ] Every state uses the words in "Voice", and alerts are native sheets.
- [ ] Rows are clickable across their full width, and every control has a visible focus ring.
