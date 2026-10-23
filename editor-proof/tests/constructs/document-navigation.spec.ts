import { expect, test } from "@playwright/test";
import { placeCursorAtEnd, typeAtEndOf } from "../support/editing";

test("the Document view exposes ordered nested headings with distinct duplicate entries", async ({ page }) => {
  await page.goto("/");
  await page.evaluate((markdown) => window.editorContract.loadMarkdown(markdown), `# Introduction

## Details

### Deep detail

## Details
`);

  expect(await page.evaluate(() => window.editorContract.getOutline())).toEqual([
    { id: "heading-0", text: "Introduction", level: 1 },
    { id: "heading-1", text: "Details", level: 2 },
    { id: "heading-2", text: "Deep detail", level: 3 },
    { id: "heading-3", text: "Details", level: 2 },
  ]);
});

test("selecting a duplicate outline entry scrolls its corresponding formatted heading", async ({ page }) => {
  await page.goto("/");
  await page.evaluate((markdown) => window.editorContract.loadMarkdown(markdown), `# Repeat

${"paragraph\n\n".repeat(30)}

# Repeat
`);
  await page.evaluate(() => window.editorContract.getOutline());
  await page.evaluate(() => {
    (window.HTMLElement.prototype as HTMLElement & { scrollIntoView: () => void }).scrollIntoView = function () {
      document.body.setAttribute("data-scrolled-outline-id", this.getAttribute("data-paperbranch-outline-id") ?? "");
    };
  });

  expect(await page.evaluate(() => window.editorContract.selectOutline("heading-1"))).toBe(true);
  expect(await page.locator("body").getAttribute("data-scrolled-outline-id")).toBe("heading-1");
});

test("the outline updates after live heading additions, edits, and removals", async ({ page }) => {
  await page.goto("/");
  await page.evaluate((markdown) => window.editorContract.loadMarkdown(markdown), "# First\n\n# Remove me\n");

  const editor = page.locator("#editor-root .ProseMirror");
  const first = page.locator("#editor-root h1").nth(0);
  const removable = page.locator("#editor-root h1").nth(1);
  await typeAtEndOf(page, editor, first, " edited");
  await editor.evaluate((el) => (el as HTMLElement).focus());
  await placeCursorAtEnd(removable);
  await page.keyboard.press("Meta+Alt+0");
  await placeCursorAtEnd(first);
  await page.keyboard.press("Enter");
  await page.keyboard.type("Added heading");
  await page.keyboard.press("Meta+Alt+2");

  await expect.poll(() => page.evaluate(() => window.editorContract.getOutline())).toEqual([
    { id: "heading-0", text: "First edited", level: 1 },
    { id: "heading-1", text: "Added heading", level: 2 },
  ]);
});

test("reading progress follows long-document scroll position and documents without headings expose an empty outline", async ({ page }) => {
  await page.goto("/");
  await page.evaluate((markdown) => window.editorContract.loadMarkdown(markdown), `${"A long readable paragraph.\n\n".repeat(500)}`);

  expect(await page.evaluate(() => window.editorContract.getOutline())).toEqual([]);
  expect(await page.evaluate(() => window.editorContract.getReadingProgress())).toBe(0);

  await page.evaluate(() => window.scrollTo(0, document.documentElement.scrollHeight));
  await expect.poll(() => page.evaluate(() => window.editorContract.getReadingProgress())).toBeGreaterThan(0.99);
});

test("the current heading follows the reading position (Ticket 42)", async ({ page }) => {
  await page.setViewportSize({ width: 1000, height: 600 });
  await page.goto("/");
  const sections = Array.from({ length: 6 }, (_, i) => `## Part ${i + 1}\n\n${"A long paragraph that takes up room. ".repeat(40)}\n`).join("\n");
  await page.evaluate((md) => window.editorContract.loadMarkdown(md), `# Title\n\n${sections}`);
  expect(await page.evaluate(() => window.editorContract.getCurrentOutlineID())).toBe("heading-0");
  // Scroll Part 3 (heading-3) to the top of the Document view.
  await page.locator("#editor-root h2").nth(2).evaluate((h) => window.scrollTo(0, h.getBoundingClientRect().top + window.scrollY - 10));
  await expect.poll(() => page.evaluate(() => window.editorContract.getCurrentOutlineID())).toBe("heading-3");
});
