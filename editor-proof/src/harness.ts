import { Editor, rootCtx, defaultValueCtx } from "@milkdown/kit/core";
import { commonmark } from "@milkdown/kit/preset/commonmark";
import { gfm } from "@milkdown/kit/preset/gfm";
import { getMarkdown } from "@milkdown/kit/utils";
import { history } from "@milkdown/kit/plugin/history";
import { listener, listenerCtx } from "@milkdown/kit/plugin/listener";
import "prosemirror-view/style/prosemirror.css";
import { taskListItemView } from "./task-list-item-view";
import { classifyMarkdown, type AdmissionResult } from "./admission";
import { installNativeBridge, reportDirtyState } from "./native-bridge";

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
      });
    })
    .use(commonmark)
    .use(gfm)
    .use(taskListItemView)
    .use(history)
    .use(listener)
    .create();

  return admission;
}

function getMarkdownContent(): string {
  if (blockedSource !== undefined) return blockedSource;
  if (!editor) throw new Error("loadMarkdown must run before getMarkdown");
  return editor.action(getMarkdown());
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
  isDirty: () => dirty,
};

installNativeBridge({
  loadDocument: loadMarkdown,
  getMarkdown: getMarkdownContent,
  isDirty: () => dirty,
  externalReplace,
  saveSucceeded,
});
