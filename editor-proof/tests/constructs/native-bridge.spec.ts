import { test, expect } from "@playwright/test";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { typeAtEndOf } from "../support/editing";
import { parseSemanticMarkdown } from "../support/semantic-markdown";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function loadFixture(name: string): string {
  return readFileSync(path.join(__dirname, "..", "..", "fixtures", name), "utf-8");
}

// docs/specs/paperbranch-implementation.md ("Native and editor boundary")
// requires: the native layer sends content and requests a save; the editor
// reports dirty-state changes and returns serialized Markdown on request
// without writing a file; a clean external-content replacement loads the
// new content, a dirty one preserves the in-memory edits. These tests drive
// src/native-bridge.ts's JS-side surface (window.paperbranchNativeBridge)
// the same way the native WKWebView host does, via page.evaluate standing
// in for evaluateJavaScript, plus window.editorContract.isDirty() as an
// observability hook mirroring the dirtyStateChanged messages the bridge
// sends to native.

test.describe("native bridge: dirty state", () => {
  test("a fresh load is clean", async ({ page }) => {
    await page.goto("/");
    await page.evaluate(
      (md) => window.editorContract.loadMarkdown(md),
      loadFixture("headings.md"),
    );
    expect(await page.evaluate(() => window.editorContract.isDirty())).toBe(false);
  });

  test("an edit marks the document dirty", async ({ page }) => {
    await page.goto("/");
    await page.evaluate(
      (md) => window.editorContract.loadMarkdown(md),
      loadFixture("headings.md"),
    );

    const heading = page.locator("#editor-root h1");
    await typeAtEndOf(page, page.locator("#editor-root .ProseMirror"), heading, "!");

    await expect
      .poll(() => page.evaluate(() => window.editorContract.isDirty()))
      .toBe(true);
  });

  test("undoing back to the loaded content clears dirty state", async ({ page }) => {
    await page.goto("/");
    await page.evaluate(
      (md) => window.editorContract.loadMarkdown(md),
      loadFixture("headings.md"),
    );

    const heading = page.locator("#editor-root h1");
    await typeAtEndOf(page, page.locator("#editor-root .ProseMirror"), heading, "!");
    await expect
      .poll(() => page.evaluate(() => window.editorContract.isDirty()))
      .toBe(true);

    await page.locator("#editor-root .ProseMirror").focus();
    await page.keyboard.press("ControlOrMeta+z");

    await expect
      .poll(() => page.evaluate(() => window.editorContract.isDirty()))
      .toBe(false);
  });

  test("requestSave returns the current serialized Markdown without any file write", async ({
    page,
  }) => {
    await page.goto("/");
    const fixture = loadFixture("headings.md");
    await page.evaluate((md) => window.editorContract.loadMarkdown(md), fixture);

    const heading = page.locator("#editor-root h1");
    await typeAtEndOf(page, page.locator("#editor-root .ProseMirror"), heading, "!");

    // This is exactly the call the native host makes from its Command-S
    // handler (see native-host/README.md): a plain JS function call with a
    // return value, nothing that touches disk.
    const saved = await page.evaluate(() => window.paperbranchNativeBridge.requestSave());
    expect(saved).toContain("Top level heading!");
  });
});

test.describe("native bridge: external content replacement", () => {
  test("a clean document is replaced by an external-content message", async ({
    page,
  }) => {
    await page.goto("/");
    await page.evaluate(
      (md) => window.editorContract.loadMarkdown(md),
      loadFixture("headings.md"),
    );
    expect(await page.evaluate(() => window.editorContract.isDirty())).toBe(false);

    const replacement = loadFixture("lists.md");
    const result = await page.evaluate(
      (md) => window.paperbranchNativeBridge.externalReplace(md),
      replacement,
    );
    expect(result).toEqual({ applied: true });

    const current = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(parseSemanticMarkdown(current)).toEqual(parseSemanticMarkdown(replacement));
    expect(await page.evaluate(() => window.editorContract.isDirty())).toBe(false);
  });

  test("a dirty document preserves its in-memory content against an external-content message", async ({
    page,
  }) => {
    await page.goto("/");
    await page.evaluate(
      (md) => window.editorContract.loadMarkdown(md),
      loadFixture("headings.md"),
    );

    const heading = page.locator("#editor-root h1");
    await typeAtEndOf(page, page.locator("#editor-root .ProseMirror"), heading, "!!!");
    await expect
      .poll(() => page.evaluate(() => window.editorContract.isDirty()))
      .toBe(true);

    const dirtyContent = await page.evaluate(() => window.editorContract.getMarkdown());

    const result = await page.evaluate(
      (md) => window.paperbranchNativeBridge.externalReplace(md),
      loadFixture("lists.md"),
    );
    expect(result).toEqual({ applied: false });

    // The in-memory edit is untouched, not merged and not discarded.
    const current = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(current).toBe(dirtyContent);
    expect(current).toContain("Top level heading!!!");
    expect(await page.evaluate(() => window.editorContract.isDirty())).toBe(true);
  });

  test("an external-content message for a document requiring admission is blocked, not loaded, even when clean", async ({
    page,
  }) => {
    await page.goto("/");
    await page.evaluate(
      (md) => window.editorContract.loadMarkdown(md),
      loadFixture("headings.md"),
    );

    const result = await page.evaluate(
      (md) => window.paperbranchNativeBridge.externalReplace(md),
      loadFixture("unsupported-math.md"),
    );
    expect(result).toEqual({ applied: true });

    // "Applied" means the admission seam ran and decided; it still blocked
    // the unsafe content rather than loading it into Milkdown.
    await expect(page.locator("#editor-root .ProseMirror")).toHaveCount(0);
    await expect(page.locator("#editor-root")).toHaveAttribute(
      "data-admission",
      "blocked",
    );
  });
});
