import { Editor, rootCtx, defaultValueCtx } from "@milkdown/kit/core";
import { commonmark } from "@milkdown/kit/preset/commonmark";
import { gfm } from "@milkdown/kit/preset/gfm";
import { getMarkdown } from "@milkdown/kit/utils";
import { history } from "@milkdown/kit/plugin/history";
import { listener, listenerCtx } from "@milkdown/kit/plugin/listener";
import "prosemirror-view/style/prosemirror.css";
import { taskListItemView } from "./task-list-item-view";
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

  if (admission.status === "blocked") {
    blockedSource = markdown;
    root.dataset.admission = "blocked";
    root.textContent = `Formatted editing is unavailable for this document (${admission.reasons.join(", ")}).`;
    return admission;
  }

  blockedSource = undefined;
  root.dataset.admission = "admitted";

  editor = await Editor.make()
    .config((ctx) => {
      ctx.set(rootCtx, root);
      ctx.set(defaultValueCtx, markdown);
      ctx.get(listenerCtx).markdownUpdated((_ctx, current) => {
        setDirty(current !== baseline);
        reportNavigation();
      });
    })
    .use(commonmark)
    .use(gfm)
    .use(taskListItemView)
    .use(history)
    .use(listener)
    .create();

  configureLocalImages();
  imageObserver.disconnect();
  imageObserver.observe(root, { childList: true, subtree: true });
  reportNavigation();

  return admission;
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

function getReadingProgress(): number {
  const root = document.scrollingElement;
  if (!root || root.scrollHeight <= root.clientHeight) return 0;
  return Math.max(0, Math.min(1, root.scrollTop / (root.scrollHeight - root.clientHeight)));
}

function reportNavigation(): void { reportNavigationState({ outline: getOutline(), progress: getReadingProgress() }); }

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
  isDirty: () => dirty,
};

window.addEventListener("scroll", reportNavigation, { passive: true });

installNativeBridge({
  loadDocument: loadMarkdown,
  getMarkdown: getMarkdownContent,
  isDirty: () => dirty,
  externalReplace,
  saveSucceeded,
  selectOutline,
});
