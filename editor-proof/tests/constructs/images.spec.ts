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
    await typeAtEndOf(
      page,
      page.locator("#editor-root .ProseMirror"),
      firstParagraph,
      " caption",
    );

    const image = page.locator("#editor-root p > img:not(.ProseMirror-separator)").first();
    await expect(image).toHaveAttribute("src", "./assets/diagram.png");
    await expect(firstParagraph).toHaveText(" caption");

    // Proof finding: a space typed immediately after an atomic inline node
    // (here, an image) becomes a non-breaking space (U+00A0), not a plain
    // space, since that is standard `contenteditable` behavior guarding
    // against the browser collapsing a space at a text/atomic-node boundary.
    // The visual result is the same; the serialized character is not.
    const expectedEdited = [
      '![Relative diagram](./assets/diagram.png "Diagram title") caption',
      "",
      "![Absolute photo](https://example.com/photo.png)",
      "",
    ].join("\n").replace(") caption", ") caption");

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
});
