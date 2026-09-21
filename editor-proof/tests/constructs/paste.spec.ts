import { test, expect } from "@playwright/test";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { parseSemanticMarkdown } from "../support/semantic-markdown";
import { pasteAtEndOf } from "../support/editing";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function loadFixture(name: string): string {
  return readFileSync(path.join(__dirname, "..", "..", "fixtures", name), "utf-8");
}

// Proof tests: clipboard paste handling is Milkdown's own capability
// (ProseMirror's HTML clipboard parsing plus the commonmark schema). Not a
// build-it-ourselves cycle.

test.describe("paste", () => {
  test("pasting HTML from a browser preserves its formatting", async ({ page }) => {
    await page.goto("/");
    const fixture = loadFixture("paste-target.md");
    await page.evaluate((md) => window.editorContract.loadMarkdown(md), fixture);

    const paragraph = page.locator("#editor-root p").first();
    await pasteAtEndOf(page.locator("#editor-root .ProseMirror"), paragraph, {
      html: "<p>Pasted <strong>bold</strong> text</p>",
      text: "Pasted bold text",
    });

    await expect(page.locator("#editor-root strong")).toHaveText("bold");

    const serialized = await page.evaluate(() => window.editorContract.getMarkdown());
    // Confirms the pasted content's meaning (that "bold" is actually
    // emphasized, not literal asterisks) survives serialization.
    expect(parseSemanticMarkdown(serialized)).toEqual(
      parseSemanticMarkdown("Existing paragraph.Pasted **bold** text\n"),
    );

    await page.evaluate((md) => window.editorContract.loadMarkdown(md), serialized);
    await expect(page.locator("#editor-root strong")).toHaveText("bold");
  });

  test("pasting Markdown source as plain text keeps it as literal text, not reinterpreted formatting", async ({
    page,
  }) => {
    // Proof finding: a paste that carries only `text/plain` (as a plain-text
    // Markdown source file would, copied from another editor) is inserted
    // as literal text. Its `**` characters are not reinterpreted as an
    // emphasis marker; they round-trip as literal, escaped characters
    // instead. Nothing is silently lost or turned into different supported
    // content, but the pasted Markdown syntax does not become formatting.
    await page.goto("/");
    const fixture = loadFixture("paste-target.md");
    await page.evaluate((md) => window.editorContract.loadMarkdown(md), fixture);

    const paragraph = page.locator("#editor-root p").first();
    await pasteAtEndOf(page.locator("#editor-root .ProseMirror"), paragraph, {
      text: " **bold** from another editor",
    });

    await expect(page.locator("#editor-root strong")).toHaveCount(0);
    await expect(paragraph).toHaveText(
      "Existing paragraph. **bold** from another editor",
    );

    const serialized = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(serialized).toBe(
      "Existing paragraph. \\*\\*bold\\*\\* from another editor\n",
    );

    await page.evaluate((md) => window.editorContract.loadMarkdown(md), serialized);
    await expect(page.locator("#editor-root strong")).toHaveCount(0);
    await expect(page.locator("#editor-root p").first()).toHaveText(
      "Existing paragraph. **bold** from another editor",
    );
  });
});
