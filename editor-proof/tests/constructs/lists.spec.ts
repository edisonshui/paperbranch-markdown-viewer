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

// Proof tests: nested/mixed list rendering and editing are Milkdown's own
// capability. Not a build-it-ourselves red/green cycle.

test.describe("nested and mixed lists", () => {
  test("renders unordered and ordered lists nested inside each other", async ({
    page,
  }) => {
    await page.goto("/");
    const fixture = loadFixture("lists.md");
    await page.evaluate((md) => window.editorContract.loadMarkdown(md), fixture);

    const topLists = page.locator(
      "#editor-root .ProseMirror > ul, #editor-root .ProseMirror > ol",
    );
    await expect(topLists).toHaveCount(2);
    await expect(topLists.nth(0)).toHaveJSProperty("tagName", "UL");
    await expect(topLists.nth(1)).toHaveJSProperty("tagName", "OL");

    // First bullet list nests an ordered list inside its second item.
    await expect(
      topLists.nth(0).locator("> li").nth(1).locator("> ol > li"),
    ).toHaveCount(2);

    // Second ordered list nests a bullet list inside its second item.
    await expect(
      topLists.nth(1).locator("> li").nth(1).locator("> ul > li"),
    ).toHaveCount(2);
  });

  test("editing a nested list item serializes and reopens with the same structure", async ({
    page,
  }) => {
    await page.goto("/");
    const fixture = loadFixture("lists.md");
    await page.evaluate((md) => window.editorContract.loadMarkdown(md), fixture);

    const nestedItem = page.locator("#editor-root ol li p", {
      hasText: "Nested ordered item",
    }).first();
    await typeAtEndOf(
      page,
      page.locator("#editor-root .ProseMirror"),
      nestedItem,
      " updated",
    );

    await expect(nestedItem).toHaveText("Nested ordered item updated");

    const expectedEdited = [
      "* Unordered item one",
      "* Unordered item two",
      "  1. Nested ordered item updated",
      "  2. Second nested ordered item",
      "* Unordered item three",
      "",
      "1. Ordered item one",
      "2. Ordered item two",
      "   * Nested unordered item",
      "   * Second nested unordered item",
      "3. Ordered item three",
      "",
    ].join("\n");

    const serialized = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(parseSemanticMarkdown(serialized)).toEqual(
      parseSemanticMarkdown(expectedEdited),
    );

    await page.evaluate((md) => window.editorContract.loadMarkdown(md), serialized);
    await expect(
      page.locator("#editor-root ol li p", { hasText: "Nested ordered item" }).first(),
    ).toHaveText("Nested ordered item updated");
    const reopened = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(parseSemanticMarkdown(reopened)).toEqual(
      parseSemanticMarkdown(expectedEdited),
    );
  });
});
