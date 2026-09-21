# 10: Package and verify the personal Mac app

**What to build:** Produce a complete local Paperbranch application bundle for personal use and verify the integrated product against the approved specification and Variant B visual source.

**Blocked by:** 03: Display local images safely; 05: Restore and refresh the Library; 06: Open Library and Standalone documents from Finder; 07: Add the document outline and reading progress; 09: Resolve external changes with unsaved edits.

**Status:** ready-for-agent

- [ ] Xcode produces a Paperbranch macOS application bundle that launches on the user's Mac.
- [ ] The built application works without an account, server, or internet connection.
- [ ] The application uses the Paperbranch name and contains no prototype switcher, Folio branding, sample documents, or browser file picker.
- [ ] The Library window and Standalone windows match the approved Variant B visual direction at representative window sizes.
- [ ] Visual verification covers an expanded and collapsed sidebar, a selected document, a long document, an empty Library, an unavailable Library, a dirty document, and a conflict.
- [ ] The complete application-workflow and editor-contract test suites pass against the packaged implementation.
- [ ] A manual acceptance pass confirms choosing and restoring a Library, opening from Finder, direct formatted editing, local images, `Command-S`, clean external reloads, and dirty conflict resolution.
- [ ] The personal build adds no signing, notarization, installer, telemetry, update service, or public release configuration.
- [ ] The application can be copied to the user's Applications folder and launched again with its Library access and document behavior intact.
