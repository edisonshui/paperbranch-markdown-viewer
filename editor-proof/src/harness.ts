import { Editor, rootCtx, defaultValueCtx, editorViewCtx } from "@milkdown/kit/core";
import type { Ctx } from "@milkdown/kit/ctx";
import { commonmark } from "@milkdown/kit/preset/commonmark";
import { gfm } from "@milkdown/kit/preset/gfm";
import { getMarkdown } from "@milkdown/kit/utils";
import { history } from "@milkdown/kit/plugin/history";
import { listener, listenerCtx } from "@milkdown/kit/plugin/listener";
import "prosemirror-view/style/prosemirror.css";
// The design skill's tokens are the single source of every value (Ticket 39). Vite bundles this file into the
// packaged editor and serves it in dev, so there is no copy to drift.
import "../../.claude/skills/paperbranch-design/tokens.css";
import { taskListItemView } from "./task-list-item-view";
import { configureFormattingPopover, formattingPopover } from "./formatting-popover";
import { classifyMarkdown, type AdmissionResult } from "./admission";
import { installNativeBridge, reportDirtyState, reportNavigationState } from "./native-bridge";

let editor: Editor | undefined;
// Set only while the currently loaded document is blocked. Its presence
// (rather than a boolean) also serves as the byte-for-byte source of truth
// getMarkdown() returns for a blocked document: it is never derived from
// Milkdown, because Milkdown never sees the document at all.
let blockedSource: string | undefined;
// The document as last loaded (by loadMarkdown or a clean externalReplace).
// Compared against the live serialized content to derive dirty state.
let baseline = "";
let dirty = false;
let imageObserver = new MutationObserver(() => configureLocalImages());

function nativeImageURL(reference: string): string {
  const bytes = new TextEncoder().encode(reference);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  const token = btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
  return `paperbranch-image://resource/${token}`;
}

function isRelativeImageReference(reference: string): boolean {
  return !/^(?:[a-z][a-z0-9+.-]*:|\/|#)/i.test(reference);
}

function configureLocalImages(): void {
  const root = document.getElementById("editor-root");
  if (!root) return;
  for (const image of root.querySelectorAll<HTMLImageElement>("img")) {
    const reference = image.dataset.paperbranchImageReference ?? image.getAttribute("src");
    if (!reference || !isRelativeImageReference(reference)) continue;
    image.dataset.paperbranchImageReference = reference;
    image.classList.add("paperbranch-local-image");
    // The proof page remains usable in an ordinary browser. In WebKit's
    // native host, use the scoped scheme rather than granting file access.
    if (window.webkit && image.getAttribute("src") !== nativeImageURL(reference)) {
      image.setAttribute("src", nativeImageURL(reference));
    }
  }
}

document.addEventListener("error", (event) => {
  const image = event.target;
  if (image instanceof HTMLImageElement && image.classList.contains("paperbranch-local-image")) {
    image.classList.add("paperbranch-broken-image");
    if (!image.alt) image.alt = "Image unavailable";
  }
}, true);

function setDirty(next: boolean): void {
  if (dirty === next) return;
  dirty = next;
  reportDirtyState(dirty);
}

async function loadMarkdown(markdown: string): Promise<AdmissionResult> {
  const admission = classifyMarkdown(markdown);

  if (editor) {
    await editor.destroy();
    editor = undefined;
  }

  const root = document.getElementById("editor-root");
  if (!root) throw new Error("editor-proof harness is missing #editor-root");
  root.innerHTML = "";

  baseline = markdown;
  setDirty(false);
  // Reader chrome frames a formatted document only. A blocked document shows just its notice.
  for (const id of ["document-meta", "document-footer"]) {
    const chrome = document.getElementById(id);
    if (chrome) chrome.hidden = admission.status === "blocked";
  }

  if (admission.status === "blocked") {
    blockedSource = markdown;
    root.dataset.admission = "blocked";
    root.textContent = `Formatted editing is unavailable for this document (${admission.reasons.join(", ")}).`;
    wordCount = null;
    reportNavigation();
    return admission;
  }

  blockedSource = undefined;
  root.dataset.admission = "admitted";

  editor = await Editor.make()
    .config((ctx) => {
      ctx.set(rootCtx, root);
      ctx.set(defaultValueCtx, markdown);
      ctx.get(listenerCtx).markdownUpdated((ctx, current) => {
        setDirty(current !== baseline);
        showDocumentStats(ctx);
        reportNavigation();
      });
      configureFormattingPopover(ctx);
    })
    .use(commonmark)
    .use(gfm)
    .use(taskListItemView)
    .use(history)
    .use(listener)
    .use(formattingPopover)
    .create();

  editor.action(showDocumentStats);
  configureLocalImages();
  imageObserver.disconnect();
  imageObserver.observe(root, { childList: true, subtree: true });
  reportNavigation();

  return admission;
}

// The Library sidebar's Open now card shows this same count, so the two never disagree.
let wordCount: number | null = null;

// Counts the words a reader sees, so link targets and Markdown syntax do not count. Variant B reads 220 words a minute.
function showDocumentStats(ctx: Ctx): void {
  const meta = document.getElementById("document-meta");
  if (!meta) return;
  const { doc } = ctx.get(editorViewCtx).state;
  const text = doc.textBetween(0, doc.content.size, " ", " ").trim();
  const words = text ? text.split(/\s+/).length : 0;
  wordCount = words;
  const minutes = Math.max(1, Math.ceil(words / 220));
  const item = (label: string) => Object.assign(document.createElement("span"), { textContent: label });
  // Grouped the way the Open now card's Swift formatting groups it, so "3,039 words" reads the same in both.
  meta.replaceChildren(item(`${words.toLocaleString()} ${words === 1 ? "word" : "words"}`), item(`${minutes} min read`));
}

function getMarkdownContent(): string {
  if (blockedSource !== undefined) return blockedSource;
  if (!editor) throw new Error("loadMarkdown must run before getMarkdown");
  return editor.action(getMarkdown());
}

// The outline and its headings, refreshed on load and on content change and never on scroll (Ticket 49).
let outlineHeadings: HTMLElement[] = [];
let outline: Array<{ id: string; text: string; level: number }> = [];

function readHeadings(): HTMLElement[] {
  const root = document.getElementById("editor-root");
  if (!root || blockedSource !== undefined) return [];
  return Array.from(root.querySelectorAll<HTMLElement>("h1, h2, h3, h4, h5, h6"));
}

function outlineEntries(headings: HTMLElement[]): Array<{ id: string; text: string; level: number }> {
  return headings.map((heading, index) => ({ id: `heading-${index}`, text: heading.textContent?.trim() ?? "", level: Number(heading.tagName.slice(1)) }));
}

// Content changed: rebuild the outline and tag each heading with its id, writing only attributes that differ.
function refreshOutline(): void {
  outlineHeadings = readHeadings();
  outline = outlineEntries(outlineHeadings);
  outlineHeadings.forEach((heading, index) => {
    const id = `heading-${index}`;
    if (heading.getAttribute("data-paperbranch-outline-id") !== id) heading.setAttribute("data-paperbranch-outline-id", id);
  });
}

// Reads the live headings without writing to them, for the editor contract.
function getOutline(): Array<{ id: string; text: string; level: number }> {
  return outlineEntries(readHeadings());
}

function selectOutline(id: string): boolean {
  const root = document.getElementById("editor-root");
  const headings = root ? Array.from(root.querySelectorAll<HTMLElement>("h1, h2, h3, h4, h5, h6")) : [];
  const heading = headings[Number(id.replace("heading-", ""))];
  if (!heading) return false;
  heading.setAttribute("data-paperbranch-outline-id", id);
  heading.scrollIntoView({ block: "start", behavior: "smooth" });
  return true;
}

// Index of the first element whose top is below `threshold`, found by binary search: headings and blocks sit in
// document order, so their tops increase and each frame reads O(log n) positions.
function firstIndexWithTopAbove(elements: Element[], threshold: number): number {
  let low = 0;
  let high = elements.length;
  while (low < high) {
    const middle = (low + high) >> 1;
    if (elements[middle].getBoundingClientRect().top > threshold) high = middle; else low = middle + 1;
  }
  return low;
}

// The heading the reader is in: the last one at or above the top fifth of the Document view (Ticket 42).
function getCurrentOutlineID(): string | null {
  const headings = outlineHeadings.length > 0 && outlineHeadings[0].isConnected ? outlineHeadings : readHeadings();
  if (headings.length === 0) return null;
  const current = Math.max(0, firstIndexWithTopAbove(headings, window.innerHeight / 5) - 1);
  return `heading-${current}`;
}

function getReadingProgress(): number {
  const root = document.scrollingElement;
  if (!root || root.scrollHeight <= root.clientHeight) return 0;
  return Math.max(0, Math.min(1, root.scrollTop / (root.scrollHeight - root.clientHeight)));
}

// The current heading native code last heard about, so scrolling reports only changes.
let reportedOutlineID: string | null | undefined;

// Content changed or a document loaded: send the whole navigation state.
function reportNavigation(): void {
  refreshOutline();
  reportedOutlineID = getCurrentOutlineID();
  reportNavigationState({ outline, progress: getReadingProgress(), wordCount, currentOutlineID: reportedOutlineID });
  scheduleScrollFrame();
}

async function externalReplace(markdown: string): Promise<{ applied: boolean }> {
  if (dirty) return { applied: false };
  await loadMarkdown(markdown);
  return { applied: true };
}

// Native calls this only after its coordinated write has completed. Keeping
// the baseline here makes a failed write visibly dirty instead of pretending
// that serialization alone saved the document.
function saveSucceeded(markdown: string): void {
  baseline = markdown;
  setDirty(false);
}

window.editorContract = {
  loadMarkdown,
  getMarkdown: getMarkdownContent,
  getOutline,
  selectOutline,
  getReadingProgress,
  getCurrentOutlineID,
  isDirty: () => dirty,
};

// Collapsing or reopening the Library sidebar changes the Document view's width, which can reflow the text above the
// reader. The block at the top of the view stays on the same line (Ticket 46).
let readingAnchor: { block: Element; top: number } | null = null;

function recordReadingAnchor(): void {
  // The first block whose top edge is in view: a block cut off at the top reflows too, so its top is no anchor.
  const blocks = Array.from(document.querySelectorAll("#editor-root .ProseMirror > *"));
  const block = blocks[firstIndexWithTopAbove(blocks, -0.5)];
  readingAnchor = block ? { block, top: block.getBoundingClientRect().top } : null;
}

// The reading progress line lives in the Document view (Ticket 49): moving it never re-renders the native chrome.
let shownProgressPercent = -1;

function drawReadingProgress(progress: number): void {
  const line = document.getElementById("reading-progress");
  if (!line) return;
  line.style.transform = `scaleX(${progress})`;
  const percent = Math.round(progress * 100);
  if (percent !== shownProgressPercent) {
    shownProgressPercent = percent;
    line.setAttribute("aria-valuenow", String(percent));
  }
}

// All scroll work runs in one animation frame callback (Ticket 49): it reads layout first, then writes only the
// progress line, and tells native code only when the current heading changes.
let scrollFrame = 0;

function scheduleScrollFrame(): void {
  if (scrollFrame === 0) scrollFrame = requestAnimationFrame(runScrollFrame);
}

function runScrollFrame(): void {
  scrollFrame = 0;
  const progress = getReadingProgress();
  const currentOutlineID = getCurrentOutlineID();
  recordReadingAnchor();
  drawReadingProgress(progress);
  if (currentOutlineID !== reportedOutlineID) {
    reportedOutlineID = currentOutlineID;
    reportNavigationState({ outline, progress, wordCount, currentOutlineID });
  }
}

window.addEventListener("scroll", scheduleScrollFrame, { passive: true });
window.addEventListener("resize", () => {
  scheduleScrollFrame();
  if (!readingAnchor?.block.isConnected || window.scrollY === 0) return;
  const drift = readingAnchor.block.getBoundingClientRect().top - readingAnchor.top;
  if (Math.abs(drift) >= 1) window.scrollBy(0, drift);
});

installNativeBridge({
  loadDocument: loadMarkdown,
  getMarkdown: getMarkdownContent,
  isDirty: () => dirty,
  externalReplace,
  saveSucceeded,
  selectOutline,
});
