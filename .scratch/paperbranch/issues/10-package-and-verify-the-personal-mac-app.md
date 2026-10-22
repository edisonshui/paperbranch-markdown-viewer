# 10: Package and verify the personal Mac app

**What to build:** Produce a complete local Paperbranch application bundle for personal use and verify the integrated product against the approved specification and Variant B visual source.

**Blocked by:** 03: Display local images safely; 05: Restore and refresh the Library; 06: Open Library and Standalone documents from Finder; 07: Add the document outline and reading progress; 09: Resolve external changes with unsaved edits.

**Status:** in-progress

- [x] Xcode produces a Paperbranch macOS application bundle that launches on the user's Mac.
- [x] The built application works without an account, server, or internet connection.
- [x] The application uses the Paperbranch name and contains no prototype switcher, Folio branding, sample documents, or browser file picker.
- [ ] The Library window and Standalone windows match the approved Variant B visual direction at representative window sizes.
- [ ] Visual verification covers an expanded and collapsed sidebar, a selected document, a long document, an empty Library, an unavailable Library, a dirty document, and a conflict.
- [x] The complete application-workflow and editor-contract test suites pass against the packaged implementation.
- [ ] A manual acceptance pass confirms choosing and restoring a Library, opening from Finder, direct formatted editing, local images, `Command-S`, clean external reloads, and dirty conflict resolution.
- [x] The personal build adds no signing, notarization, installer, telemetry, update service, or public release configuration.
- [x] The application can be copied to the user's Applications folder and launched again with its Library access and document behavior intact.

## Comments

Verified 2026-09-21:

- `editor-proof/native-host/verify-package.sh`: Xcode Release build succeeded. It bundled the compiled editor under `Paperbranch.app/Contents/Resources/Web`, verified the plist and absence of shipped Folio/prototype-switcher/browser-file-picker text, then ran all 37 native application-workflow tests against those bundled assets through `paperbranch-editor://` with no Vite server.
- `cd editor-proof && APP_PATH="$PWD/native-host/.build/Paperbranch.app"; npx vite preview --outDir "$APP_PATH/Contents/Resources/Web" --host 127.0.0.1 --port 5184 --strictPort & PAPERBRANCH_EDITOR_CONTRACT_BASE_URL=http://127.0.0.1:5184 npm test`: 51 editor-contract tests passed while serving the exact compiled assets in the packaged app.
- `cd editor-proof && npm test`: 51 editor-contract tests passed against the normal development harness.
- `plutil -lint editor-proof/native-host/Info.plist` and `git diff --check`: passed before the implementation commit.
- Manual packaging pass: Paperbranch launched with no listener on port 5183, loaded its Document view from the bundled resource, and showed the Paperbranch Library window. The Library sidebar expanded and collapsed. After copying the build to `/Applications/Paperbranch.app`, it relaunched and restored the remembered Library; its Document view loaded through `paperbranch-editor://document/index.html`.
- Visual comparison: incomplete. The current Library and Standalone windows use stock AppKit controls and do not match Variant B's reader layout, dark Library panel, typography, or reading presentation. The expanded/collapsed sidebar states were observed, but the required representative-state comparison cannot pass yet.
- Manual acceptance: incomplete. The offline launch, Library restoration, and copied-app relaunch were exercised manually. The Finder routing, direct formatted editing, local-image display, Command-S, clean external reload, and dirty-conflict flows were exercised by the packaged native suite, not by a full manual pass.

Implementation commit: `7d2b9cabb8ecc2195fc9024d2841ed870eb7160c`.

Functional acceptance pass 2026-10-22, packaged app after Tickets 29 to 34, against a test Library in `/tmp` (nested folders, a 3,039-word essay with 60 headings, tables, code, task lists, a local image, a missing image, a front-matter document, a `.markdown` file). Driven through accessibility actions, `open`, and synthetic mouse and key events; "measured" means seen in the app.

- Choosing and restoring a Library: measured. Chosen with File > Choose Library and the folder panel. Relaunches restored it with the previous selection and collapsed folders.
- Opening from Finder: measured with `open -a`. A Library document (`Ideas.markdown`) opened in the Library window and was selected in the sidebar. An outside document opened in its own Standalone window at 800x640 content size.
- Direct formatted editing: measured. Typed characters landed in the formatted paragraph, and the top bar showed "Edited".
- Local images: measured. A relative PNG rendered; a missing image showed the broken-image placeholder.
- `Command-S`: measured. It wrote the file and cleared "Edited" in the Variant B presentation (fixed in Ticket 30).
- Clean external reload: measured. An atomic replacement on disk showed the new text in the open document.
- Dirty conflict resolution: measured for Reload Disk. A dirty document changed on disk showed "Changed on disk" and the conflict alert, and Reload Disk loaded the disk version. Keep Editing and the later overwrite confirmation were not exercised by hand, because the pass stopped sending keystrokes once Edison was using the Mac. The packaged native suite covers both.
- Also seen: deleting the open document showed the unavailable state without resizing the window, and the front-matter document showed the blocked message.

Still open in this ticket: the Variant B visual-match items, deferred until the brand guideline decides the visual direction. Ticket 35 (unsaved edits on document switch) needs Edison's decision.
