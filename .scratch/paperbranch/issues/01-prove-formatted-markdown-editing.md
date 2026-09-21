# 01: Prove formatted Markdown editing

**What to build:** Create a repeatable editor proof that loads, edits, serializes, and reopens Paperbranch's supported Markdown. Start with Milkdown. The proof must select one editor that preserves document meaning and supports direct formatted editing before application work depends on it.

**Blocked by:** None (can start immediately).

**Status:** resolved

- [x] The proof loads and renders headings, emphasis, ordered and unordered lists, links, images, block quotes, fenced code blocks, tables, task lists, and strikethrough.
- [x] The proof performs a representative edit to each supported construct and serializes the result to Markdown.
- [x] Each serialized result can be parsed and reopened with the same semantic document structure, even when equivalent Markdown syntax changes.
- [x] Fixtures cover nested and mixed lists, table alignment and escaped pipes, fenced code block languages and literal backticks, relative and absolute images, escaped links, and formatting nested inside block quotes.
- [x] Paste from a browser and another Markdown editor works without losing supported document meaning.
- [x] Undo and redo restore the expected document structure across inline and block edits.
- [x] The proof records how raw HTML, front matter, footnotes, mathematical notation, Mermaid diagrams, and unknown syntax behave, and no case silently becomes different supported content. (Raw HTML, footnotes, Mermaid, and unknown syntax pass through Milkdown intact. Front matter and math are detected by the editor-admission seam and blocked from formatted editing before Milkdown loads them, rather than accepted as a mutation. See `editor-proof/PROOF_REPORT.md` and ADR 0004.)
- [x] One repeatable test command runs the complete editor contract and reports individual fixture failures. (`npm test` in `editor-proof/`; every passing assertion is a positive claim, none accept a contract failure as an outcome.)
- [x] Milkdown is accepted only if every required check passes. If it fails, the same contract runs against TOAST UI Editor and records the selected editor. (TOAST UI Editor was run and failed more broadly than Milkdown; see PROOF_REPORT.md. Milkdown is selected, gated by the editor-admission seam, which brings the complete contract to passing.)
- [x] The proof runs inside a minimal macOS `WKWebView` host, not only in a normal browser. (`editor-proof/native-host`, a SwiftPM app; `native-host/run.sh` runs it against the harness.)
- [x] With focus inside the editor, `Command-S` reaches the native host and requests the current serialized Markdown without writing a file automatically. (`AppDelegate.swift`'s Save menu item, keyEquivalent "s" + Command, routes through AppKit's standard key-equivalent resolution. `requestSave()` is verified by `native-host/test.sh` to return live content and write nothing to disk. The visible focused-editor path was confirmed with OS-level Command-S input on 2026-09-21.)
- [x] Simulated external-content messages replace clean editor content and preserve dirty editor content for later conflict handling. (`externalReplace`, verified by both `editor-proof` (`tests/constructs/native-bridge.spec.ts`) and `native-host/test.sh`.)
- [x] The native/editor bridge exposes only the document information needed for editing, saving, safe reloads, and conflict notifications. JavaScript receives no unrestricted file-system access. (One `WKScriptMessageHandler` name (`"paperbranch"`, dirty-state only) and two native-facing JS calls (`requestSave`, `externalReplace`); verified by `native-host/test.sh`.)

Editor decision resolved: Milkdown is selected, gated by a new
editor-admission seam (`editor-proof/src/admission.ts`) that blocks
formatted editing for a document containing front matter or mathematical
notation, per ADR 0004. The minimal native WKWebView host and bridge are
built and verified in `editor-proof/native-host/`; see
`editor-proof/PROOF_REPORT.md` for the full account.

## Comments

Verification:

- `cd editor-proof && npm test`: 46 browser contract tests passed.
- `cd editor-proof/native-host && ./test.sh`: 5 tests passed against a real off-screen `WKWebView`.
- The built host loaded deterministic sample Markdown in a visible window. An Accessibility-permissioned UI controller focused and edited the Document view, then sent OS-level Command-S. The host logged `Command-S requested a save. Received 140 characters of serialized Markdown. No file was written.`

Implementation commits: `fc9c24e`, `74a1550`, and `0ab5eac`.
