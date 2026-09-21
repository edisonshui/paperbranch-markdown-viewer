import { test, expect } from "@playwright/test";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { parseSemanticMarkdown } from "../support/semantic-markdown";
import { typeAfter } from "../support/editing";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function loadFixture(name: string): string {
  return readFileSync(path.join(__dirname, "..", "..", "fixtures", name), "utf-8");
}

// Proof tests: image rendering and preservation across edits is Milkdown's
// own capability. Not a build-it-ourselves cycle. Whether a relative image
// path actually resolves to a file is a native-bridge concern out of scope
// for this seam; here only the reference itself must survive.

test.describe("images", () => {
  test("renders a relative image with its title and an absolute image", async ({
    page,
  }) => {
    await page.goto("/");
    const fixture = loadFixture("images.md");
    await page.evaluate((md) => window.editorContract.loadMarkdown(md), fixture);

    const images = page.locator("#editor-root p > img:not(.ProseMirror-separator)");
    await expect(images).toHaveCount(2);
    await expect(images.nth(0)).toHaveAttribute("src", "./assets/diagram.png");
    await expect(images.nth(0)).toHaveAttribute("alt", "Relative diagram");
    await expect(images.nth(0)).toHaveAttribute("title", "Diagram title");
    await expect(images.nth(1)).toHaveAttribute("src", "https://example.com/photo.png");
    await expect(images.nth(1)).toHaveAttribute("alt", "Absolute photo");
  });

  test("text typed after an image is preserved alongside it through serialize and reopen", async ({
    page,
  }) => {
    await page.goto("/");
    const fixture = loadFixture("images.md");
    await page.evaluate((md) => window.editorContract.loadMarkdown(md), fixture);

    const firstParagraph = page.locator("#editor-root p").first();
    const image = page.locator("#editor-root p > img:not(.ProseMirror-separator)").first();
    await typeAfter(
      page,
      page.locator("#editor-root .ProseMirror"),
      image,
      " caption",
    );

    await expect(image).toHaveAttribute("src", "./assets/diagram.png");
    await expect(firstParagraph).toHaveText(" caption");

    // The official ProseMirror stylesheet preserves the plain space typed
    // after the atomic inline image node.
    const expectedEdited = [
      '![Relative diagram](./assets/diagram.png "Diagram title") caption',
      "",
      "![Absolute photo](https://example.com/photo.png)",
      "",
    ].join("\n");

    const serialized = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(parseSemanticMarkdown(serialized)).toEqual(
      parseSemanticMarkdown(expectedEdited),
    );

    await page.evaluate((md) => window.editorContract.loadMarkdown(md), serialized);
    await expect(
      page.locator("#editor-root p > img:not(.ProseMirror-separator)").first(),
    ).toHaveAttribute("src", "./assets/diagram.png");
    const reopened = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(parseSemanticMarkdown(reopened)).toEqual(
      parseSemanticMarkdown(expectedEdited),
    );
  });

  test("shows a clear broken-image state without blocking formatted editing", async ({ page }) => {
    await page.goto("/");
    await page.evaluate((md) => window.editorContract.loadMarkdown(md), "![missing](missing.png)\n\nStill editable.\n");

    const image = page.locator("#editor-root img:not(.ProseMirror-separator)");
    await expect(image).toHaveClass(/paperbranch-broken-image/);
    await expect(page.locator("#editor-root .ProseMirror")).toContainText("Still editable.");
  });
});
