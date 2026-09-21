# 01: Prove formatted Markdown editing

**What to build:** Create a repeatable editor proof that loads, edits, serializes, and reopens Paperbranch's supported Markdown. Start with Milkdown. The proof must select one editor that preserves document meaning and supports direct formatted editing before application work depends on it.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] The proof loads and renders headings, emphasis, ordered and unordered lists, links, images, block quotes, fenced code blocks, tables, task lists, and strikethrough.
- [ ] The proof performs a representative edit to each supported construct and serializes the result to Markdown.
- [ ] Each serialized result can be parsed and reopened with the same semantic document structure, even when equivalent Markdown syntax changes.
- [ ] Fixtures cover nested and mixed lists, table alignment and escaped pipes, fenced code block languages and literal backticks, relative and absolute images, escaped links, and formatting nested inside block quotes.
- [ ] Paste from a browser and another Markdown editor works without losing supported document meaning.
- [ ] Undo and redo restore the expected document structure across inline and block edits.
- [ ] The proof records how raw HTML, front matter, footnotes, mathematical notation, Mermaid diagrams, and unknown syntax behave, and no case silently becomes different supported content.
- [ ] One repeatable test command runs the complete editor contract and reports individual fixture failures.
- [ ] Milkdown is accepted only if every required check passes. If it fails, the same contract runs against TOAST UI Editor and records the selected editor.
