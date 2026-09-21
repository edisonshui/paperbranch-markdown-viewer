import type { Locator, Page } from "@playwright/test";

/**
 * Collapses the browser selection to the end of `locator`'s own text,
 * using the DOM Selection/Range API (not Milkdown/ProseMirror internals).
 * Needed whenever "End" would otherwise run to the end of the surrounding
 * block instead of the end of an inline mark or nested element.
 */
export async function placeCursorAtEnd(locator: Locator): Promise<void> {
  await locator.evaluate((el) => {
    const range = document.createRange();
    range.selectNodeContents(el);
    range.collapse(false);
    const selection = window.getSelection();
    selection?.removeAllRanges();
    selection?.addRange(range);
    // ProseMirror syncs its internal selection from the DOM's
    // `selectionchange` event asynchronously. Without waiting a frame here,
    // a following keyboard.type can race ahead of that sync and land at the
    // previous cursor position instead.
    return new Promise<void>((resolve) => requestAnimationFrame(() => resolve()));
  });
}

/**
 * Focuses the editor, collapses the selection to the end of `target`'s own
 * text, and types `text` there.
 *
 * Clicking `target` and then immediately overriding the selection is racy:
 * ProseMirror resolves its own selection from the click asynchronously and
 * can clobber our override afterwards. Using `.focus()` instead of a mouse
 * click avoids that race, since it does not go through ProseMirror's
 * pointer-event selection handling.
 */
/**
 * Focuses the editor, collapses the selection to the end of `target`, and
 * dispatches a synthetic clipboard paste event there with the given
 * clipboard payloads. Mirrors what a real paste delivers: a browser paste
 * usually carries both `text/html` and `text/plain`; a plain-text source
 * (e.g. another Markdown editor) usually carries only `text/plain`.
 */
export async function pasteAtEndOf(
  editorRoot: Locator,
  target: Locator,
  clipboard: { html?: string; text?: string },
): Promise<void> {
  await editorRoot.evaluate((el) => (el as HTMLElement).focus());
  await placeCursorAtEnd(target);
  await editorRoot.evaluate((el, { html, text }) => {
    const dataTransfer = new DataTransfer();
    if (html != null) dataTransfer.setData("text/html", html);
    if (text != null) dataTransfer.setData("text/plain", text);
    const event = new ClipboardEvent("paste", {
      clipboardData: dataTransfer,
      bubbles: true,
      cancelable: true,
    });
    el.dispatchEvent(event);
  }, clipboard);
}

export async function typeAtEndOf(
  page: Page,
  editorRoot: Locator,
  target: Locator,
  text: string,
): Promise<void> {
  await editorRoot.evaluate((el) => (el as HTMLElement).focus());
  await placeCursorAtEnd(target);
  await page.keyboard.type(text);
}
