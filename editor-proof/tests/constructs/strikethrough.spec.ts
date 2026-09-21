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

// Proof tests: strikethrough and combining it with other inline marks is
// Milkdown's own gfm-preset capability. Not a build-it-ourselves cycle.

test.describe("strikethrough mixed with other inline formatting", () => {
  test("renders plain and emphasis-combined strikethrough", async ({ page }) => {
    await page.goto("/");
    const fixture = loadFixture("strikethrough.md");
    await page.evaluate((md) => window.editorContract.loadMarkdown(md), fixture);

    await expect(page.locator("#editor-root del").first()).toHaveText(
      "struck through",
    );
    await expect(page.locator("#editor-root del em, #editor-root em del")).toHaveText(
      "struck and emphasized",
    );
  });

  test("editing struck-through text serializes and reopens with the same structure", async ({
    page,
  }) => {
    await page.goto("/");
    const fixture = loadFixture("strikethrough.md");
    await page.evaluate((md) => window.editorContract.loadMarkdown(md), fixture);

    const plainDel = page.locator("#editor-root del").first();
    await typeAtEndOf(page, page.locator("#editor-root .ProseMirror"), plainDel, "!");

    await expect(plainDel).toHaveText("struck through!");

    const expectedEdited =
      "This is ~~struck through!~~ text, and this is ~~*struck and emphasized*~~ together.\n";

    const serialized = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(parseSemanticMarkdown(serialized)).toEqual(
      parseSemanticMarkdown(expectedEdited),
    );

    await page.evaluate((md) => window.editorContract.loadMarkdown(md), serialized);
    await expect(page.locator("#editor-root del").first()).toHaveText(
      "struck through!",
    );
    const reopened = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(parseSemanticMarkdown(reopened)).toEqual(
      parseSemanticMarkdown(expectedEdited),
    );
  });
});
