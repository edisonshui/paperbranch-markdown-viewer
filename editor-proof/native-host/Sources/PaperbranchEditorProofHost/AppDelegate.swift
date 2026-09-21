import AppKit
import PaperbranchBridgeCore
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSToolbarDelegate {
    private var window: NSWindow!
    private var documentSession: DocumentSession!
    private let sidebarController = LibrarySidebarViewController()
    private let documentController = NSViewController()
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
        documentSession.navigationStateDidChange = { [weak self] outline, progress in self?.sidebarController.showDocumentNavigation(outline: outline, progress: progress) }
        sidebarController.chooseLibrary = { [weak self] in self?.handleChooseLibrary() }
        sidebarController.selectDocument = { [weak self] url in self?.routeFinderOpen([url]) }
        sidebarController.folderExpansionChanged = { [weak self] node, expanded in self?.libraryWorkflow.setFolder(node, expanded: expanded) }
        sidebarController.selectOutline = { [weak self] id in self?.selectOutline(id) }
        documentController.view = coordinator.webView
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
        try await standalone.session.open(url)
        standalone.updateTitle()
        standalone.window.makeKeyAndOrderFront(nil)
        standaloneWindows[url.standardizedFileURL] = standalone
    }

    @objc private func handleSave() {
        let session = activeDocumentSession
        Task { [weak self] in guard let self, let session, session.fileURL != nil else { return }; do { try await session.save(); updateWindowTitle() } catch { presentError(error, for: session.fileURL) } }
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
        window.title = url.lastPathComponent; window.isDocumentEdited = documentSession.isDirty
    }

    private var activeDocumentSession: DocumentSession? {
        if let standalone = standaloneWindows.values.first(where: { $0.window == NSApp.keyWindow }) { return standalone.session }
        return documentSession
    }

    private func presentError(_ error: Error, for url: URL?) {
        let alert = NSAlert(error: error); alert.messageText = "Could not open or save \(url?.lastPathComponent ?? "document")"; alert.beginSheetModal(for: window)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let session = documentSession(for: sender), session.isDirty, !windowsAllowedToClose.contains(sender) else { return true }
        let alert = NSAlert(); alert.messageText = "Save changes to \(session.fileURL?.lastPathComponent ?? "this document")?"; alert.informativeText = "Your edits will be lost if you do not save them."
        alert.addButton(withTitle: "Save"); alert.addButton(withTitle: "Cancel"); alert.addButton(withTitle: "Discard")
        alert.beginSheetModal(for: sender) { [weak self] response in guard let self else { return }; switch response {
        case .alertFirstButtonReturn: Task { do { try await session.save(); self.windowsAllowedToClose.insert(sender); sender.performClose(nil) } catch { self.presentError(error, for: session.fileURL) } }
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
}

private extension NSToolbarItem.Identifier { static let chooseLibrary = NSToolbarItem.Identifier("ChooseLibrary") }
