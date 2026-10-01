import { expect, test } from "@playwright/test";
import { typeAtEndOf } from "../support/editing";

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

test("the meta line above the document shows its word count and read time", async ({ page }) => {
  await page.goto("/");
  const markdown = "# Note\n\nOne *two* [three](https://example.com).\n";
  await page.evaluate((source) => window.editorContract.loadMarkdown(source), markdown);

  const meta = page.locator("#document-meta");
  await expect(meta.locator("span")).toHaveText(["4 words", "1 min read"]);
  expect(await meta.evaluate((el) => el.closest(".ProseMirror"))).toBeNull();
  expect(await page.evaluate(() => window.editorContract.getMarkdown())).toBe(markdown);

  const metaBox = await meta.boundingBox();
  const firstBlock = await page.locator("#editor-root .ProseMirror > :first-child").boundingBox();
  expect(metaBox!.y + metaBox!.height).toBeLessThanOrEqual(firstBlock!.y);
});

test("the meta line updates after an edit and after an external reload", async ({ page }) => {
  await page.goto("/");
  await page.evaluate(() => window.editorContract.loadMarkdown("# Note\n\nOne two.\n"));
  const meta = page.locator("#document-meta");
  await expect(meta.locator("span")).toHaveText(["3 words", "1 min read"]);

  const editor = page.locator("#editor-root .ProseMirror");
  await typeAtEndOf(page, editor, page.locator("#editor-root p").first(), " three four");
  await expect(meta.locator("span")).toHaveText(["5 words", "1 min read"]);

  // A clean document takes the external content, and 500 words is three minutes at 220 words a minute.
  await page.evaluate(() => window.editorContract.loadMarkdown("# Note\n\nSaved.\n"));
  expect(await page.evaluate((source) => window.paperbranchNativeBridge.externalReplace(source), `${"word ".repeat(500)}\n`)).toEqual({ applied: true });
  await expect(meta.locator("span")).toHaveText(["500 words", "3 min read"]);
});

test("a blocked document shows no meta line", async ({ page }) => {
  await page.goto("/");
  await page.evaluate(() => window.editorContract.loadMarkdown("---\ntitle: Blocked\n---\n\nText.\n"));

  await expect(page.locator("#document-meta")).toBeHidden();
});
