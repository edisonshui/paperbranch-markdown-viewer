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

// Proof tests: emphasis/link rendering, editing, and serialization are all
// Milkdown's existing capability. Not a build-it-ourselves red/green cycle.

test.describe("emphasis and links", () => {
  test("renders a heading and paragraph with nested emphasis and links", async ({
    page,
  }) => {
    await page.goto("/");
    const fixture = loadFixture("emphasis-and-links.md");
    await page.evaluate((md) => window.editorContract.loadMarkdown(md), fixture);

    await expect(page.locator("#editor-root h1 em")).toHaveText("emphasis");
    await expect(page.locator("#editor-root h1 a")).toHaveText("link");
    await expect(page.locator("#editor-root h1 a")).toHaveAttribute(
      "href",
      "https://example.com/heading",
    );
    await expect(page.locator("#editor-root p em")).toHaveText("emphasis");
    await expect(page.locator("#editor-root p strong")).toHaveText(
      "strong emphasis",
    );
    await expect(page.locator("#editor-root p a")).toHaveText("plain link");
  });

  test("editing text inside strong emphasis serializes and reopens with the same structure", async ({
    page,
  }) => {
    await page.goto("/");
    const fixture = loadFixture("emphasis-and-links.md");
    await page.evaluate((md) => window.editorContract.loadMarkdown(md), fixture);

    const strong = page.locator("#editor-root p strong");
    await typeAtEndOf(page, page.locator("#editor-root .ProseMirror"), strong, " indeed");

    await expect(strong).toHaveText("strong emphasis indeed");

    const expectedEdited = [
      "# A heading with *emphasis* and a [link](https://example.com/heading)",
      "",
      "Body text with *emphasis*, **strong emphasis indeed**, and a [plain link](https://example.com/body) inside a paragraph.",
      "",
    ].join("\n");

    const serialized = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(parseSemanticMarkdown(serialized)).toEqual(
      parseSemanticMarkdown(expectedEdited),
    );

    await page.evaluate((md) => window.editorContract.loadMarkdown(md), serialized);
    await expect(page.locator("#editor-root p strong")).toHaveText(
      "strong emphasis indeed",
    );
    const reopened = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(parseSemanticMarkdown(reopened)).toEqual(
      parseSemanticMarkdown(expectedEdited),
    );
  });
});
