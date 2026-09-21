# Editor proof report (Ticket 01)

Status: **complete.** Milkdown is selected, gated by an
editor-admission seam (see [ADR 0004](../docs/adr/0004-block-unsafe-markdown-before-the-editor.md)),
and the minimal native WKWebView host (`native-host/`) implements the
Command-S, external-content, and bridge-scope requirements. The automated
suites verify the code paths, and OS-level input verified Command-S with the
visible editor focused.

## What was tested

Milkdown was run through the full behavioral contract (`fixtures/*.md`,
load → edit/round-trip → serialize → reopen), driven by Playwright against
`src/harness.ts` served at `/`. `npm test` in this directory is the one
repeatable acceptance command; it passes only when every required construct
round-trips correctly and every unsafe construct is blocked before reaching
Milkdown. It does not contain any test that treats a contract failure as an
accepted outcome.

## Supported constructs

All required supported constructs (headings, emphasis, links, ordered and
unordered lists including nesting, block quotes, fenced code blocks, tables,
task lists, strikethrough, images, escaped links, paste from a browser and
from plain text, undo and redo) round-trip with the same semantic structure.
Covered by `tests/constructs/*.spec.ts` (excluding `admission.spec.ts` and
`unsupported-syntax.spec.ts`, which cover the unsupported/unsafe cases
below).

## Unsupported constructs (the six required findings)

Per `docs/specs/paperbranch-implementation.md`: "Paperbranch must avoid
silently converting an unsupported construct into different supported
content... The editor proof must determine whether unsupported source
remains intact, becomes visible as plain content, or blocks formatted
editing."

| Construct | Result | Covered by |
|---|---|---|
| Raw HTML (block + inline) | Admitted, intact. Rendered as opaque, non-editable nodes; serializes back byte-for-byte identical. | `tests/constructs/unsupported-syntax.spec.ts` |
| Footnotes (reference + definition) | Admitted, intact. Dedicated (non-editing) footnote nodes; serializes back byte-for-byte identical. | `tests/constructs/unsupported-syntax.spec.ts` |
| Mermaid diagrams (fenced ` ```mermaid ` blocks) | Admitted, intact. Falls back to a plain fenced code block; source round-trips identically. | `tests/constructs/unsupported-syntax.spec.ts` |
| Unknown/plugin syntax (`::custom::`, `{curly}`) | Admitted, intact. No matching construct; kept as literal paragraph text; round-trips identically. | `tests/constructs/unsupported-syntax.spec.ts` |
| Front matter (YAML between `---` fences) | **Blocked.** Milkdown's parser reads it as a thematic break + a setext heading built from the YAML lines -- the front matter would be replaced by a real heading if admitted. Detected via `remark-frontmatter`'s `yaml` node and never loaded into Milkdown. | `tests/constructs/admission.spec.ts` |
| Mathematical notation (`$...$`, `$$...$$`) | **Blocked.** Milkdown has no math node; commonmark escaping mutates the literal math source (`\_` escaping, `\,` → `,`) if admitted. Detected via `remark-math`'s `math`/`inlineMath` nodes and never loaded into Milkdown. | `tests/constructs/admission.spec.ts` |

## The editor-admission seam

`src/admission.ts` exports `classifyMarkdown(markdown): AdmissionResult`,
returning `{ status: "admitted" }` or `{ status: "blocked", reasons:
BlockedReason[] }`. It parses the document with `remark-parse` plus the
`remark-frontmatter` and `remark-math` extensions and walks the resulting
AST for `yaml` and `math`/`inlineMath` nodes, rather than pattern-matching
raw text. `src/harness.ts` calls it at the top of `loadMarkdown` and, when
blocked:

- never constructs a Milkdown editor instance for that document;
- stores the original source verbatim and returns it unchanged from
  `getMarkdown()` -- there is no serializer involved, so there is nothing
  for a save request to write back except the original bytes;
- marks `#editor-root` with `data-admission="blocked"` so the host UI can
  show why formatted editing is unavailable.

`tests/constructs/admission.spec.ts` covers: unit-level classification of
every fixture (all twelve supported-construct fixtures admitted, all four
safe unsupported-construct fixtures admitted, both unsafe fixtures blocked
with the correct reason, and a combined-reasons case); that a blocked
document never creates a `.ProseMirror` surface and returns its source
byte-for-byte; and that switching between blocked and admitted documents
correctly tears down/creates the Milkdown instance each time.

### Known trade-off: `$` ambiguity

`remark-math` treats any `$` not immediately followed by whitespace as a
potential math opener, paired with the next `$` in the same paragraph. A
sentence like "This costs $5 and that costs $10" is indistinguishable from
inline math by this rule -- the same ambiguity `$`-delimited math has in
Pandoc and other implementations, not a bug specific to this detector. This
means such a paragraph is blocked from formatted editing even though it is
not actually math. That failure direction is accepted: it over-blocks
(a safe, recoverable usability cost -- the user can still see and, once the
native host exists, cannot silently lose data) rather than under-blocking,
which would risk exactly the silent corruption this seam exists to prevent.
See `tests/constructs/admission.spec.ts` for the documented case.

## Why TOAST UI Editor was not chosen instead

TOAST UI Editor was evaluated as Ticket 01's required fallback before the
admission-seam approach was decided. It does not avoid the problem Milkdown
has -- it is strictly worse:

| Construct | Milkdown | TOAST UI Editor |
|---|---|---|
| Raw HTML | Intact | **Worse.** Tags stripped outright; only text content survives -- silent data loss, not just reformatting. |
| Footnotes | Intact | **Worse.** Definition line escaped into literal bracket text, losing the footnote-definition construct. |
| Front matter | Contract failure (becomes a heading) | Contract failure (becomes a paragraph) -- same class of failure. |
| Math | Contract failure (source mutated) | Contract failure (source mutated further, plus an extra inserted backslash). |
| Mermaid | Intact | Intact |
| Unknown syntax | Intact | Intact |
| Image titles (a required *supported* construct) | Preserved correctly | **Additional failure.** A relative image's title text is silently dropped on serialize. |

TOAST UI Editor failed on 4 of 6 unsupported-construct checks (versus
Milkdown's 2) and introduced a new failure on a required supported
construct. Building the admission seam on top of Milkdown was a better use
of the "block formatted editing" option the spec already allows than
switching to a worse editor. The exploratory TOAST UI harness used for this
comparison was not kept in the repository once this decision was made; this
table is the durable record of what was found.

## Native WKWebView host and bridge

`native-host/` (a SwiftPM package, not a full Xcode project -- lighter
weight for a throwaway proof host) runs the harness inside a real
`WKWebView` and implements the native/editor boundary from
`docs/specs/paperbranch-implementation.md`:

- `src/native-bridge.ts` installs `window.paperbranchNativeBridge`
  (`requestSave`, `externalReplace`) as the only native-facing surface, and
  reports dirty-state transitions through a single `"paperbranch"`
  `WKScriptMessageHandler` message (`{ type: "dirtyStateChanged", dirty
  }`). Nothing else is exposed -- no file paths, no read/write primitive.
- `src/harness.ts` tracks dirty state via Milkdown's `listener` plugin,
  comparing live serialized content against the last-loaded baseline, and
  drives `externalReplace`: clean -> loads the new content through the
  admission seam; dirty -> preserves the in-memory content untouched.
- `native-host/Sources/PaperbranchEditorProofHost/AppDelegate.swift` wires
  a `Save` menu item with `keyEquivalent: "s"` / Command modifier to the
  same `requestSave()` path, so Command-S reaches native code via AppKit's
  standard key-equivalent resolution (which runs before a view's own
  `keyDown` handling) even with the `WKWebView` focused.
- `native-host/Tests/PaperbranchBridgeCoreTests/BridgeCoordinatorTests.swift`
  drives a real (off-screen) `WKWebView` through the bridge and verifies:
  `requestSave()` returns live content and touches no file on disk; a
  clean document is replaced by `externalReplace`; a dirty document's
  content is preserved byte-for-byte and the replacement is reported as
  not applied; an unsafe (blocked) external replacement is correctly
  blocked, not loaded; and the only registered message handler and native
  JS surface are exactly the narrow ones described above.

`native-host/test.sh` verifies the bridge without a human. On 2026-09-21,
an Accessibility-permissioned UI controller focused and edited the visible
Document view, then sent OS-level Command-S. The host received 140 characters
of serialized Markdown and confirmed that it wrote no file. See
`native-host/README.md` for the reproduction steps.

## How to reproduce

```sh
cd editor-proof
npm install
npx playwright install chromium   # first run only
npm test                          # browser-editor contract (46 specs)

cd native-host
./test.sh                         # native bridge contract (5 specs)
./run.sh                          # the actual proof host, for manual Command-S confirmation
```

All specs pass, and every passing assertion is a positive claim (a
construct round-trips correctly, an unsafe document is correctly blocked,
or a bridge behavior is verified against a real WebKit/WKWebView) -- none
of them accept a contract failure as an expected outcome.
