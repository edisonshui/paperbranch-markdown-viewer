# 08: Reload clean documents after external changes

**What to build:** Keep a clean open document current when another program changes its file, without reacting twice to Paperbranch's own saves or replacing content on an unreliable notification alone.

**Blocked by:** 02: Open, edit, and save one Markdown document.

**Status:** ready-for-agent

- [ ] Paperbranch monitors each open Markdown document for external modification, replacement, movement, and deletion.
- [ ] A notification causes Paperbranch to re-read and compare disk content before it treats the event as a meaningful change.
- [ ] If the Document view is clean and the disk content changed, Paperbranch reloads the new Markdown in the existing document session.
- [ ] A clean reload keeps the same window and continues to identify the same document where the file still exists.
- [ ] Notifications caused by Paperbranch's own completed save do not trigger a second reload or a conflict.
- [ ] A moved or deleted clean document receives a clear unavailable-document state instead of stale or blank content.
- [ ] A dirty document is never reloaded by this behavior. It is handed to the conflict behavior in Ticket 9.
- [ ] Application-workflow tests use real temporary files and cover external modification, atomic replacement, Paperbranch's own save, movement, deletion, and a dirty document.
