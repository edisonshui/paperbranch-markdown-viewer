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

// Proof tests: fenced code block rendering/editing is Milkdown's own
// commonmark-preset capability. Not a build-it-ourselves cycle.

test.describe("fenced code blocks", () => {
  test("renders each block's language and keeps literal backticks as text", async ({
    page,
  }) => {
    await page.goto("/");
    const fixture = loadFixture("code-blocks.md");
    await page.evaluate((md) => window.editorContract.loadMarkdown(md), fixture);

    const blocks = page.locator("#editor-root pre");
    await expect(blocks).toHaveCount(2);
    await expect(blocks.nth(0)).toHaveAttribute("data-language", "js");
    await expect(blocks.nth(1)).toHaveAttribute("data-language", "markdown");
    await expect(blocks.nth(1).locator("code")).toHaveText(
      "Inline code with a literal backtick: `` ` ``",
    );
  });

  test("editing a code block serializes with its language and literal backticks preserved, and reopens the same", async ({
    page,
  }) => {
    await page.goto("/");
    const fixture = loadFixture("code-blocks.md");
    await page.evaluate((md) => window.editorContract.loadMarkdown(md), fixture);

    const jsCode = page.locator("#editor-root pre").nth(0).locator("code");
    await typeAtEndOf(page, page.locator("#editor-root .ProseMirror"), jsCode, "\nconsole.log(answer);");

    await expect(jsCode).toHaveText("const answer = 42;\nconsole.log(answer);");

    const expectedEdited = [
      "```js",
      "const answer = 42;",
      "console.log(answer);",
      "```",
      "",
      "```markdown",
      "Inline code with a literal backtick: `` ` ``",
      "```",
      "",
    ].join("\n");

    const serialized = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(parseSemanticMarkdown(serialized)).toEqual(
      parseSemanticMarkdown(expectedEdited),
    );

    await page.evaluate((md) => window.editorContract.loadMarkdown(md), serialized);
    await expect(page.locator("#editor-root pre").nth(0).locator("code")).toHaveText(
      "const answer = 42;\nconsole.log(answer);",
    );
    const reopened = await page.evaluate(() => window.editorContract.getMarkdown());
    expect(parseSemanticMarkdown(reopened)).toEqual(
      parseSemanticMarkdown(expectedEdited),
    );
  });
});
