# 06: Open Library and Standalone documents from Finder

**What to build:** Make Paperbranch behave as a Mac document application when Finder opens Markdown files. Route Library documents to the Library window and outside documents to separate Standalone windows.

**Blocked by:** 05: Restore and refresh the Library.

**Status:** resolved

- [x] macOS recognizes Paperbranch as an editor for `.md` and `.markdown` documents.
- [x] Finder can open a Markdown document when Paperbranch is stopped or already running.
- [x] A Finder-opened document inside the Library becomes the selected document in the Library window.
- [x] A Finder-opened document outside the Library opens in its own Standalone window and is not added to the Library.
- [x] Different Standalone documents can remain open in separate windows at the same time.
- [x] Opening an already open document focuses its existing window instead of creating a second editing session.
- [x] Library and Standalone documents support the same formatted editing, dirty-state, and `Command-S` behavior.
- [x] Application-workflow tests cover stopped and running application events, Library membership routing, separate Standalone windows, and duplicate-open prevention.

## Comments

Verified 2026-09-21:

- `cd editor-proof/native-host && ./test.sh`: 22 native tests passed, including real temporary-file workflows for stopped and running Finder events, Library routing, separate Standalone sessions, duplicate focus, close-and-reopen behavior, formatted edits, dirty state, and explicit saves.
- `cd editor-proof && npm test`: 47 editor-contract tests passed.
- `cd editor-proof/native-host && plutil -lint Info.plist`: passed.
- `git diff --check`: passed before the implementation commit.

Implementation commit: `50472e3695e12e4709f6bc658cf36a64f3612c26`.
