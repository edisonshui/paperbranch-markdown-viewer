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

// Proof tests: table alignment and escaped-pipe rendering/editing are
// Milkdown's own gfm-preset capability. Not a build-it-ourselves cycle.

test.describe("tables", () => {
  test("renders column alignment and an escaped pipe inside a cell", async ({
    page,
  }) => {
    await page.goto("/");
    const fixture = loadFixture("tables.md");
    await page.evaluate((md) => window.editorContract.loadMarkdown(md), fixture);

    const headerCells = page.locator("#editor-root table tr").first().locator("th");
    await expect(headerCells.nth(0)).toHaveCSS("text-align", "left");
    await expect(headerCells.nth(1)).toHaveCSS("text-align", "center");
    await expect(headerCells.nth(2)).toHaveCSS("text-align", "right");

    // The escaped pipe must render as a literal character inside one cell,
    // not split the row into an extra column.
    await expect(page.locator("#editor-root table tr").nth(1).locator("td")).toHaveCount(3);
    await expect(page.locator("#editor-root table tr").nth(1).locator("td").nth(1)).toHaveText(
      "b | c",
    );
  });

  test("editing a cell serializes with alignment and escaping preserved, and reopens the same", async ({
    page,
  }) => {
    await page.goto("/");
    const fixture = loadFixture("tables.md");
    await page.evaluate((md) => window.editorContract.loadMarkdown(md), fixture);

    const firstDataCell = page.locator("#editor-root table tr").nth(1).locator("td").first();
    // Target the cell's paragraph, not the <td> itself: collapsing a range
    // at the end of the <td> lands after its block child rather than at the
    // end of that child's text.
    await typeAtEndOf(
      page,
      page.locator("#editor-root .ProseMirror"),
      firstDataCell.locator("p"),
      " updated",
    );

    await expect(firstDataCell).toHaveText("a updated");

    const expectedEdited = [
      "| Left | Center | Right |",
      "| :--- | :----: | ----: |",
      "| a updated | b \\| c | d |",
      "| e | f | g |",
      "",
    ].join("\n");

    const serialized = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(parseSemanticMarkdown(serialized)).toEqual(
      parseSemanticMarkdown(expectedEdited),
    );

    await page.evaluate((md) => window.editorContract.loadMarkdown(md), serialized);
    await expect(
      page.locator("#editor-root table tr").nth(1).locator("td").first(),
    ).toHaveText("a updated");
    const reopened = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(parseSemanticMarkdown(reopened)).toEqual(
      parseSemanticMarkdown(expectedEdited),
    );
  });
});
