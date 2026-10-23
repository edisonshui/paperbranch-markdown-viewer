import { test, expect, type Page } from "@playwright/test";

// Ticket 40: the Document view follows the macOS appearance and the design skill's "Document view" part.

const markdown = "# Reading slowly\n\nA paragraph with a [link](https://example.com) and `code`.\n\n> A quote.\n\n## Why the margin matters\n\nMore text.\n";

async function load(page: Page, colorScheme: "light" | "dark") {
  await page.emulateMedia({ colorScheme });
  await page.setViewportSize({ width: 1000, height: 700 });
  await page.goto("/");
  await page.evaluate((md) => window.editorContract.loadMarkdown(md), markdown);
}

const css = (page: Page, selector: string, properties: string[]) =>
  page.locator(selector).first().evaluate((el, properties) => properties.map((p) => getComputedStyle(el).getPropertyValue(p)), properties);

for (const [scheme, paper, ink, accentText, border] of [
  ["light", "rgb(255, 255, 255)", "rgb(29, 29, 31)", "rgb(29, 78, 216)", "rgb(221, 221, 225)"],
  ["dark", "rgb(28, 28, 30)", "rgb(230, 230, 232)", "rgb(126, 167, 245)", "rgb(58, 58, 64)"],
] as const) {
  test(`the Document view uses the ${scheme} tokens`, async ({ page }) => {
    await load(page, scheme);
    expect(await css(page, "body", ["background-color"])).toEqual([paper]);
    expect(await css(page, "#editor-root .ProseMirror", ["color"])).toEqual([ink]);
    expect(await css(page, "#editor-root a", ["color"])).toEqual([accentText]);
    expect(await css(page, "#editor-root p code", ["color"])).toEqual([accentText]);
    expect(await css(page, "#editor-root blockquote", ["border-left-width", "border-left-color", "font-style"])).toEqual(["2px", border, "italic"]);
  });
}

test("the column, type, and meta line follow the design skill", async ({ page }) => {
  await load(page, "light");
  const columnWidth = await page.locator("#editor-root").evaluate((el) => el.getBoundingClientRect().width);
  expect(columnWidth).toBe(680);
  const [size, lineHeight, family] = await css(page, "#editor-root .ProseMirror", ["font-size", "line-height", "font-family"]);
  expect([size, parseFloat(lineHeight).toFixed(1)]).toEqual(["19px", "32.3"]);
  expect(family).toContain("New York");
  expect(await css(page, "#editor-root h1", ["font-size", "text-align", "font-weight"])).toEqual(["40px", "start", "700"]);
  expect(await css(page, "#editor-root h2", ["font-size"])).toEqual(["27px"]);
  expect(await css(page, "#document-meta", ["text-transform", "text-align", "font-size"])).toEqual(["uppercase", "start", "11px"]);
  // The meta line sits above the title, aligned with the column's left edge.
  const [meta, title] = await Promise.all(["#document-meta", "#editor-root h1"].map((s) => page.locator(s).boundingBox()));
  expect(meta!.y + meta!.height).toBeLessThanOrEqual(title!.y);
  expect(Math.round(meta!.x)).toBe(Math.round(title!.x));
});

test("list items keep list spacing instead of paragraph spacing", async ({ page }) => {
  await load(page, "light");
  await page.evaluate(() => window.editorContract.loadMarkdown("- Keep the column narrow.\n- Let headings breathe.\n"));
  // Milkdown wraps each item's text in a paragraph, whose 16 px bottom margin made lists look loose.
  expect(await css(page, "#editor-root li p", ["margin-bottom"])).toEqual(["0px"]);
});
