# macOS application approaches for Paperbranch

Research date: 2026-09-20

## Scope and evidence rules

This report compares four implementation approaches against Paperbranch's settled product decisions:

1. SwiftUI and AppKit with a native TextKit editor.
2. A SwiftUI and AppKit shell with a `WKWebView` rich-text editor.
3. Tauri 2 with a web rich-text editor.
4. Electron with a web rich-text editor.

The comparison uses the [Library and Standalone document decision](../adr/0001-use-a-library-with-standalone-documents.md), [direct formatted editing decision](../adr/0002-edit-formatted-markdown-directly.md), and [external-change decision](../adr/0003-handle-external-file-changes-safely.md). The important requirements are:

- One remembered folder Library with a nested sidebar.
- Standalone Markdown documents opened from Finder in separate windows.
- Direct editing of formatted content, with no raw-source or split-view requirement.
- Explicit `Command-S` saves.
- Meaning-preserving Markdown normalization is allowed.
- Headings, emphasis, lists, links, images, block quotes, fenced code blocks, tables, task lists, and strikethrough.
- Automatic reload after an external change only when the Document view is clean. A dirty Document view must prompt for conflict resolution.
- Personal use on one Mac now. Signing and public distribution are possible later, but are not current requirements.

Claims below use these labels:

- **Documented** means a cited primary source states the behavior.
- **Measured reference** means the number comes from an official release artifact or an official project's own measurement. It is not a prediction of Paperbranch's final size.
- **Project claim** means a framework or library project states the result. It is not an independent measurement.
- **Inference** means the conclusion follows from the documented components and Paperbranch's requirements, but no source promises it as an end-to-end result.

## Evidence matrix

| Requirement | Native TextKit | Native shell with `WKWebView` | Tauri 2 | Electron |
| --- | --- | --- | --- | --- |
| Folder Library and persistent access | Strongest native path | Strongest native path | Viable for a current direct build; a sandboxed relaunch needs a validated or custom Apple bookmark layer | Viable, with Electron dialogs and stored security-scoped bookmarks for a Mac App Store build |
| Finder document opening | Native document APIs | Native document APIs | Supported through file associations and `RunEvent::Opened`, with a current macOS 26 regression report | Viable through `Info.plist` association and the `open-file` event |
| Separate Standalone windows | Native window and document model | Native window model | Supported, but the app must map opened URLs to windows | Supported, but the app must map `open-file` events to windows |
| Direct formatted Markdown editing | Viable, highest custom-editor risk | Strong fit with a Markdown-first web editor | Strong fit with the same web editor | Strong fit with the same web editor |
| Required Markdown feature set | Parser support exists; editing and serialization need custom work | Milkdown's CommonMark and GFM presets cover the required set | Same editor support as the hybrid option | Same editor support as the hybrid option |
| Explicit `Command-S` | Straightforward | Straightforward through the native command system and bridge | Straightforward through a menu command and backend call | Straightforward through Electron menus and main-process file write |
| External change detection | Best native APIs | Best native APIs | Viable through the file-system watch feature | Viable through Node `fs.watch`, with documented replacement-file caveats |
| Conflict policy | App logic on top of native notifications | App logic on top of native notifications | App logic | App logic |
| Relative installed size | Smallest | Small to medium | Small to medium | Largest by a wide margin |
| Packaging for personal use | Xcode `.app` | Xcode `.app` | `tauri build` produces `.app` and DMG targets | Electron Forge packages the app and bundled Electron runtime |
| Direct auto-update later | Sparkle is established | Sparkle is established | Official updater plugin | Built-in `autoUpdater` on macOS |
| Direct signed distribution later | Native Xcode workflow | Native Xcode workflow | Official signing and notarization workflow | Forge and Electron signing and notarization workflow |
| Mac App Store later | Native path | Native path | Official App Store path exists | Supported, but needs the separate MAS Electron build and helper entitlements |
| Main technical risk | Building a semantic WYSIWYG Markdown editor on TextKit | Swift to JavaScript editor bridge and local-image URL handling | Rust, JavaScript, capabilities, and macOS sandbox behavior across layers | Runtime size, security maintenance, and more complex packaging |

All four approaches are technically viable. Native TextKit is viable only if the project accepts substantial custom editor work. Electron is viable, but its runtime cost is hard to justify for this Mac-only personal app. The two strongest candidates are the native `WKWebView` shell and Tauri 2.

## Shared macOS file requirements

### Folder access and restoration

A sandboxed Mac app can ask the user to select a folder with `NSOpenPanel`. macOS extends access to the selected folder and its nested contents. To restore access after relaunch, the app stores a security-scoped URL bookmark, resolves it on launch, checks whether it is stale, and calls `startAccessingSecurityScopedResource()` before reading or writing. These are documented Apple behaviors, not framework-specific assumptions. [Apple: Accessing files from the macOS App Sandbox](https://developer.apple.com/documentation/Security/accessing-files-from-the-macos-app-sandbox)

This directly matches the Library decision. One bookmark can represent the chosen Library folder, and its scope covers the nested Markdown documents. A native Swift layer can implement this without adaptation. Tauri and Electron can reach the same operating-system capability, but each framework adds its own API and persistence layer.

Tauri's dialog plugin can request `fileAccessMode: 'scoped'` on macOS. Its source documentation says the system manages security-scoped access and points to the persisted-scope plugin for restoration. [Tauri dialog plugin source](https://github.com/tauri-apps/plugins-workspace/blob/v2/plugins/dialog/guest-js/index.ts) The persisted-scope plugin saves and restores Tauri file-system and asset scope entries across launches. [Tauri: Persisted Scope](https://v2.tauri.app/plugin/persisted-scope/)

Those two kinds of scope are not the same. Tauri's persisted-scope source serializes allowed and forbidden path patterns into its own state file. It does not show Apple bookmark data being created, stored, resolved, or refreshed. [Tauri persisted-scope implementation](https://github.com/tauri-apps/plugins-workspace/blob/v2/plugins/persisted-scope/src/lib.rs) **Inference:** the plugin restores Tauri's internal authorization list, but the cited source does not prove that it restores macOS sandbox authority after relaunch. A sandboxed Paperbranch build must validate this behavior. If it does not work, the Rust side needs a small native plugin that uses Apple's security-scoped bookmark APIs. This uncertainty does not block the current personal, direct-build use case, but it adds risk to a future Mac App Store build.

Electron's open dialog can return base64 security-scoped bookmark data in Mac App Store builds. The app can store that bookmark and later pass it to `app.startAccessingSecurityScopedResource()`. Electron requires the returned stop function to be called, otherwise the process leaks the finite system resource. [Electron: `dialog.showOpenDialog`](https://www.electronjs.org/docs/latest/api/dialog), [Electron: `app.startAccessingSecurityScopedResource`](https://github.com/electron/electron/blob/main/docs/api/app.md)

For direct, non-App-Store distribution, an app can remain outside App Sandbox and use normal process permissions. If Paperbranch enters the Mac App Store later, Apple requires App Sandbox. If it is notarized for direct distribution, Apple requires the hardened runtime but says App Sandbox is optional. [Apple: Preparing your app for distribution](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution)

### Finder document opening

SwiftUI's `DocumentGroup` registers document types and handles files opened by double-clicking them in Finder. It also adds standard macOS document menus and multi-document support. [Apple: `DocumentGroup`](https://developer.apple.com/documentation/SwiftUI/DocumentGroup) An AppKit-controlled app can instead receive open events through `NSApplicationDelegate`; Apple documents that a Finder double-click may call `application(_:openFile:)` before `applicationDidFinishLaunching`. [Apple: `application:openFile:`](https://developer.apple.com/documentation/appkit/nsapplicationdelegate/application%28_%3Aopenfile%3A%29?language=objc)

Paperbranch has a nonstandard window rule: Library documents stay in one Library window, while files outside the Library get separate Standalone windows. **Inference:** a custom native window coordinator is a cleaner fit than making every Library selection an `NSDocument` window. The app can still use the native open-event APIs without forcing its whole UI into `DocumentGroup`.

Tauri can declare `.md` and `.markdown` file associations with the Apple `Editor` role, and its macOS `RunEvent::Opened` contains the URLs the user asked the app to open. [Tauri: file-association configuration](https://v2.tauri.app/reference/config/), [Tauri: `RunEvent`](https://docs.rs/tauri/latest/x86_64-apple-darwin/tauri/enum.RunEvent.html)

There is also an open first-party Tao issue reporting that macOS 26 can drop Finder `openURLs` events for quarantined files when a Tao-based app is already running. The report covers Tao 0.34.5 and Tauri 2.9.5. This is a reported regression, not a documented platform guarantee, but Paperbranch would need to reproduce the case before relying on Tauri's Finder path. [Tao issue 1206](https://github.com/tauri-apps/tao/issues/1206)

Electron emits an `open-file` event when macOS asks the app to open a file. Electron warns that the listener must be registered before `ready` so cold-launch events are not missed. [Electron: `app` open-file event](https://www.electronjs.org/docs/latest/api/app)

### External changes and conflict handling

Apple's `NSFilePresenter` tells a presenter when another coordinated reader or writer changes, moves, or deletes its file. `presentedItemDidChange()` can compare modification dates before rereading. [Apple: `NSFilePresenter`](https://developer.apple.com/documentation/foundation/nsfilepresenter), [Apple: `presentedItemDidChange`](https://developer.apple.com/documentation/foundation/nsfilepresenter/presenteditemdidchange%28%29?language=objc) A `DispatchSourceFileSystemObject` can also monitor write, rename, and delete events on a file descriptor. [Apple: `DispatchSourceFileSystemObject`](https://developer.apple.com/documentation/dispatch/dispatchsourcefilesystemobject), [Apple: file-system event flags](https://developer.apple.com/documentation/dispatch/dispatchsource/filesystemevent/write)

**Inference:** for Paperbranch, the robust native design is to treat either signal as an instruction to re-stat and, if needed, reread the file. The app should remember the last loaded content hash or modification identity. If the editor is clean, it reloads. If it is dirty, it retains the in-memory draft and shows the conflict prompt. The event mechanism does not implement Paperbranch's conflict policy by itself.

Tauri's official file-system plugin has `watch` and recursive directory watching when its `watch` Cargo feature is enabled. Its capability system requires explicit command permissions and path scopes. [Tauri: File System](https://v2.tauri.app/plugin/file-system/)

Electron can use Node's `fs.watch`. Node documents that, on macOS, a file watch follows the inode. If another editor saves by deleting and recreating the path, the watcher remains attached to the old inode and does not report later events for the replacement. Node also says network-file-system watches can be unreliable. [Node: `fs.watch` caveats](https://nodejs.org/api/fs.html#fswatchfilename-options-listener)

**Inference:** Tauri and Electron should watch the parent directory or rebuild a per-file watcher after rename or delete events, then verify the path's metadata or content hash. This is important because atomic-save behavior commonly replaces the original file. Regardless of framework, Paperbranch must suppress its own save notification so `Command-S` does not appear as an external conflict.

## Approach 1: native SwiftUI and AppKit with TextKit

### What the platform supplies

`NSTextView` is AppKit's editable text view. Apple documents support for rich text, attachments, input management, key bindings, selection, and editing. [Apple: `NSTextView`](https://developer.apple.com/documentation/AppKit/NSTextView) SwiftUI can host it through `NSViewRepresentable`, while AppKit can own the menus, windows, file panels, and open events.

Apple's `AttributedString` can parse Markdown into presentation-intent attributes. [Apple: Creating `AttributedString` with Markdown](https://developer.apple.com/documentation/Foundation/AttributedString) Apple's documentation describes Markdown input initializers, but it does not provide an end-to-end formatted Markdown editor or a Markdown serializer for edited attributed content.

The official Swift Markdown package parses, builds, edits, and analyzes Markdown syntax trees. It uses `cmark-gfm`, so its parser follows GitHub-flavored Markdown closely. [Swift Markdown repository](https://github.com/swiftlang/swift-markdown)

### Fit for Paperbranch

File access, Finder integration, native windows, keyboard commands, sandbox bookmarks, and external-change monitoring all fit cleanly. The problem is the Document view.

**Inference:** TextKit supplies rich-text mechanics, and Swift Markdown supplies a syntax tree, but Paperbranch would have to create and maintain the semantic bridge between them. That includes:

- Mapping every Markdown node to attributed text and editor behavior.
- Preserving block identity as the user edits across boundaries.
- Implementing task-list checkboxes, fenced code blocks, images, and table editing.
- Translating selection changes back into an updated Markdown tree.
- Serializing a normalized Markdown document without losing supported meaning.
- Defining paste, undo, drag, and accessibility behavior for custom attachments and tables.

The decision allowing equivalent syntax normalization helps serialization, but it does not remove the editor-state mapping problem. No cited Apple API or Swift Markdown API claims to provide that complete editor.

### Packaging, size, updates, and distribution

Xcode can archive and export the `.app`. Apple provides separate export paths for App Store and Developer ID distribution. [Apple: Creating distribution-signed code for macOS](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac/)

**Relative-size inference:** this should be the smallest option because AppKit, SwiftUI, and TextKit come from macOS, and the app does not carry a browser runtime. The final bundle still includes Paperbranch's code, assets, and any statically linked Markdown parser. This report has no measured Paperbranch build, so it does not attach a megabyte estimate.

For direct-download auto-updates, Sparkle 2 supports sandboxed apps, signed update feeds, automatic installation, and delta updates. [Sparkle repository](https://github.com/sparkle-project/Sparkle), [Sparkle setup documentation](https://github.com/sparkle-project/sparkle-project.github.io/blob/master/documentation/index.md) A personal build does not need an updater yet.

### Assessment

Viable, but not the best first implementation. It spends most of the project's risk on building an editor engine that Paperbranch can obtain from established web-editor libraries.

## Approach 2: native SwiftUI and AppKit shell with `WKWebView`

### Architecture

The Swift layer owns the Library bookmark, directory enumeration, windows, Finder events, file coordination, external-change monitoring, conflict state, saving, menus, and distribution. The web view owns only the formatted Document view and its editing model.

Apple describes `WKWebView` as a native view that presents HTML, CSS, and JavaScript alongside native views. [Apple: `WKWebView`](https://developer.apple.com/documentation/WebKit/WKWebView) JavaScript can send structured messages to Swift through `WKScriptMessageHandler`. [Apple: `WKScriptMessageHandler`](https://developer.apple.com/documentation/webkit/wkscriptmessagehandler) The reverse direction can use WebKit's JavaScript evaluation APIs.

The bridge can stay narrow:

- Swift sends a Markdown string and a document identifier to the editor.
- The editor sends dirty-state changes and its serialized Markdown to Swift.
- Swift handles `Command-S`, verifies the on-disk identity, writes the file, and acknowledges the saved version.
- Swift notifies the editor when an external reload is safe or when a conflict needs UI.

This keeps path access out of JavaScript. It also makes the conflict policy testable without tying it to the editor framework.

Relative images need an explicit policy. `WKWebView` can load local content while granting read access to a chosen file or directory. [Apple: `loadFileRequest(_:allowingReadAccessTo:)`](https://developer.apple.com/documentation/webkit/wkwebview/loadfilerequest%28_%3Aallowingreadaccessto%3A%29) **Inference:** a custom URL handler or a narrowly scoped bridge is safer than granting the editor page broad read access to the whole Library. It can resolve an image path against the Markdown document's folder and return only authorized bytes.

### Markdown editor fit

Milkdown describes itself as a plugin-driven WYSIWYG Markdown editor built on ProseMirror and remark. [Milkdown repository](https://github.com/Milkdown/milkdown) Its CommonMark preset provides the base Markdown model. [Milkdown: CommonMark preset](https://milkdown.dev/docs/api/preset-commonmark) Its GFM preset adds tables, task lists, and strikethrough, which completes Paperbranch's first-version feature list. [Milkdown: GFM preset](https://milkdown.dev/docs/api/preset-gfm)

ProseMirror's Markdown package provides a schema limited to Markdown-expressible content and parser and serializer pairs for converting between the editor model and Markdown text. [ProseMirror Markdown example](https://prosemirror.net/examples/markdown/)

TOAST UI Editor is a viable fallback. Its project documents both WYSIWYG and Markdown modes and CommonMark plus GFM support. [TOAST UI Editor repository](https://github.com/nhn/tui.editor) Paperbranch does not need to expose TOAST UI's raw Markdown mode.

**Inference:** Milkdown is the better initial spike because its Markdown-first model and GFM preset match Paperbranch's exact supported syntax. Paperbranch explicitly permits formatting normalization on save, so the editor does not need source-preserving round trips. The spike must still test nested emphasis, mixed lists, task-list state, code fences with language identifiers, table alignment, escaped characters, image URLs, and Markdown pasted from other apps.

### Packaging, size, updates, and distribution

Packaging and distribution use the same native Xcode route as Approach 1. Sparkle remains available for future direct-download updates.

**Relative-size inference:** this should be larger than the TextKit build because it bundles the editor's JavaScript and CSS, but much smaller than Electron because it uses the WebKit already installed with macOS instead of shipping Chromium. `WKWebView` is the system WebKit view, so there is no separate browser runtime in the app bundle. The actual size depends on the production JavaScript bundle and included assets.

One trade-off follows from the system WebKit choice. **Inference:** rendering behavior can vary with the user's macOS WebKit version. For a personal app targeting one known Mac, that is a small risk. A public release would need a declared minimum macOS version and testing on each supported release.

### Assessment

Strongest fit. It uses native macOS APIs for the requirements that are specific to Mac and a Markdown-first editor for the requirement that is hardest to implement natively.

## Approach 3: Tauri 2 with a web rich-text editor

### Architecture and file behavior

Tauri uses the operating system's web view and connects JavaScript to a Rust backend. Its project says a Tauri app contains its own code and assets rather than a bundled browser engine. [Tauri: What is Tauri?](https://v2.tauri.app/start/)

The official dialog and file-system plugins cover folder selection, scoped access for the current run, reading, and writing. The persisted-scope plugin restores Tauri's internal path allowlist. It does not prove restoration of Apple sandbox authority. The file-system plugin blocks dangerous commands and paths by default. Each operation needs permission and the path must fall inside an allowed scope. [Tauri: File System](https://v2.tauri.app/plugin/file-system/), [Tauri persisted-scope implementation](https://github.com/tauri-apps/plugins-workspace/blob/v2/plugins/persisted-scope/src/lib.rs)

For Paperbranch, privileged file operations should live in narrow Rust commands rather than exposing general file-system calls to the web view. **Inference:** this reduces the number of allowed Tauri capabilities and gives one place to enforce the selected Library root, Standalone document URLs, content hashes, and save conflict checks.

Finder opening is supported through Tauri file associations and `RunEvent::Opened`. The current macOS 26 Tao regression report makes the already-running, quarantined-file case a required acceptance test. Multiple webview windows are supported by the framework, so the Library and Standalone window policy can be implemented. Tauri does not supply Paperbranch's document/window coordinator, so the app must build it.

Milkdown or TOAST UI provides the same Markdown editing capability as in Approach 2. Local image loading can use Tauri's asset scope or a Rust command that returns authorized data. This needs capability configuration because Tauri separates operating-system permission from its own webview-to-backend permission scopes.

### External changes

The file-system plugin's watch feature can watch the Library recursively. [Tauri: File System](https://v2.tauri.app/plugin/file-system/) The app still needs dirty-state tracking, self-save suppression, and content verification before reload. Those are Paperbranch rules, not updater or watcher features.

### Packaging, size, updates, and distribution

Tauri can produce a macOS app bundle and DMG. Its distribution documentation covers both direct download and the Mac App Store. [Tauri: Distribute](https://v2.tauri.app/distribute/) Its macOS signing guide uses a Developer ID Application certificate for direct distribution and requires notarization for that route. [Tauri: macOS code signing](https://v2.tauri.app/distribute/sign/macos/)

Tauri's updater plugin generates signed macOS update archives and signatures. [Tauri: Updater](https://v2.tauri.app/plugin/updater/) This is not needed for the current personal build.

Tauri states that a minimal app can be less than 600 KB because it uses the system web view. This is a **project claim about a minimal app**, not a realistic estimate for Paperbranch. [Tauri: What is Tauri?](https://v2.tauri.app/start/) **Relative-size inference:** Paperbranch would be small to medium after adding a universal Rust binary, Milkdown or TOAST UI, syntax styling, icons, and other assets. It should still be much smaller than Electron because it does not include Chromium and Node.

Tauri documents a Mac App Store path with an App Store Connect provisioning profile and embedded profile. [Tauri: App Store distribution](https://v2.tauri.app/distribute/app-store/) A store build must also satisfy Apple's sandbox and entitlement rules. Tauri's own persisted scope is not evidence of a persisted Apple security-scoped bookmark. A store build therefore needs a focused relaunch test and may need native bookmark integration.

### Assessment

Viable and the second-best fit. It is attractive if a cross-platform future or a Rust and web codebase matters. Neither is a current Paperbranch requirement. For a Mac-only personal app, it adds Rust, Tauri capabilities, plugin configuration, and framework window routing without improving the rich editor over the native `WKWebView` option.

## Approach 4: Electron with a web rich-text editor

### Architecture and file behavior

Electron bundles Chromium and Node.js and runs the UI as a web application. [Electron introduction](https://www.electronjs.org/docs/latest) Node's file-system APIs make folder enumeration and file writes direct. Electron's `dialog`, `open-file` event, and security-scoped bookmark APIs make Paperbranch's Library and Standalone document behavior viable on macOS.

Milkdown or TOAST UI can run directly in an Electron renderer. The main process should own file access, and the renderer should receive a narrow API through a preload script. Electron recommends context isolation, process sandboxing, restrictive navigation, validation of IPC senders, and avoiding direct exposure of Electron APIs to web content. [Electron security checklist](https://www.electronjs.org/docs/latest/tutorial/security), [Electron context isolation](https://www.electronjs.org/docs/latest/tutorial/context-isolation)

Relative Markdown images should go through a validated custom protocol or IPC route. Electron recommends custom protocols over `file://`, and its protocol API can register a standard scheme so relative URLs resolve. [Electron security checklist](https://www.electronjs.org/docs/latest/tutorial/security), [Electron: `protocol`](https://www.electronjs.org/docs/latest/api/protocol)

### Packaging, size, updates, and distribution

Electron itself does not bundle packaging tools. Its documentation recommends Electron Forge, which packages the app with the Electron binary and then produces distributables such as a macOS `.app`, ZIP, or DMG. [Electron: Packaging your application](https://www.electronjs.org/docs/latest/tutorial/tutorial-packaging)

Electron Packager states that a zipped minimal Electron app is approximately the size of the zipped prebuilt Electron binary. [Electron Packager repository](https://github.com/electron/packager) The official Electron 43.7.3 release lists a compressed macOS ARM64 runtime archive of 123,535,869 bytes and an x64 archive of 127,642,184 bytes. These are **measured release artifact sizes**, not Paperbranch builds or installed sizes. [Electron 43.7.3 release data](https://api.github.com/repos/electron/electron/releases/tags/v43.7.3), [Electron 43.7.3 ARM64 archive](https://github.com/electron/electron/releases/download/v43.7.3/electron-v43.7.3-darwin-arm64.zip) Paperbranch's app code and editor assets would be additional. This makes Electron the largest option by a wide margin.

Electron's macOS `autoUpdater` uses Squirrel.Mac and requires the app to be signed. [Electron: `autoUpdater`](https://www.electronjs.org/docs/latest/api/auto-updater) The official update guide supports static object storage and a GitHub Releases service for qualifying public repositories. [Electron: Updating applications](https://www.electronjs.org/docs/latest/tutorial/updates)

Forge can configure Apple code signing and notarization. [Electron: Code signing](https://www.electronjs.org/docs/latest/tutorial/code-signing) Mac App Store distribution is supported, but Electron requires its separate MAS build and sandbox entitlements for the app and helper executables. [Electron: Mac App Store submission guide](https://www.electronjs.org/docs/latest/tutorial/mac-app-store-submission-guide)

Electron's own security guidance says the app ships Electron, Chromium, and Node and should stay on a current Electron version to receive fixes. [Electron security checklist](https://www.electronjs.org/docs/latest/tutorial/security) **Inference:** that creates more update pressure than a system-WebKit approach, even if Paperbranch's features do not change.

### Assessment

Viable, with the fastest all-JavaScript route and the most predictable web-engine version. It is a poor proportional fit for one personal, Mac-only document app because the bundled runtime exceeds the app's functional needs. It becomes more defensible if cross-platform delivery or an existing Electron team becomes a real requirement.

## Packaging and distribution rules that do not depend on framework

For current personal use, Paperbranch can be built locally and copied into `/Applications`. It does not need a release updater or a public distribution pipeline.

For a future direct download, Apple says the Account Holder must sign the app with Developer ID before distribution. Apple's notarization service checks Developer ID-signed software, requires the hardened runtime and a secure timestamp, and returns a ticket that can be stapled to the app, disk image, or package. [Apple: Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

For a future Mac App Store release, Apple requires App Sandbox. [Apple: Preparing your app for distribution](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution) The Library bookmark flow must therefore be tested in a sandboxed release build even if early personal builds run without the sandbox.

Framework choice changes the tooling, but not these Apple requirements:

| Channel | Native and native hybrid | Tauri 2 | Electron |
| --- | --- | --- | --- |
| Personal local build | Xcode build | `tauri build` | Forge package |
| Direct installer | Xcode archive, then ZIP or DMG | Tauri app bundle or DMG | Forge ZIP or DMG |
| Direct trust | Developer ID and notarization | Developer ID and notarization | Developer ID and notarization |
| Direct updates | Sparkle, if added | Tauri updater plugin | Electron `autoUpdater` |
| Mac App Store | Native target with App Sandbox | Tauri App Store configuration and Apple profile | Separate Electron MAS build and helper entitlements |

## Recommendation after the evidence

Use a native SwiftUI and AppKit shell with a `WKWebView` Document view. Use Milkdown with its CommonMark and GFM presets for the first editor spike.

This recommendation follows Paperbranch's requirements:

1. The app is Mac-only and depends on macOS-specific document behavior. Swift and AppKit give the shortest path to folder bookmarks, Finder events, windows, native menus, `Command-S`, coordinated file access, and future signing.
2. Direct formatted Markdown editing is the hardest requirement. Milkdown already models Markdown as editable structured content and has documented support for tables, task lists, and strikethrough.
3. Paperbranch permits equivalent Markdown normalization. That removes the main reason to preserve a source-oriented editor model and makes a ProseMirror serializer acceptable.
4. `WKWebView` avoids Electron's bundled Chromium and Node runtime. It also avoids Tauri's Rust and capability layers for a product that does not need cross-platform support.
5. The Swift layer can keep all paths and file writes outside JavaScript. This gives one authoritative place for the Library boundary, Standalone windows, external-change hashes, and conflict checks.

The recommendation is conditional on a short editor proof. Before committing the framework in an ADR, build one spike that round-trips Paperbranch's complete supported syntax through Milkdown and exercises:

- Loading Markdown, editing each supported node, serializing, reopening, and comparing meaning.
- Nested lists with task items.
- Tables with alignment and escaped pipes.
- Fenced code blocks with language identifiers and literal backticks.
- Relative and absolute image references.
- Links containing parentheses and escaped characters.
- Paste from a browser and from another Markdown editor.
- Undo and redo across structural changes.
- `Command-S` while the web view has focus.
- An external file replacement while the Document view is clean and while it is dirty.

If Milkdown fails the round-trip proof, test TOAST UI in the same shell before changing the application framework. Both the native hybrid, Tauri, and Electron options depend on the same class of web editor, so an editor failure is not evidence that a different shell will fix it.

## Confidence and open questions

Confidence is high for native macOS file access, packaging, signing, the documented Finder-open APIs, framework updater availability, and the relative size ordering. Confidence is lower for Tauri's current Finder reliability on macOS 26 and for restoring Apple sandbox authority through Tauri alone because the cited sources expose open questions in both areas.

Confidence is medium for the final editor choice. Milkdown documents the required syntax nodes, but documentation cannot prove Paperbranch's exact round-trip and interaction quality. The spike above is the necessary evidence.

The research does not produce exact final bundle sizes. The Tauri number is a minimal-project claim, and the Electron number is a runtime reference measurement. Exact Paperbranch sizes require release builds of the same editor and assets under each candidate shell.
