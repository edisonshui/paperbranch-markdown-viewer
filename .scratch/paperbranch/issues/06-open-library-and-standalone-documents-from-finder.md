# 06: Open Library and Standalone documents from Finder

**What to build:** Make Paperbranch behave as a Mac document application when Finder opens Markdown files. Route Library documents to the Library window and outside documents to separate Standalone windows.

**Blocked by:** 05: Restore and refresh the Library.

**Status:** ready-for-agent

- [ ] macOS recognizes Paperbranch as an editor for `.md` and `.markdown` documents.
- [ ] Finder can open a Markdown document when Paperbranch is stopped or already running.
- [ ] A Finder-opened document inside the Library becomes the selected document in the Library window.
- [ ] A Finder-opened document outside the Library opens in its own Standalone window and is not added to the Library.
- [ ] Different Standalone documents can remain open in separate windows at the same time.
- [ ] Opening an already open document focuses its existing window instead of creating a second editing session.
- [ ] Library and Standalone documents support the same formatted editing, dirty-state, and `Command-S` behavior.
- [ ] Application-workflow tests cover stopped and running application events, Library membership routing, separate Standalone windows, and duplicate-open prevention.
