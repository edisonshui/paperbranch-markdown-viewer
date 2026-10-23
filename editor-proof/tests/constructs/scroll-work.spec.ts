import { test, expect, type Page } from "@playwright/test";

// Ticket 49: scrolling must stay light. All scroll work runs once per animation frame, reads layout without writing
// to headings, and talks to native only when the current heading changes. The reading progress line is drawn by the
// Document view itself, so moving it never re-renders the native chrome.

declare global { interface Window { __messages: Array<{ type: string; currentOutlineID?: string | null; progress?: number }>; } }

test.beforeEach(async ({ page }) => {
  // Stands in for WKWebView's message handler, recording what the editor would send to native code.
  await page.addInitScript(() => {
    window.__messages = [];
    (window as unknown as { webkit: unknown }).webkit = {
      messageHandlers: { paperbranch: { postMessage: (message: unknown) => window.__messages.push(JSON.parse(JSON.stringify(message))) } },
    };
  });
});

async function loadLongDocument(page: Page): Promise<void> {
  await page.setViewportSize({ width: 1000, height: 700 });
  await page.goto("/");
  const sections = Array.from({ length: 30 }, (_, i) => `## Part ${i + 1}\n\n${"A paragraph long enough to take some room on the page. ".repeat(12)}\n`).join("\n");
  await page.evaluate((md) => window.editorContract.loadMarkdown(md), `# Long report\n\n${sections}`);
}

test("scrolling sends navigation at most once per frame, only when the current heading changes, and writes no heading attributes", async ({ page }) => {
  await loadLongDocument(page);
  const frames = 120;
  const result = await page.evaluate(async (frames) => {
    const headings = document.querySelectorAll("#editor-root h1, #editor-root h2");
    let headingWrites = 0;
    const observer = new MutationObserver((records) => {
      headingWrites += records.filter((r) => r.type === "attributes" && (r.target as Element).matches("h1, h2, h3, h4, h5, h6")).length;
    });
    observer.observe(document.getElementById("editor-root")!, { attributes: true, subtree: true });
    window.__messages = [];
    for (let i = 0; i < frames; i++) {
      // Two scroll events per frame, as a trackpad often delivers.
      window.scrollBy(0, 20);
      window.dispatchEvent(new Event("scroll"));
      window.scrollBy(0, 20);
      await new Promise((resolve) => requestAnimationFrame(resolve));
    }
    await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    observer.disconnect();
    const navigation = window.__messages.filter((m) => m.type === "navigationStateChanged");
    return { headingCount: headings.length, headingWrites, navigation: navigation.map((m) => m.currentOutlineID) };
  }, frames);

  console.log(`Ticket 49 measure: ${result.navigation.length} navigation messages and ${result.headingWrites} heading attribute writes over ${frames} frames (${result.headingCount} headings)`);
  expect(result.navigation.length).toBeLessThanOrEqual(frames);
  // Each message reports a new current heading.
  result.navigation.forEach((id, index) => { if (index > 0) expect(id).not.toBe(result.navigation[index - 1]); });
  expect(result.navigation.length).toBeLessThanOrEqual(result.headingCount);
  expect(result.headingWrites).toBe(0);
});

for (const [scheme, accent] of [["light", "rgb(37, 99, 235)"], ["dark", "rgb(91, 141, 239)"]] as const) {
  test(`the reading progress line is a 2 px --accent bar at the top of the Document view (${scheme})`, async ({ page }) => {
    await page.emulateMedia({ colorScheme: scheme });
    await loadLongDocument(page);
    const line = page.getByRole("progressbar", { name: "Reading progress" });
    await expect(line).toHaveAttribute("aria-valuenow", "0");
    const style = await line.evaluate((el) => {
      const s = getComputedStyle(el);
      return [s.position, s.top, s.left, s.height, s.backgroundColor];
    });
    expect(style).toEqual(["fixed", "0px", "0px", "2px", accent]);

    await page.evaluate(() => window.scrollTo(0, document.documentElement.scrollHeight));
    await expect(line).toHaveAttribute("aria-valuenow", "100");
    expect(await line.evaluate((el) => getComputedStyle(el).transform)).toBe("matrix(1, 0, 0, 1, 0, 0)");
  });
}
