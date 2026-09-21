import { test, expect } from "@playwright/test";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function loadFixture(name: string): string {
  return readFileSync(path.join(__dirname, "..", "..", "fixtures", name), "utf-8");
}

// Proof tests: docs/specs/paperbranch-implementation.md ("Formatted editing
// and Markdown") requires that raw HTML, front matter, footnotes,
// mathematical notation, Mermaid diagrams, and plugin-defined Markdown are
// unsupported in v1, and that Paperbranch "must avoid silently converting
// an unsupported construct into different supported content."
//
// Four of those six constructs are admitted into Milkdown and pass through
// safely: Milkdown has no dedicated node for them, so it either renders
// them as inert/opaque content or leaves them as literal text, and
// serialization reproduces the original source byte-for-byte. These four
// are exercised here.
//
// The other two -- front matter and mathematical notation -- are NOT safe:
// Milkdown's commonmark parser recognizes overlapping syntax (thematic
// breaks, setext headings, escaped underscores) inside them and silently
// reinterprets them as different supported content. Per
// docs/adr/0004-block-unsafe-markdown-before-the-editor.md, those two are
// detected and blocked by the editor-admission module before Milkdown ever
// loads them; see tests/constructs/admission.spec.ts.

test.describe("unsupported syntax", () => {
  test("raw HTML blocks and inline HTML are admitted and round-trip intact", async ({
    page,
  }) => {
    await page.goto("/");
    const fixture = loadFixture("unsupported-html.md");
    const admission = await page.evaluate(
      (md) => window.editorContract.loadMarkdown(md),
      fixture,
    );
    expect(admission).toEqual({ status: "admitted" });

    // Milkdown renders raw HTML as opaque, non-editable "html" nodes rather
    // than interpreting it, so it never becomes different supported content.
    await expect(page.locator('#editor-root [data-type="html"]')).toHaveCount(3);

    const serialized = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(serialized).toBe(fixture);
  });

  test("footnote references and definitions are admitted and round-trip intact", async ({
    page,
  }) => {
    await page.goto("/");
    const fixture = loadFixture("unsupported-footnotes.md");
    const admission = await page.evaluate(
      (md) => window.editorContract.loadMarkdown(md),
      fixture,
    );
    expect(admission).toEqual({ status: "admitted" });

    // Milkdown has dedicated (but non-editing-supported) footnote nodes, so
    // the reference and definition survive as themselves, not as plain text
    // or a different construct.
    await expect(
      page.locator('#editor-root [data-type="footnote_reference"]'),
    ).toHaveText("1");
    await expect(
      page.locator('#editor-root [data-type="footnote_definition"]'),
    ).toContainText("The footnote definition.");

    const serialized = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(serialized).toBe(fixture);
  });

  test("Mermaid fenced blocks are admitted and round-trip intact as opaque code", async ({
    page,
  }) => {
    await page.goto("/");
    const fixture = loadFixture("unsupported-mermaid.md");
    const admission = await page.evaluate(
      (md) => window.editorContract.loadMarkdown(md),
      fixture,
    );
    expect(admission).toEqual({ status: "admitted" });

    // Milkdown has no Mermaid renderer, so the block falls back to being
    // treated as a plain fenced code block with the "mermaid" language tag.
    // It stays a code block (source visible as plain content), not a
    // diagram and not reinterpreted as anything else.
    await expect(page.locator("#editor-root pre[data-language='mermaid']")).toHaveText(
      "graph TD\n  A --> B",
    );

    const serialized = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(serialized).toBe(fixture);
  });

  test("unknown plugin-style syntax is admitted and round-trips intact as literal text", async ({
    page,
  }) => {
    await page.goto("/");
    const fixture = loadFixture("unsupported-unknown-syntax.md");
    const admission = await page.evaluate(
      (md) => window.editorContract.loadMarkdown(md),
      fixture,
    );
    expect(admission).toEqual({ status: "admitted" });

    // No commonmark/GFM construct matches `::custom::` or `{curly}`, so
    // Milkdown's parser leaves them as literal paragraph text.
    await expect(page.locator("#editor-root p")).toHaveText(
      "A paragraph with an unknown ::custom:: directive and a {curly} plugin span.",
    );

    const serialized = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(serialized).toBe(fixture);
  });
});
