# Paperbranch implementation specification

## Problem statement

Reading a local Markdown document usually means choosing between a source editor and a browser-style preview. The source editor exposes Markdown syntax while the preview cannot edit the document. Neither supports a focused reading experience that also allows direct editing.

Paperbranch needs to provide that experience for one person's files on a Mac. It must remember a folder-based Library, open Markdown documents from Finder, save changes to the original files, and react safely when another program changes an open document. The first version does not need collaboration, cloud storage, public distribution, or exact preservation of equivalent Markdown syntax.

## Solution

Build Paperbranch as a personal macOS application with one Library window and separate Standalone windows. The Library window restores one chosen Library, mirrors its folder hierarchy in a collapsible sidebar, and opens the selected Markdown document in a Document view. A Markdown document opened through Finder outside the Library opens in its own Standalone window.

The Document view renders Markdown as formatted content and allows direct editing. Paperbranch saves only when the user presses `Command-S`. It may normalize Markdown syntax during serialization as long as it preserves the document's meaning. It automatically reloads a clean document after an external change. If the document has unsaved edits, it preserves those edits and asks the user how to resolve the conflict.

The [Variant B HTML prototype](../../index.html?variant=B) is the primary source for the product's visual design. Implementation should reproduce that variant's layout and interactions while applying the Paperbranch name and the behavior in this specification. The prototype is not the source of truth for file access, saving, editing, or application architecture.

## User stories

1. As a first-time user, I want to choose a folder as my Library, so that Paperbranch can display my Markdown collection.
2. As a returning user, I want Paperbranch to restore my chosen Library at launch, so that I do not have to select it again.
3. As a user, I want the Library sidebar to mirror the Library's nested folder hierarchy, so that the organization on disk remains familiar.
4. As a user, I want the Library to include `.md` and `.markdown` files, so that both common Markdown extensions work.
5. As a user, I want to select a Markdown document in the sidebar, so that it opens in the Library window's Document view.
6. As a user, I want folders in the sidebar to expand and collapse, so that I can navigate a large Library.
7. As a user, I want the entire Library sidebar to collapse and reopen, so that I can concentrate on the current document.
8. As a user, I want the selected document and relevant sidebar state to remain clear, so that I know which file I am editing.
9. As a user, I want to read a document as formatted content, so that Markdown syntax does not distract from the document.
10. As a user, I want to edit the formatted content directly, so that I do not need a raw source mode or split view.
11. As a user, I want headings, emphasis, lists, links, images, block quotes, fenced code blocks, tables, task lists, and strikethrough to render and remain editable, so that Paperbranch supports the Markdown I use.
12. As a user, I want relative image references to resolve from the document's folder, so that local images appear without changing my files.
13. As a user, I want normal editing actions such as selection, paste, undo, and redo to work in the Document view, so that editing follows Mac conventions.
14. As a user, I want `Command-S` to save while focus is inside the Document view, so that saving does not depend on which part of the window is active.
15. As a user, I want Paperbranch to write changes only after I press `Command-S`, so that viewing or editing does not change a file unexpectedly.
16. As a user, I want Paperbranch to show whether the current document has unsaved edits, so that I know when a save is needed.
17. As a user, I want a saved document to preserve its meaning even if Paperbranch standardizes whitespace or equivalent Markdown syntax, so that editing does not lose supported content.
18. As a user, I want to open a Markdown document through Finder, so that Paperbranch works as a normal Mac document application.
19. As a user, I want a Finder-opened document that belongs to the Library to open in the Library window, so that the same file does not appear in two editing contexts.
20. As a user, I want a Finder-opened document outside the Library to open in a Standalone window, so that I can edit it without adding it to the Library.
21. As a user, I want each outside document to remain a Standalone document, so that opening it does not alter the Library.
22. As a user, I want separate Standalone documents to use separate windows, so that each one behaves like an independent Mac document.
23. As a user, I want Paperbranch to focus a document's existing window when I open the same file again, so that two windows cannot make conflicting edits to one file.
24. As a user, I want a clean Document view to reload when another program changes its file, so that I see the latest contents.
25. As a user, I want Paperbranch to retain my unsaved edits when another program changes the file, so that external changes cannot silently discard my work.
26. As a user, I want Paperbranch to tell me when my unsaved edits conflict with an external change, so that I can choose which version to continue with.
27. As a user, I want to reload the external version or keep my in-memory edits after a conflict, so that I control the resolution.
28. As a user, I want Paperbranch to warn me before a later save overwrites a version that changed externally, so that keeping my edits does not cause a silent overwrite.
29. As a user, I want a clear state when the Library is unavailable or a document has moved or been deleted, so that I can reconnect the Library or choose another document without losing unrelated work.
30. As a user, I want my documents to stay on my Mac, so that Paperbranch does not require an account, server, or internet connection.

## Implementation decisions

### Visual source of truth

Use [Variant B of the HTML prototype](../../index.html?variant=B) as the visual source of truth. Reproduce its Library and reading layout, collapsible sidebar behavior, visual hierarchy, and window states. Replace the prototype's Folio branding with Paperbranch. Exclude the prototype switcher, demo content, browser file picker, and any behavior belonging to Variants A or C.

The prototype defines appearance and interaction intent. This specification and the accepted architecture decisions define product behavior.

### Application architecture

Use a native SwiftUI and AppKit application shell with a WebKit-based Document view. The native layer owns file access, Library persistence, directory enumeration, windows, Finder open events, commands, saving, external-change monitoring, and conflict state. The web editor owns formatted Markdown display, editing state, selection, undo and redo, parsing, and serialization.

Use Milkdown with its CommonMark and GitHub Flavored Markdown support for the first editor proof. Do not make Milkdown a permanent architecture decision until it passes the Markdown editor test seam described below. If it fails, test TOAST UI Editor inside the same native shell before reconsidering the application architecture.

The first implementation phase is the editor proof. Application implementation can proceed after the proof shows that the chosen editor preserves the meaning of every supported Markdown construct and supports the required editing actions.

### Native and editor boundary

Keep the bridge between Swift and the editor small. The native layer sends a document identifier and Markdown content to the editor. The editor reports dirty-state changes and returns serialized Markdown when the native layer requests a save. The native layer reports successful saves, safe external reloads, and conflicts back to the editor.

JavaScript must not receive unrestricted file-system access or decide which paths it may read or write. The native layer remains the authority for document identity, Library membership, file access, and writes.

### Library access and restoration

The user chooses one folder as the Library. Persist access with a security-scoped bookmark so the same design can support sandboxed distribution later. Restore the bookmark at launch, verify that it still resolves, and show a reconnect flow if it does not.

Enumerate the Library recursively and preserve its relative folder hierarchy in the sidebar. Include regular files whose extensions are `.md` or `.markdown`, using case-insensitive extension matching. Do not copy, import, rename, reorganize, or delete files in the first version.

Refresh the Library when relevant directory contents change. Preserve the selected document and expanded folder state when those items still exist.

### Documents and windows

Represent each open document as one document session. A session tracks the canonical file identity, whether the document belongs to the Library or is Standalone, its associated window, the last content loaded from disk, its current dirty state, and any unresolved external change.

Maintain one Library window. A Library document opens in that window even when Finder initiated the open. A document outside the Library opens in its own Standalone window and is not added to the Library. Reopening an already open file focuses its existing window instead of creating another session.

Register Paperbranch as an editor for `.md` and `.markdown` documents so Finder can send open events to a stopped or running application.

### Formatted editing and Markdown

The Document view has one formatted editing mode. Do not add raw Markdown editing, a source and preview split, or a read-only mode toggle.

Support CommonMark plus the required GitHub Flavored Markdown constructs: tables, task lists, and strikethrough. Also support images and fenced code block language identifiers. Equivalent Markdown syntax may change after a save. The editor must preserve the parsed meaning of supported content.

Resolve relative images against the Markdown document's containing folder. Route image reads through a narrowly scoped native handler that validates the resolved path before returning file data. Do not grant the editor general access to the Library or arbitrary local files.

Raw HTML, front matter, footnotes, mathematical notation, Mermaid diagrams, and plugin-defined Markdown are not supported in the first version. Paperbranch must avoid silently converting an unsupported construct into different supported content. The editor proof must determine whether unsupported source remains intact, becomes visible as plain content, or blocks formatted editing. Record that result before implementation proceeds.

### Saving and dirty state

Mark a document dirty after an editor transaction changes its serialized Markdown from the last saved version. Do not write changes during typing, when switching documents, or on a timer.

Route `Command-S` through the native command system even when the WebKit editor has focus. Before writing, serialize the editor state and verify that the file still matches the disk version associated with the session. Write through coordinated macOS file access. After a successful write, update the session's disk version and clear its dirty state.

If serialization or writing fails, keep the document dirty and show an error that identifies the affected document. Never report a successful save before the coordinated write finishes.

### External changes and conflicts

Monitor each open document for external replacement, modification, movement, or deletion. Re-read and compare file content rather than treating every file-system notification as a meaningful change. Ignore notifications caused by Paperbranch's own completed save.

If an external change arrives while the document is clean, load the new Markdown into the existing document session and keep the current window context. If the document is dirty, retain the in-memory version and enter a conflict state. Offer two initial actions: reload the disk version and discard the in-memory edits, or keep editing the in-memory version.

Keeping the in-memory version does not authorize an automatic overwrite. A later save must compare against the external version again and require explicit confirmation before replacing it. Closing a dirty or conflicted window must use the standard unsaved-change confirmation flow.

### Packaging and distribution

Build a normal macOS application bundle through Xcode. The current product is a personal local build for one Mac. It does not need code signing, notarization, an installer, an update service, telemetry, or a release channel.

Do not add Sparkle or another updater in the first version. If direct public distribution becomes a requirement, add Developer ID signing, the hardened runtime, notarization, and an update mechanism as a separate project. If Mac App Store distribution becomes a requirement, validate Library bookmark restoration in a sandboxed release build.

## Testing decisions

### Test seam 1: application workflows

Test the application through user-visible commands and real temporary files and folders. These tests should launch the application in a controlled environment, choose or restore a temporary Library, drive window and editing actions, and inspect visible application state and file contents on disk.

Cover at least these workflows:

1. Choosing and restoring a nested Library.
2. Selecting Library documents and preserving the folder hierarchy.
3. Collapsing and reopening the Library sidebar.
4. Opening Library and outside documents through simulated Finder open events.
5. Reusing an existing window for an already open file.
6. Editing without writing until `Command-S`.
7. Saving while the Document view has focus.
8. Reloading an external change when the document is clean.
9. Preserving local edits and entering conflict state when the document is dirty.
10. Preventing a silent overwrite after the user keeps an in-memory conflicted version.
11. Handling an unavailable Library and a moved or deleted open document.

Assertions should cover observable window state, document content, dirty or conflict indicators, prompts, and bytes written to disk. Avoid assertions about private Swift types, internal message names, or framework-specific implementation details.

### Test seam 2: Markdown editor contract

Test the editor as a contract that accepts Markdown, exposes formatted editing actions, and returns Markdown. Use a checked-in fixture collection that covers every supported construct and difficult combinations of those constructs.

For each fixture, load the Markdown, perform a representative edit, serialize it, parse the result again, and compare semantic document structure rather than exact source text. Reopen the serialized result to confirm that a second load preserves the same structure.

The fixture collection must cover:

1. Nested headings, emphasis, and links.
2. Ordered, unordered, nested, and mixed lists.
3. Task items and task-state changes.
4. Tables with alignment and escaped pipe characters.
5. Fenced code blocks with language identifiers and literal backticks.
6. Relative and absolute image references.
7. Links containing parentheses and escaped characters.
8. Block quotes containing other supported blocks.
9. Strikethrough mixed with other inline formatting.
10. Paste from a browser and another Markdown editor.
11. Undo and redo across structural edits.
12. Save requests while the editor has focus.
13. Clean and dirty external-content replacement messages.
14. Unsupported constructs identified during the proof.

Milkdown passes the proof only if it preserves the semantic structure of all supported fixtures, provides usable direct editing for the required block types, and does not silently corrupt unsupported input. Record failures and repeat the same contract suite against TOAST UI Editor if needed.

### Visual verification

Compare the Library window against the [Variant B HTML prototype](../../index.html?variant=B) at representative window sizes. Verify the expanded sidebar, collapsed sidebar, selected document, long document, empty Library, missing Library, dirty document, and conflict states. The prototype remains the comparison source, so tests should not duplicate its dimensions, colors, or typography as prose assertions.

### Existing test infrastructure

The repository contains a throwaway HTML prototype and planning documents but no application code or test framework. There is no existing test pattern to preserve. Choose the native application test tools and browser-editor test runner during project setup, while keeping the two agreed test seams intact.

## Out of scope

- Windows, Linux, iPhone, iPad, and web versions.
- Multiple Libraries or Library tabs.
- Cloud sync, accounts, collaboration, comments, or sharing.
- Creating, renaming, moving, or deleting files and folders from the Library sidebar.
- Raw Markdown source editing or a split source and preview layout.
- Exact preservation of whitespace, list markers, or other equivalent Markdown syntax.
- Raw HTML, front matter, footnotes, mathematical notation, Mermaid diagrams, and plugin systems.
- Search, tags, backlinks, graph views, and document databases.
- Automatic saving or scheduled saving.
- Version history, automatic conflict merging, or cloud-style conflict copies.
- Public distribution, signing, notarization, an installer, the Mac App Store, or automatic updates.
- Tauri, Electron, and a custom TextKit Markdown editor unless the editor proof invalidates the recommended architecture.

## Further notes

The following sources form the decision record for this specification:

- [Visual prototype, Variant B](../../index.html?variant=B). This is the primary source for appearance and visual interaction.
- [Project context and glossary](../../CONTEXT.md). This defines the canonical product name and terms.
- [ADR 0001: Use a Library with standalone documents](../adr/0001-use-a-library-with-standalone-documents.md).
- [ADR 0002: Edit formatted Markdown directly](../adr/0002-edit-formatted-markdown-directly.md).
- [ADR 0003: Handle external file changes safely](../adr/0003-handle-external-file-changes-safely.md).
- [macOS application approaches research](../research/macos-application-approaches.md). This contains the evidence for the architecture recommendation, framework comparison, file-access behavior, packaging, app-size ordering, update options, Markdown libraries, and distribution requirements.

The prototype still uses the working name Folio and contains three design variants. Paperbranch is the canonical name. Only Variant B is the visual source for implementation.

The current folder has no configured issue tracker or `ready-for-agent` label. This trial therefore stores the specification locally instead of publishing an issue. Issue publication can happen later without changing the specification's contents.
