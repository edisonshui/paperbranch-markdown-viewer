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

function getOutline(): Array<{ id: string; text: string; level: number }> {
  const root = document.getElementById("editor-root");
  if (!root || blockedSource !== undefined) return [];
  return Array.from(root.querySelectorAll<HTMLElement>("h1, h2, h3, h4, h5, h6")).map((heading, index) => {
    const id = `heading-${index}`;
    heading.setAttribute("data-paperbranch-outline-id", id);
    return { id, text: heading.textContent?.trim() ?? "", level: Number(heading.tagName.slice(1)) };
  });
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

// The heading the reader is in: the last one at or above the top fifth of the Document view (Ticket 42).
function getCurrentOutlineID(): string | null {
  const root = document.getElementById("editor-root");
  if (!root || blockedSource !== undefined) return null;
  const headings = Array.from(root.querySelectorAll<HTMLElement>("h1, h2, h3, h4, h5, h6"));
  if (headings.length === 0) return null;
  const line = window.innerHeight / 5;
  let current = 0;
  headings.forEach((heading, index) => { if (heading.getBoundingClientRect().top <= line) current = index; });
  return `heading-${current}`;
}

function getReadingProgress(): number {
  const root = document.scrollingElement;
  if (!root || root.scrollHeight <= root.clientHeight) return 0;
  return Math.max(0, Math.min(1, root.scrollTop / (root.scrollHeight - root.clientHeight)));
}

function reportNavigation(): void {
  reportNavigationState({ outline: getOutline(), progress: getReadingProgress(), wordCount, currentOutlineID: getCurrentOutlineID() });
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

window.addEventListener("scroll", reportNavigation, { passive: true });

// Collapsing or reopening the Library sidebar changes the Document view's width, which can reflow the text above the
// reader. The block at the top of the view stays on the same line (Ticket 46).
let readingAnchor: { block: Element; top: number } | null = null;

function recordReadingAnchor(): void {
  // The first block whose top edge is in view: a block cut off at the top reflows too, so its top is no anchor.
  const blocks = Array.from(document.querySelectorAll("#editor-root .ProseMirror > *"));
  const block = blocks.find((candidate) => candidate.getBoundingClientRect().top >= 0);
  readingAnchor = block ? { block, top: block.getBoundingClientRect().top } : null;
}

window.addEventListener("scroll", recordReadingAnchor, { passive: true });
window.addEventListener("resize", () => {
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
