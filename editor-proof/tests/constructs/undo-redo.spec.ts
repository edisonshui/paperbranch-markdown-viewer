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

async function fullyUndo(page: import("@playwright/test").Page): Promise<void> {
  for (let i = 0; i < 10; i += 1) await page.keyboard.press("Meta+z");
}

async function fullyRedo(page: import("@playwright/test").Page): Promise<void> {
  for (let i = 0; i < 10; i += 1) await page.keyboard.press("Meta+Shift+z");
}

test.describe("undo and redo", () => {
  test("undo restores the document before a structural edit, and redo restores it after", async ({
    page,
  }) => {
    // This is new implementation: Milkdown's default Editor.make() with
    // just the commonmark and gfm presets does not wire up undo/redo at
    // all, so Cmd-Z does nothing without adding the history plugin.
    await page.goto("/");
    const fixture = loadFixture("undo-redo.md");
    await page.evaluate((md) => window.editorContract.loadMarkdown(md), fixture);

    const secondItem = page.locator("#editor-root li p").nth(1);
    await typeAtEndOf(page, page.locator("#editor-root .ProseMirror"), secondItem, "");
    await page.keyboard.press("Enter");
    await page.keyboard.type("Third item");

    const editedMarkdown = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(parseSemanticMarkdown(editedMarkdown)).toEqual(
      parseSemanticMarkdown("* First item\n* Second item\n* Third item\n"),
    );

    await fullyUndo(page);
    const undoneMarkdown = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(parseSemanticMarkdown(undoneMarkdown)).toEqual(
      parseSemanticMarkdown(fixture),
    );

    await fullyRedo(page);
    const redoneMarkdown = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(parseSemanticMarkdown(redoneMarkdown)).toEqual(
      parseSemanticMarkdown(editedMarkdown),
    );
  });
});
