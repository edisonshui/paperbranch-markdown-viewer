import { expect, test } from "@playwright/test";

test("the reader footer follows a short document's last block instead of the window bottom", async ({ page }) => {
  await page.goto("/");
  const markdown = "# Note\n\nText.\n";
  await page.evaluate((source) => window.editorContract.loadMarkdown(source), markdown);

  const footer = page.locator("#document-footer");
  await expect(footer).toBeVisible();
  await expect(footer).toContainText("End of document");
  // The footer is reader chrome, so it stays out of the editor and its Markdown.
  expect(await footer.evaluate((el) => el.closest(".ProseMirror"))).toBeNull();
  expect(await page.evaluate(() => window.editorContract.getMarkdown())).toBe(markdown);

  const lastBlock = await page.locator("#editor-root .ProseMirror > :last-child").boundingBox();
  const footerBox = await footer.boundingBox();
  const viewport = page.viewportSize();
  expect(lastBlock && footerBox && viewport).toBeTruthy();
  expect(footerBox!.y).toBeGreaterThanOrEqual(lastBlock!.y + lastBlock!.height);
  expect(footerBox!.y - (lastBlock!.y + lastBlock!.height)).toBeLessThan(120);
  expect(footerBox!.y + footerBox!.height).toBeLessThan(viewport!.height - 100);
});

test("the reader footer scrolls with a long document and ends it", async ({ page }) => {
  await page.goto("/");
  await page.evaluate((source) => window.editorContract.loadMarkdown(source), `# Long\n\n${"A long readable paragraph.\n\n".repeat(200)}`);

  const footer = page.locator("#document-footer");
  await expect(footer).not.toBeInViewport();
  await page.evaluate(() => window.scrollTo(0, document.documentElement.scrollHeight));
  await expect(footer).toBeInViewport();

  const lastBlock = await page.locator("#editor-root .ProseMirror > :last-child").boundingBox();
  const footerBox = await footer.boundingBox();
  expect(footerBox!.y).toBeGreaterThanOrEqual(lastBlock!.y + lastBlock!.height);
});

test("a blocked document shows no reader footer", async ({ page }) => {
  await page.goto("/");
  await page.evaluate(() => window.editorContract.loadMarkdown("---\ntitle: Blocked\n---\n\nText.\n"));

  await expect(page.locator("#document-footer")).toBeHidden();
});
