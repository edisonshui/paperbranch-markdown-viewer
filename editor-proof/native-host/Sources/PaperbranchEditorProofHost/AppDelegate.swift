import AppKit
import PaperbranchBridgeCore
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSToolbarDelegate {
    private var window: NSWindow!
    private var documentSession: DocumentSession!
    private let sidebarController = LibrarySidebarViewController()
    private var documentController: DocumentPresentationViewController!
    private let splitController = NSSplitViewController()
    private let libraryWorkflow = LibraryWorkflow()
    private lazy var finderOpenWorkflow = FinderOpenWorkflow(libraryWorkflow: libraryWorkflow)
    private var standaloneWindows: [URL: StandaloneDocumentWindow] = [:]
    private var windowsAllowedToClose: Set<NSWindow> = []
    private var pendingFinderURLs: [URL] = []
    private var isApplicationReady = false
    private var libraryRefreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let coordinator = BridgeCoordinator()
        documentSession = DocumentSession(coordinator: coordinator)
        documentSession.dirtyStateDidChange = { [weak self] _ in self?.updateWindowTitle() }
        documentSession.availabilityDidChange = { [weak self] availability in
            self?.documentController.show(availability: availability)
            self?.updateWindowTitle()
        }
        documentSession.conflictDidChange = { [weak self] conflict in
            guard let self else { return }
            self.updateWindowTitle()
            self.presentConflict(conflict, for: self.documentSession, in: self.window)
        }
        documentSession.navigationStateDidChange = { [weak self] outline, progress in self?.sidebarController.showDocumentNavigation(outline: outline, progress: progress) }
        sidebarController.chooseLibrary = { [weak self] in self?.handleChooseLibrary() }
        sidebarController.selectDocument = { [weak self] url in self?.routeFinderOpen([url]) }
        sidebarController.folderExpansionChanged = { [weak self] node, expanded in self?.libraryWorkflow.setFolder(node, expanded: expanded) }
        sidebarController.selectOutline = { [weak self] id in self?.selectOutline(id) }
        documentController = DocumentPresentationViewController(webView: coordinator.webView)
        splitController.addSplitViewItem(NSSplitViewItem(sidebarWithViewController: sidebarController))
        splitController.addSplitViewItem(NSSplitViewItem(viewController: documentController))

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 720), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Paperbranch"
        window.contentViewController = splitController
        window.delegate = self
        let toolbar = NSToolbar(identifier: "PaperbranchToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
        window.center()
        window.makeKeyAndOrderFront(nil)
        installMenu()
        coordinator.load(url: HarnessLocation.url)
        restoreLibrary()
        isApplicationReady = true
        if !pendingFinderURLs.isEmpty {
            let urls = pendingFinderURLs
            pendingFinderURLs = []
            routeFinderOpen(urls)
        }
        libraryRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshLibraryIfNeeded() }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        routeFinderOpen([URL(fileURLWithPath: filename)])
        return true
    }

    func application(_ application: NSApplication, openFiles filenames: [String]) {
        routeFinderOpen(filenames.map(URL.init(fileURLWithPath:)))
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [.toggleSidebar, .flexibleSpace, .chooseLibrary] }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [.toggleSidebar, .flexibleSpace, .chooseLibrary] }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: id)
        if id == .toggleSidebar {
            item.label = "Library"; item.toolTip = "Show or hide Library"
            item.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: "Library")
            item.target = self; item.action = #selector(toggleLibrarySidebar)
        } else if id == .chooseLibrary {
            item.label = "Choose Library"; item.toolTip = "Choose Library"
            item.image = NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: "Choose Library")
            item.target = self; item.action = #selector(handleChooseLibrary)
        } else { return nil }
        return item
    }

    private func installMenu() {
        let main = NSMenu(); let appItem = NSMenuItem(); main.addItem(appItem)
        let appMenu = NSMenu(); appItem.submenu = appMenu
        appMenu.addItem(withTitle: "Quit Paperbranch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let fileItem = NSMenuItem(); main.addItem(fileItem); let file = NSMenu(title: "File"); fileItem.submenu = file
        file.addItem(menuItem("Choose Library…", #selector(handleChooseLibrary), "l", [.command]))
        file.addItem(menuItem("Open…", #selector(handleOpen), "o", [.command]))
        file.addItem(menuItem("Save", #selector(handleSave), "s", [.command]))
        let viewItem = NSMenuItem(); main.addItem(viewItem); let view = NSMenu(title: "View"); viewItem.submenu = view
        view.addItem(menuItem("Show or Hide Library", #selector(toggleLibrarySidebar), "l", [.command, .option]))
        NSApp.mainMenu = main
    }

    private func menuItem(_ title: String, _ action: Selector, _ key: String, _ modifiers: NSEvent.ModifierFlags) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers; item.target = self; return item
    }

    @objc private func handleChooseLibrary() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false; panel.prompt = "Choose Library"
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try self?.libraryWorkflow.chooseLibrary(at: url)
                self?.showLibrary()
                self?.splitController.splitViewItems.first?.isCollapsed = false
            } catch { self?.presentError(error, for: url) }
        }
    }

    @objc private func handleOpen() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "md")!, .init(filenameExtension: "markdown")!]
        panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
        panel.beginSheetModal(for: window) { [weak self] response in guard response == .OK, let url = panel.url else { return }; self?.routeFinderOpen([url]) }
    }

    private func routeFinderOpen(_ urls: [URL]) {
        guard isApplicationReady else { pendingFinderURLs.append(contentsOf: urls); return }
        Task { [weak self] in guard let self else { return }; do {
            let results = try await finderOpenWorkflow.applicationDidReceiveFinderOpen(urls)
            for result in results {
                switch result {
                case let .opened(state):
                    if state.kind == .library { try await openLibraryDocument(at: state.documentURL) }
                    else { try await openStandaloneDocument(at: state.documentURL) }
                case let .focused(state):
                    if state.kind == .library { window.makeKeyAndOrderFront(nil) }
                    else { standaloneWindows[state.documentURL]?.window.makeKeyAndOrderFront(nil) }
                }
            }
        } catch { presentError(error, for: urls.first) } }
    }

    private func openLibraryDocument(at url: URL) async throws {
        try await documentSession.open(url)
        sidebarController.select(url: url)
        updateWindowTitle()
        window.makeKeyAndOrderFront(nil)
    }

    private func selectOutline(_ id: String) {
        Task { [weak self] in _ = try? await self?.documentSession.coordinator.selectOutline(id: id) }
    }

    private func openStandaloneDocument(at url: URL) async throws {
        let standalone = StandaloneDocumentWindow(delegate: self)
        standalone.session.dirtyStateDidChange = { [weak standalone] _ in standalone?.updateTitle() }
        standalone.session.availabilityDidChange = { [weak standalone] availability in
            standalone?.presentation.show(availability: availability)
            standalone?.updateTitle()
        }
        standalone.session.conflictDidChange = { [weak self, weak standalone] conflict in
            guard let self, let standalone else { return }
            standalone.updateTitle()
            self.presentConflict(conflict, for: standalone.session, in: standalone.window)
        }
        try await standalone.session.open(url)
        standalone.updateTitle()
        standalone.window.makeKeyAndOrderFront(nil)
        standaloneWindows[url.standardizedFileURL] = standalone
    }

    @objc private func handleSave() {
        guard let session = activeDocumentSession, session.fileURL != nil else { return }
        save(session, in: window(for: session))
    }

    @objc private func toggleLibrarySidebar() {
        splitController.splitViewItems.first?.isCollapsed.toggle()
        libraryWorkflow.toggleSidebar()
    }

    private func restoreLibrary() {
        do {
            switch try libraryWorkflow.restoreLibrary() {
            case .restored:
                showLibrary()
                if let selected = libraryWorkflow.selectedDocumentURL { routeFinderOpen([selected]) }
            case .unavailable:
                sidebarController.showUnavailableLibrary()
            }
        } catch {
            sidebarController.showUnavailableLibrary()
        }
    }

    private func refreshLibraryIfNeeded() {
        guard libraryWorkflow.library != nil else { return }
        do {
            try libraryWorkflow.refreshLibrary()
            showLibrary()
        } catch {
            // This intentionally does not touch documentSession. A lost
            // Library must never discard unsaved Document view edits.
            libraryWorkflow.libraryAccessBecameUnavailable()
            sidebarController.showUnavailableLibrary()
        }
    }

    private func showLibrary() {
        guard let library = libraryWorkflow.library else { return }
        sidebarController.show(library, sidebarState: libraryWorkflow.sidebarState, selectedDocumentURL: libraryWorkflow.selectedDocumentURL)
        splitController.splitViewItems.first?.isCollapsed = libraryWorkflow.sidebarState.isCollapsed
    }

    private func updateWindowTitle() {
        if let standalone = standaloneWindows.values.first(where: { $0.window == NSApp.keyWindow }) {
            standalone.updateTitle()
            return
        }
        guard let url = documentSession.fileURL else { window.title = "Paperbranch"; window.isDocumentEdited = false; return }
        if documentSession.availability != .available { window.title = "\(url.lastPathComponent) (Unavailable)" }
        else if documentSession.conflict != nil { window.title = "\(url.lastPathComponent) (Conflict)" }
        else { window.title = url.lastPathComponent }
        window.isDocumentEdited = documentSession.isDirty
    }

    private var activeDocumentSession: DocumentSession? {
        if let standalone = standaloneWindows.values.first(where: { $0.window == NSApp.keyWindow }) { return standalone.session }
        return documentSession
    }

    private func presentError(_ error: Error, for url: URL?) {
        let alert = NSAlert(error: error); alert.messageText = "Could not open or save \(url?.lastPathComponent ?? "document")"; alert.beginSheetModal(for: window)
    }

    private func presentConflict(_ conflict: DocumentConflict?, for session: DocumentSession, in owner: NSWindow) {
        guard case let .externalChange(url)? = conflict else { return }
        let alert = NSAlert()
        alert.messageText = "Changes conflict in \(url.lastPathComponent)"
        alert.informativeText = "This Markdown document changed on disk while it has unsaved edits."
        alert.addButton(withTitle: "Reload Disk")
        alert.addButton(withTitle: "Keep Editing")
        alert.beginSheetModal(for: owner) { [weak self] response in
            guard let self else { return }
            if response == .alertFirstButtonReturn {
                Task { do { try await session.reloadDiskVersion(); self.updateWindowTitle() } catch { self.presentError(error, for: session.fileURL) } }
            } else {
                session.keepEditing()
                self.updateWindowTitle()
            }
        }
    }

    private func save(_ session: DocumentSession, in owner: NSWindow, afterSave: @escaping () -> Void = {}) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await session.save()
                self.updateWindowTitle()
                afterSave()
            } catch let error as DocumentSessionError {
                if case .overwriteConfirmationRequired = error {
                    self.presentOverwriteConfirmation(for: session, in: owner, afterOverwrite: afterSave)
                } else {
                    self.presentError(error, for: session.fileURL)
                }
            } catch {
                self.presentError(error, for: session.fileURL)
            }
        }
    }

    private func presentOverwriteConfirmation(for session: DocumentSession, in owner: NSWindow, afterOverwrite: @escaping () -> Void = {}) {
        let alert = NSAlert()
        alert.messageText = "Overwrite newer disk version of \(session.fileURL?.lastPathComponent ?? "this document")?"
        alert.informativeText = "Paperbranch will replace the version changed outside the app with your in-memory edits."
        alert.addButton(withTitle: "Overwrite")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: owner) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self else { return }
            Task { do { try await session.save(overwritingExternalChanges: true); self.updateWindowTitle(); afterOverwrite() } catch { self.presentError(error, for: session.fileURL) } }
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let session = documentSession(for: sender), session.isDirty, !windowsAllowedToClose.contains(sender) else { return true }
        let alert = NSAlert(); alert.messageText = "Save changes to \(session.fileURL?.lastPathComponent ?? "this document")?"; alert.informativeText = "Your edits will be lost if you do not save them."
        alert.addButton(withTitle: "Save"); alert.addButton(withTitle: "Cancel"); alert.addButton(withTitle: "Discard")
        alert.beginSheetModal(for: sender) { [weak self] response in guard let self else { return }; switch response {
        case .alertFirstButtonReturn: save(session, in: sender) { self.windowsAllowedToClose.insert(sender); sender.performClose(nil) }
        case .alertThirdButtonReturn: windowsAllowedToClose.insert(sender); sender.performClose(nil)
        default: break
        } }
        return false
    }

    func windowWillClose(_ notification: Notification) {
        guard let closedWindow = notification.object as? NSWindow,
              let entry = standaloneWindows.first(where: { $0.value.window == closedWindow }) else { return }
        finderOpenWorkflow.documentWindowDidClose(for: entry.key)
        standaloneWindows[entry.key] = nil
        windowsAllowedToClose.remove(closedWindow)
    }

    private func documentSession(for window: NSWindow) -> DocumentSession? {
        if window == self.window { return documentSession }
        return standaloneWindows.values.first(where: { $0.window == window })?.session
    }

    private func window(for session: DocumentSession) -> NSWindow {
        if session === documentSession { return window }
        return standaloneWindows.values.first(where: { $0.session === session })?.window ?? window
    }
}

private extension NSToolbarItem.Identifier { static let chooseLibrary = NSToolbarItem.Identifier("ChooseLibrary") }
