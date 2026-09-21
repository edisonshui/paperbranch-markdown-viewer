import { test, expect } from "@playwright/test";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { parseSemanticMarkdown } from "../support/semantic-markdown";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function loadFixture(name: string): string {
  return readFileSync(path.join(__dirname, "..", "..", "fixtures", name), "utf-8");
}

test.describe("task list", () => {
  test("renders each task item with its checked state", async ({ page }) => {
    // Proof test: rendering the checked/unchecked attribute is Milkdown's
    // existing gfm preset behavior.
    await page.goto("/");
    const fixture = loadFixture("task-list.md");
    await page.evaluate((md) => window.editorContract.loadMarkdown(md), fixture);

    const items = page.locator('#editor-root li[data-item-type="task"]');
    await expect(items).toHaveCount(3);
    await expect(items.nth(0)).toHaveAttribute("data-checked", "false");
    await expect(items.nth(1)).toHaveAttribute("data-checked", "true");
    await expect(items.nth(2)).toHaveAttribute("data-checked", "false");
  });

  test("clicking a task's checkbox toggles its state and serializes the change", async ({
    page,
  }) => {
    // This is new implementation: Milkdown's default gfm task item has no
    // interactive checkbox in its DOM, only a data-checked attribute, so
    // there is nothing to click yet. This is the true red half of this
    // slice.
    await page.goto("/");
    const fixture = loadFixture("task-list.md");
    await page.evaluate((md) => window.editorContract.loadMarkdown(md), fixture);

    const firstItem = page.locator('#editor-root li[data-item-type="task"]').nth(0);
    const checkbox = firstItem.locator('input[type="checkbox"]');
    await expect(checkbox).toBeChecked({ checked: false });

    await checkbox.click();

    await expect(checkbox).toBeChecked({ checked: true });
    await expect(firstItem).toHaveAttribute("data-checked", "true");

    const expectedEdited = [
      "* [x] Unchecked task",
      "* [x] Checked task",
      "* [ ] Another unchecked task",
      "",
    ].join("\n");

    const serialized = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(parseSemanticMarkdown(serialized)).toEqual(
      parseSemanticMarkdown(expectedEdited),
    );

    await page.evaluate((md) => window.editorContract.loadMarkdown(md), serialized);
    const reopenedItems = page.locator('#editor-root li[data-item-type="task"]');
    await expect(reopenedItems.nth(0)).toHaveAttribute("data-checked", "true");
    const reopened = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(parseSemanticMarkdown(reopened)).toEqual(
      parseSemanticMarkdown(expectedEdited),
    );
  });
});
