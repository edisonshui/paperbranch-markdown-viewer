import { test, expect } from "@playwright/test";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { parseSemanticMarkdown } from "../support/semantic-markdown";
import { typeAtEndOf } from "../support/editing";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function loadFixture(name: string): string {
  return readFileSync(path.join(__dirname, "..", "..", "fixtures", name), "utf-8");
}

// This construct's editing behavior (rendering, contenteditable typing,
// serialization) is Milkdown's own capability, not code this proof writes.
// These tests specify and verify that capability; they are not a
// build-it-ourselves red/green cycle. Where that matters, this file notes it.

test.describe("headings", () => {
  test("renders each heading level as formatted content", async ({ page }) => {
    // Proof test: exercises Milkdown's existing commonmark rendering.
    await page.goto("/");
    const fixture = loadFixture("headings.md");
    await page.evaluate((md) => window.editorContract.loadMarkdown(md), fixture);

    await expect(page.locator("#editor-root h1")).toHaveText("Top level heading");
    await expect(page.locator("#editor-root h2")).toHaveText("Second level heading");
    await expect(page.locator("#editor-root h3")).toHaveText("Third level heading");
  });

  test("an edit typed into a heading serializes, and reopening preserves it", async ({
    page,
  }) => {
    // Proof test: the edit is performed through the rendered contenteditable
    // surface (a real click + keystrokes), not through Milkdown internals.
    await page.goto("/");
    const fixture = loadFixture("headings.md");
    await page.evaluate((md) => window.editorContract.loadMarkdown(md), fixture);

    const heading = page.locator("#editor-root h1");
    await typeAtEndOf(page, page.locator("#editor-root .ProseMirror"), heading, " (edited)");

    await expect(heading).toHaveText("Top level heading (edited)");

    const expectedEdited = [
      "# Top level heading (edited)",
      "",
      "## Second level heading",
      "",
      "### Third level heading",
      "",
    ].join("\n");

    const serialized = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(parseSemanticMarkdown(serialized)).toEqual(
      parseSemanticMarkdown(expectedEdited),
    );

    // Reopen the serialized result in a fresh load and confirm the same
    // semantic structure survives a second parse.
    await page.evaluate(
      (md) => window.editorContract.loadMarkdown(md),
      serialized,
    );
    await expect(page.locator("#editor-root h1")).toHaveText(
      "Top level heading (edited)",
    );
    const reopened = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(parseSemanticMarkdown(reopened)).toEqual(
      parseSemanticMarkdown(expectedEdited),
    );
  });
});
