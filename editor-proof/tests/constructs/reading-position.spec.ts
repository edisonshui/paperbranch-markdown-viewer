import { test, expect } from "@playwright/test";

// Ticket 46: collapsing or reopening the Library sidebar changes the Document view's width. The line at the top of
// the Document view stays there, even when the narrower column reflows the text above it.

test("a width change keeps the top visible block on the same line", async ({ page }) => {
  await page.setViewportSize({ width: 600, height: 700 });
  await page.goto("/");
  const paragraphs = Array.from({ length: 40 }, (_, i) => `Paragraph ${i + 1}. ${"Words that wrap across several lines in a narrow column. ".repeat(6)}`).join("\n\n");
  await page.evaluate((md) => window.editorContract.loadMarkdown(md), `# Title\n\n${paragraphs}\n`);
  const target = page.locator("#editor-root p").nth(20);
  await target.evaluate((p) => window.scrollTo(0, p.getBoundingClientRect().top + window.scrollY - 100));
  await page.waitForTimeout(100);
  const before = await target.evaluate((p) => p.getBoundingClientRect().top);

  await page.setViewportSize({ width: 1000, height: 700 });
  await expect.poll(() => target.evaluate((p) => Math.round(p.getBoundingClientRect().top))).toBe(Math.round(before));

  await page.setViewportSize({ width: 600, height: 700 });
  await expect.poll(() => target.evaluate((p) => Math.round(p.getBoundingClientRect().top))).toBe(Math.round(before));
});
