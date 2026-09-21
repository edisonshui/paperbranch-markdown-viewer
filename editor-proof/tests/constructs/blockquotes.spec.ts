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

// Proof tests: nesting other blocks inside a block quote is Milkdown's own
// commonmark-preset capability. Not a build-it-ourselves cycle.

test.describe("block quotes containing other blocks", () => {
  test("renders a heading, list, and code block nested inside a block quote", async ({
    page,
  }) => {
    await page.goto("/");
    const fixture = loadFixture("blockquotes.md");
    await page.evaluate((md) => window.editorContract.loadMarkdown(md), fixture);

    const quote = page.locator("#editor-root blockquote");
    await expect(quote).toHaveCount(1);
    await expect(quote.locator("h2")).toHaveText("A quoted heading");
    await expect(quote.locator("ul li")).toHaveCount(2);
    await expect(quote.locator("pre code")).toHaveText("quoted();");
  });

  test("editing the quoted list serializes with the quote markers preserved, and reopens the same", async ({
    page,
  }) => {
    await page.goto("/");
    const fixture = loadFixture("blockquotes.md");
    await page.evaluate((md) => window.editorContract.loadMarkdown(md), fixture);

    const firstItem = page
      .locator("#editor-root blockquote ul li p")
      .first();
    await typeAtEndOf(
      page,
      page.locator("#editor-root .ProseMirror"),
      firstItem,
      " (updated)",
    );

    await expect(firstItem).toHaveText("A quoted list item (updated)");

    const expectedEdited = [
      "> ## A quoted heading",
      ">",
      "> * A quoted list item (updated)",
      "> * Another quoted list item",
      ">",
      "> ```js",
      "> quoted();",
      "> ```",
      "",
    ].join("\n");

    const serialized = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(parseSemanticMarkdown(serialized)).toEqual(
      parseSemanticMarkdown(expectedEdited),
    );

    await page.evaluate((md) => window.editorContract.loadMarkdown(md), serialized);
    await expect(
      page.locator("#editor-root blockquote ul li p").first(),
    ).toHaveText("A quoted list item (updated)");
    const reopened = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(parseSemanticMarkdown(reopened)).toEqual(
      parseSemanticMarkdown(expectedEdited),
    );
  });
});
