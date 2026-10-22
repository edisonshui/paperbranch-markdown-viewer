import { test, expect, type Page } from "@playwright/test";

// Ticket 36: selecting text shows a small popover that toggles link, bold, italic, strikethrough, and inline code.

const source = "# Note\n\nOne two three.\n";

/** Focuses the editor and selects `word` inside the first paragraph through the DOM selection, as a mouse drag would. */
async function selectWord(page: Page, word: string): Promise<void> {
  await page.locator("#editor-root .ProseMirror").focus();
  // ProseMirror writes its own selection back to the DOM shortly after focus, which would undo a selection set too early.
  await page.evaluate(() => new Promise<void>((resolve) => requestAnimationFrame(() => requestAnimationFrame(() => resolve()))));
  await page.locator("#editor-root p").first().evaluate((paragraph, word) => {
    const walker = document.createTreeWalker(paragraph, NodeFilter.SHOW_TEXT);
    for (let node = walker.nextNode(); node; node = walker.nextNode()) {
      const start = node.textContent?.indexOf(word) ?? -1;
      if (start < 0) continue;
      const range = document.createRange();
      range.setStart(node, start);
      range.setEnd(node, start + word.length);
      window.getSelection()?.removeAllRanges();
      window.getSelection()?.addRange(range);
      return;
    }
    throw new Error(`"${word}" is not in the paragraph`);
  }, word);
  await expect.poll(() => page.evaluate(() => String(window.getSelection()))).toBe(word);
}

async function load(page: Page, markdown = source): Promise<void> {
  await page.goto("/");
  await page.evaluate((md) => window.editorContract.loadMarkdown(md), markdown);
}

const popover = (page: Page) => page.locator("#formatting-popover");
const button = (page: Page, label: string) => popover(page).getByRole("button", { name: label, exact: true });

test("selecting text shows the popover centered 6 px above the selection without moving anything", async ({ page }) => {
  await load(page);
  const layout = () => page.evaluate(() => [
    document.getElementById("document")!.getBoundingClientRect().toJSON(),
    document.querySelector("#editor-root p")!.getBoundingClientRect().toJSON(),
    document.scrollingElement!.scrollHeight,
  ]);
  const before = await layout();
  await expect(popover(page)).toBeHidden();

  await selectWord(page, "two");
  await expect(popover(page)).toBeVisible();
  await expect(popover(page).getByRole("button")).toHaveText(["", "B", "I", "S", ""]);
  expect(await popover(page).getByRole("button").evaluateAll((buttons) => buttons.map((b) => b.getAttribute("aria-label")))).toEqual(["Link", "Bold", "Italic", "Strikethrough", "Inline code"]);
  await expect.poll(async () => {
    const [box, selection] = await page.evaluate(() => [
      document.getElementById("formatting-popover")!.getBoundingClientRect().toJSON(),
      window.getSelection()!.getRangeAt(0).getBoundingClientRect().toJSON(),
    ]);
    return [Math.round(selection.top - box.bottom), Math.round(box.left + box.width / 2 - (selection.left + selection.width / 2))];
  }).toEqual([6, 0]);

  // Nothing jumps: the article, the paragraph, and the page height stay where they were.
  expect(await layout()).toEqual(before);
  // The editor keeps focus.
  expect(await page.evaluate(() => document.activeElement?.classList.contains("ProseMirror"))).toBe(true);
});

for (const { label, markdown, element } of [
  { label: "Bold", markdown: "One **two** three.", element: "strong" },
  { label: "Italic", markdown: "One *two* three.", element: "em" },
  { label: "Strikethrough", markdown: "One ~~two~~ three.", element: "del" },
  { label: "Inline code", markdown: "One `two` three.", element: "code" },
]) {
  test(`${label} toggles its mark, shows it active, and round-trips through the saved Markdown`, async ({ page }) => {
    await load(page);
    await selectWord(page, "two");
    await expect(button(page, label)).toHaveAttribute("aria-pressed", "false");

    await button(page, label).click();
    await expect(page.locator(`#editor-root p ${element}`)).toHaveText("two");
    await expect(button(page, label)).toHaveAttribute("aria-pressed", "true");
    expect(await page.evaluate(() => document.activeElement?.classList.contains("ProseMirror"))).toBe(true);
    const saved = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(saved).toContain(markdown);

    await page.evaluate((md) => window.editorContract.loadMarkdown(md), saved);
    await expect(page.locator(`#editor-root p ${element}`)).toHaveText("two");
    await selectWord(page, "two");
    await expect(button(page, label)).toHaveAttribute("aria-pressed", "true");
    await button(page, label).click();
    await expect(page.locator(`#editor-root p ${element}`)).toHaveCount(0);
    expect(await page.evaluate(() => window.editorContract.getMarkdown())).toContain("One two three.");
  });
}

test("Link asks for a URL to add a link, and removes an existing link without asking", async ({ page }) => {
  await load(page);
  await selectWord(page, "two");
  page.once("dialog", (dialog) => dialog.accept("https://example.com"));
  await button(page, "Link").click();
  await expect(page.locator("#editor-root p a")).toHaveAttribute("href", "https://example.com");
  expect(await page.evaluate(() => window.editorContract.getMarkdown())).toContain("One [two](https://example.com) three.");

  await selectWord(page, "two");
  await expect(button(page, "Link")).toHaveAttribute("aria-pressed", "true");
  let asked = false;
  page.once("dialog", (dialog) => { asked = true; void dialog.dismiss(); });
  await button(page, "Link").click();
  await expect(page.locator("#editor-root p a")).toHaveCount(0);
  expect(asked).toBe(false);
});

test("a cancelled link prompt changes nothing", async ({ page }) => {
  await load(page);
  await selectWord(page, "two");
  page.once("dialog", (dialog) => dialog.dismiss());
  await button(page, "Link").click();
  await expect(page.locator("#editor-root p a")).toHaveCount(0);
  expect(await page.evaluate(() => window.editorContract.isDirty())).toBe(false);
});

test("the popover hides on Escape, when the selection collapses, and when the editor loses focus", async ({ page }) => {
  await load(page);
  await selectWord(page, "two");
  await expect(popover(page)).toBeVisible();
  await page.keyboard.press("Escape");
  await expect(popover(page)).toBeHidden();

  await selectWord(page, "three");
  await expect(popover(page)).toBeVisible();
  await page.keyboard.press("ArrowRight");
  await expect(popover(page)).toBeHidden();

  await selectWord(page, "One");
  await expect(popover(page)).toBeVisible();
  await page.locator("#editor-root .ProseMirror").evaluate((editor) => (editor as HTMLElement).blur());
  await expect(popover(page)).toBeHidden();
});

test("undo reverts a mark the popover applied", async ({ page }) => {
  await load(page);
  await selectWord(page, "two");
  await button(page, "Bold").click();
  await expect(page.locator("#editor-root p strong")).toHaveText("two");
  await page.keyboard.press("ControlOrMeta+z");
  await expect(page.locator("#editor-root p strong")).toHaveCount(0);
  await page.keyboard.press("ControlOrMeta+Shift+z");
  await expect(page.locator("#editor-root p strong")).toHaveText("two");
});

test("a blocked document never shows the popover", async ({ page }) => {
  await load(page);
  await selectWord(page, "two");
  await expect(popover(page)).toBeVisible();

  await page.evaluate(() => window.editorContract.loadMarkdown("---\ntitle: Blocked\n---\n\nOne two three.\n"));
  await expect(popover(page)).toBeHidden();
  await page.locator("#editor-root").evaluate((root) => {
    const range = document.createRange();
    range.selectNodeContents(root);
    window.getSelection()?.removeAllRanges();
    window.getSelection()?.addRange(range);
  });
  await page.waitForTimeout(300);
  await expect(popover(page)).toBeHidden();
});
