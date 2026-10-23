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

  // Currency follows Pandoc's tex_math_dollars rule (Edison's decision, 22 Oct 2026):
  // the opening $ needs a non-space character to its right, the closing $ needs a
  // non-space character to its left and must not be followed by a digit.
  test("two dollar amounts in one paragraph are prices, not math", () => {
    const doc = "This costs $5 and that costs $10, not a math expression.";
    expect(classifyMarkdown(doc)).toEqual({ status: "admitted" });
  });

  test("a price range and a table of prices are admitted", () => {
    const doc = [
      "Rent runs $650 to $1,000 a bed, plus $30 per lease year.",
      "",
      "| Building | $/bed | Fee |",
      "|---|---|---|",
      "| HERE | $1,200 | $100 |",
      "| Octave | $954 est. | $75 |",
      "",
    ].join("\n");
    expect(classifyMarkdown(doc)).toEqual({ status: "admitted" });
  });

  test("a closing dollar sign followed by a digit is not math", () => {
    expect(classifyMarkdown("Between $20,000 and $30,000 a year.")).toEqual({ status: "admitted" });
  });

  test("real inline math is still blocked next to prices", () => {
    expect(classifyMarkdown("It costs $5, and $E = mc^2$ holds.")).toEqual({ status: "blocked", reasons: ["math"] });
    expect(classifyMarkdown("Let $x$ be the rent.")).toEqual({ status: "blocked", reasons: ["math"] });
  });

  test("display math is still blocked", () => {
    expect(classifyMarkdown("$$\n\\int_0^1 x \\, dx\n$$\n")).toEqual({ status: "blocked", reasons: ["math"] });
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
