import type { AdmissionResult } from "./admission";

// The native/editor boundary for this proof, matching
// docs/specs/paperbranch-implementation.md ("Native and editor boundary"):
// the native layer sends document content and requests a save; the editor
// reports dirty-state changes and returns serialized Markdown on request;
// the native layer reports external reloads back to the editor. Nothing
// here exposes a file path, a file handle, or any operation broader than
// those four messages -- JavaScript cannot ask for anything the native
// host did not already decide to send.

export interface NativeBridgeHost {
  /** Native -> JS. Called once per document open, and again on any
   * external-content replacement. Runs the document through the
   * editor-admission seam exactly like a normal load. */
  loadMarkdown(markdown: string): Promise<AdmissionResult>;
  /** Native -> JS, in response to a save request. Never writes a file --
   * this proof's host only logs the returned string. */
  getMarkdown(): string;
  /** Whether the currently loaded document has unsaved edits. */
  isDirty(): boolean;
  /** Native -> JS. If the document is clean, replaces it with `markdown`
   * (through the same admission seam as loadMarkdown). If the document is
   * dirty, the in-memory content is preserved untouched and the message is
   * reported as not applied, for a later conflict flow to handle -- this
   * proof does not build that flow, only the preserve-vs-replace branch. */
  externalReplace(markdown: string): Promise<{ applied: boolean }>;
}

interface OutgoingMessage {
  type: "dirtyStateChanged";
  dirty: boolean;
}

function postToNative(message: OutgoingMessage): void {
  window.webkit?.messageHandlers?.paperbranch?.postMessage(message);
}

/** JS -> native. The editor calls this whenever its dirty state changes;
 * it does not push document content, only the boolean the native layer
 * needs to decide how to react to an external change or a close request. */
export function reportDirtyState(dirty: boolean): void {
  postToNative({ type: "dirtyStateChanged", dirty });
}

/** Installs the fixed, narrow surface the native host calls into. This is
 * the only thing `window` exposes for the native layer to drive -- no
 * generic eval hook, no file-system access. */
export function installNativeBridge(host: NativeBridgeHost): void {
  window.paperbranchNativeBridge = {
    requestSave: () => host.getMarkdown(),
    externalReplace: (markdown: string) => host.externalReplace(markdown),
  };
}
