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

// Proof tests: link-target escaping is Milkdown's own commonmark-preset
// capability. Not a build-it-ourselves cycle.

test.describe("links with parentheses and escaped characters", () => {
  test("renders a link whose target contains escaped parentheses", async ({ page }) => {
    await page.goto("/");
    const fixture = loadFixture("escaped-links.md");
    await page.evaluate((md) => window.editorContract.loadMarkdown(md), fixture);

    const link = page.locator("#editor-root a");
    await expect(link).toHaveText("design doc (draft)");
    await expect(link).toHaveAttribute(
      "href",
      "https://example.com/docs/design_(draft).pdf",
    );
  });

  test("editing the link text preserves the escaped target through serialize and reopen", async ({
    page,
  }) => {
    await page.goto("/");
    const fixture = loadFixture("escaped-links.md");
    await page.evaluate((md) => window.editorContract.loadMarkdown(md), fixture);

    const link = page.locator("#editor-root a");
    await typeAtEndOf(page, page.locator("#editor-root .ProseMirror"), link, " v2");

    await expect(link).toHaveText("design doc (draft) v2");
    await expect(link).toHaveAttribute(
      "href",
      "https://example.com/docs/design_(draft).pdf",
    );

    // The official ProseMirror stylesheet preserves the plain space typed
    // at the formatting boundary.
    const expectedEdited =
      "See the [design doc (draft) v2](https://example.com/docs/design_\\(draft\\).pdf) for details.\n";

    const serialized = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(parseSemanticMarkdown(serialized)).toEqual(
      parseSemanticMarkdown(expectedEdited),
    );

    await page.evaluate((md) => window.editorContract.loadMarkdown(md), serialized);
    await expect(page.locator("#editor-root a")).toHaveAttribute(
      "href",
      "https://example.com/docs/design_(draft).pdf",
    );
    const reopened = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(parseSemanticMarkdown(reopened)).toEqual(
      parseSemanticMarkdown(expectedEdited),
    );
  });
});
