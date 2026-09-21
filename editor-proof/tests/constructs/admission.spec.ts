import { test, expect } from "@playwright/test";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { classifyMarkdown } from "../../src/admission";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function loadFixture(name: string): string {
  return readFileSync(path.join(__dirname, "..", "..", "fixtures", name), "utf-8");
}

// The editor-admission seam (src/admission.ts, docs/adr/0004) classifies a
// document as safe to load into Milkdown or blocked, before any Markdown
// reaches the editor. It exists because two unsupported constructs --
// front matter and mathematical notation -- are not just "unsupported" but
// actively unsafe: Milkdown's parser silently reinterprets them as
// different supported content (see tests/constructs/unsupported-syntax.spec.ts
// for the four constructs that ARE safe to admit).

test.describe("editor admission: classification", () => {
  test("blocks front matter with reason 'front-matter'", () => {
    const result = classifyMarkdown(loadFixture("unsupported-frontmatter.md"));
    expect(result).toEqual({ status: "blocked", reasons: ["front-matter"] });
  });

  test("blocks inline and block math with reason 'math'", () => {
    const result = classifyMarkdown(loadFixture("unsupported-math.md"));
    expect(result).toEqual({ status: "blocked", reasons: ["math"] });
  });

  test("blocks a document containing both front matter and math with both reasons", () => {
    const combined = [
      "---",
      "title: Both unsafe constructs",
      "---",
      "",
      "Inline math $E = mc^2$ here.",
      "",
    ].join("\n");
    const result = classifyMarkdown(combined);
    expect(result.status).toBe("blocked");
    expect(result.status === "blocked" && result.reasons.sort()).toEqual([
      "front-matter",
      "math",
    ]);
  });

  test("admits the four unsupported-but-safe constructs", () => {
    for (const name of [
      "unsupported-html.md",
      "unsupported-footnotes.md",
      "unsupported-mermaid.md",
      "unsupported-unknown-syntax.md",
    ]) {
      expect(classifyMarkdown(loadFixture(name))).toEqual({ status: "admitted" });
    }
  });

  test("admits every required supported-construct fixture", () => {
    for (const name of [
      "headings.md",
      "lists.md",
      "tables.md",
      "code-blocks.md",
      "images.md",
      "escaped-links.md",
      "task-list.md",
      "blockquotes.md",
      "strikethrough.md",
      "emphasis-and-links.md",
      "undo-redo.md",
      "paste-target.md",
    ]) {
      expect(classifyMarkdown(loadFixture(name))).toEqual({ status: "admitted" });
    }
  });

  test("does not misfire on a plain thematic break that is not front matter", () => {
    const doc = ["A paragraph.", "", "---", "", "Another paragraph."].join("\n");
    expect(classifyMarkdown(doc)).toEqual({ status: "admitted" });
  });

  test("KNOWN TRADE-OFF: a paragraph with two unspaced dollar amounts is blocked as math", () => {
    // This is not a detector bug: `$...$` is inherently ambiguous between
    // "inline math" and "two currency amounts" in any implementation of
    // this CommonMark math extension (Pandoc has the identical ambiguity).
    // remark-math treats an opening `$` not immediately followed by
    // whitespace as a potential math start, and pairs it with the next `$`
    // in the same paragraph, so two dollar amounts with no blank line
    // between them can read as one inline math span. See docs/adr/0004 for
    // why this direction of failure is accepted: it over-blocks (a safe,
    // recoverable usability cost) rather than under-blocking (which would
    // risk the silent corruption this seam exists to prevent).
    const doc = "This costs $5 and that costs $10, not a math expression.";
    expect(classifyMarkdown(doc)).toEqual({ status: "blocked", reasons: ["math"] });
  });

  test("a single unpaired dollar sign is not mistaken for math", () => {
    const doc = "This document has one price: $5 total, nothing to pair it with.";
    expect(classifyMarkdown(doc)).toEqual({ status: "admitted" });
  });
});

test.describe("editor admission: blocked documents never reach Milkdown", () => {
  test("a blocked front-matter document is never passed to Milkdown and its source is preserved byte-for-byte", async ({
    page,
  }) => {
    await page.goto("/");
    const fixture = loadFixture("unsupported-frontmatter.md");
    const admission = await page.evaluate(
      (md) => window.editorContract.loadMarkdown(md),
      fixture,
    );
    expect(admission).toEqual({ status: "blocked", reasons: ["front-matter"] });

    // No Milkdown/ProseMirror surface was created for this document.
    await expect(page.locator("#editor-root .ProseMirror")).toHaveCount(0);
    await expect(page.locator("#editor-root")).toHaveAttribute(
      "data-admission",
      "blocked",
    );

    // getMarkdown() returns the original source untouched -- it was never
    // derived from a serializer, so it cannot have been mutated into
    // different supported content, and there is nothing here a save
    // request could write back except the original bytes.
    const returned = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(returned).toBe(fixture);
  });

  test("a blocked math document is never passed to Milkdown and its source is preserved byte-for-byte", async ({
    page,
  }) => {
    await page.goto("/");
    const fixture = loadFixture("unsupported-math.md");
    const admission = await page.evaluate(
      (md) => window.editorContract.loadMarkdown(md),
      fixture,
    );
    expect(admission).toEqual({ status: "blocked", reasons: ["math"] });

    await expect(page.locator("#editor-root .ProseMirror")).toHaveCount(0);
    await expect(page.locator("#editor-root")).toHaveAttribute(
      "data-admission",
      "blocked",
    );

    const returned = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(returned).toBe(fixture);
  });

  test("loading an admitted document after a blocked one creates a fresh Milkdown editor", async ({
    page,
  }) => {
    await page.goto("/");
    await page.evaluate(
      (md) => window.editorContract.loadMarkdown(md),
      loadFixture("unsupported-frontmatter.md"),
    );
    await expect(page.locator("#editor-root .ProseMirror")).toHaveCount(0);

    const admission = await page.evaluate(
      (md) => window.editorContract.loadMarkdown(md),
      loadFixture("headings.md"),
    );
    expect(admission).toEqual({ status: "admitted" });
    await expect(page.locator("#editor-root .ProseMirror")).toHaveCount(1);
    await expect(page.locator("#editor-root h1")).toHaveText("Top level heading");
  });

  test("loading a blocked document after an admitted one tears down the previous Milkdown editor", async ({
    page,
  }) => {
    await page.goto("/");
    await page.evaluate(
      (md) => window.editorContract.loadMarkdown(md),
      loadFixture("headings.md"),
    );
    await expect(page.locator("#editor-root .ProseMirror")).toHaveCount(1);

    const admission = await page.evaluate(
      (md) => window.editorContract.loadMarkdown(md),
      loadFixture("unsupported-math.md"),
    );
    expect(admission.status).toBe("blocked");
    await expect(page.locator("#editor-root .ProseMirror")).toHaveCount(0);
  });
});
