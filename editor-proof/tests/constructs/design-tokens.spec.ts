import { test, expect } from "@playwright/test";

// Ticket 39: the Document view loads the design skill's tokens.css itself, so every value has one source.

test("the Document view resolves the design tokens", async ({ page }) => {
  await page.goto("/");
  const tokens = await page.evaluate(() => {
    const style = getComputedStyle(document.documentElement);
    return ["--measure", "--text-body", "--radius-l", "--duration-fast"].map((name) => style.getPropertyValue(name).trim());
  });
  expect(tokens).toEqual(["680px", "19px", "10px", "120ms"]);
});
