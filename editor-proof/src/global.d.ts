import type { AdmissionResult } from "./admission";

export interface EditorContract {
  loadMarkdown(markdown: string): Promise<AdmissionResult>;
  getMarkdown(): string;
  /** Test/observability hook mirroring the dirty state the native bridge
   * receives via `dirtyStateChanged` messages. */
  isDirty(): boolean;
}

export interface PaperbranchNativeBridge {
  requestSave(): string;
  externalReplace(markdown: string): Promise<{ applied: boolean }>;
}

declare global {
  interface Window {
    editorContract: EditorContract;
    paperbranchNativeBridge: PaperbranchNativeBridge;
    webkit?: {
      messageHandlers?: {
        paperbranch?: {
          postMessage(body: unknown): void;
        };
      };
    };
  }
}
