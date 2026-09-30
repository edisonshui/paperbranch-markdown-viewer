# 25: Stop closing a Standalone window from crashing Paperbranch

**What to build:** Closing a Standalone window closes only that window. Paperbranch keeps running, and the Library window and its document stay open.

**Blocked by:** 06: Open Library and Standalone documents from Finder.

**Status:** ready-for-agent

- [ ] The cause of the crash is confirmed and recorded in Comments.
- [ ] Closing a clean Standalone window leaves Paperbranch running with the Library window unchanged.
- [ ] Closing a dirty Standalone window through the existing Save, Cancel, and Discard alert still works, and neither Save nor Discard crashes.
- [ ] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Created 2026-09-30 from Ticket 20's visual check. In the packaged app, the reader's Open button opened a Markdown file outside the Library in a Standalone window. Clicking that window's close button crashed Paperbranch while the Library window was still open.

The crash report is `~/Library/Logs/DiagnosticReports/Paperbranch-2026-09-30-165822.ips`: `EXC_BAD_ACCESS` (`KERN_INVALID_ADDRESS`) in `objc_release`, called from `-[_NSWindowTransformAnimation dealloc]` while an autorelease pool drained during a Core Animation commit. So the window's close animation released an object that had already been freed.

Suspected cause, not confirmed: `StandaloneDocumentWindow` creates its `NSWindow` in code, where `isReleasedWhenClosed` defaults to `true`, while `AppDelegate.windowWillClose(_:)` also drops the last strong reference with `standaloneWindows[entry.key] = nil`. Confirm this before fixing, for example by setting `isReleasedWhenClosed = false` and checking that the crash stops, rather than assuming it.

Not yet known: whether the crash reproduces on the build before Ticket 20 (`81bde36`). Ticket 20 did not change Standalone window code, which has been unchanged since `50472e3`.
