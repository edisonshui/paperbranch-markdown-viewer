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
