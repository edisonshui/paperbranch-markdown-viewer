import AppKit
import PaperbranchBridgeCore
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSToolbarDelegate {
    private(set) var window: NSWindow!
    private(set) var documentSession: DocumentSession!
    private var libraryPresentation: PaperbranchWindowPresentation!
    let sidebarController = LibrarySidebarViewController()
    private var documentController: DocumentPresentationViewController!
    private let splitController = NSSplitViewController()
    private let libraryWorkflow: LibraryWorkflow
    private lazy var finderOpenWorkflow = FinderOpenWorkflow(libraryWorkflow: libraryWorkflow)
    private(set) var standaloneWindows: [URL: StandaloneDocumentWindow] = [:]
    private var windowsAllowedToClose: Set<NSWindow> = []
    private var pendingFinderURLs: [URL] = []
    private var isApplicationReady = false
    private var libraryRefreshTimer: Timer?
    private var documentOutline: [DocumentOutlineEntry] = []
    private var readingProgress = 0.0
    private var documentWordCount: Int?

    init(libraryWorkflow: LibraryWorkflow = LibraryWorkflow()) {
        self.libraryWorkflow = libraryWorkflow
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpLibraryWindow()
        window.makeKeyAndOrderFront(nil)
        installMenu()
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // AppKit calls local monitors on the main thread, so the event never leaves it.
            nonisolated(unsafe) let event = event
            let handled = MainActor.assumeIsolated { self?.handleKeyDown(event, keyWindow: NSApp.keyWindow) == nil }
            return handled ? nil : event
        }
        restoreLibrary()
        if !pendingFinderURLs.isEmpty {
            let urls = pendingFinderURLs
            pendingFinderURLs = []
            routeFinderOpen(urls)
        }
        libraryRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshLibraryIfNeeded() }
        }
    }

    /// Builds the Library window, its Document view, and its presentation, and starts loading the editor.
    /// Tests call this without the menu, key monitor, Library restore, or refresh timer.
    func setUpLibraryWindow() {
        let coordinator = BridgeCoordinator()
        documentSession = DocumentSession(coordinator: coordinator)
        documentSession.dirtyStateDidChange = { [weak self] _ in
            self?.updateWindowTitle()
            self?.refreshWindowPresentation()
        }
        documentSession.availabilityDidChange = { [weak self] availability in
            self?.documentController.show(availability: availability)
            self?.updateWindowTitle()
            self?.refreshWindowPresentation()
        }
        documentSession.conflictDidChange = { [weak self] conflict in
            guard let self else { return }
            self.updateWindowTitle()
            self.refreshWindowPresentation()
            self.presentConflict(conflict, for: self.documentSession, in: self.window)
        }
        documentSession.navigationStateDidChange = { [weak self] outline, progress, wordCount in
            guard let self else { return }
            self.documentOutline = outline
            self.readingProgress = progress
            self.documentWordCount = wordCount
            self.sidebarController.showDocumentNavigation(outline: outline, progress: progress)
            self.refreshWindowPresentation()
        }
        sidebarController.chooseLibrary = { [weak self] in self?.handleChooseLibrary() }
        sidebarController.selectDocument = { [weak self] url in self?.routeFinderOpen([url]) }
        sidebarController.folderExpansionChanged = { [weak self] node, expanded in self?.libraryWorkflow.setFolder(node, expanded: expanded) }
        sidebarController.selectOutline = { [weak self] id in self?.selectOutline(id) }
        documentController = DocumentPresentationViewController(webView: coordinator.webView)
        splitController.addSplitViewItem(NSSplitViewItem(sidebarWithViewController: sidebarController))
        splitController.addSplitViewItem(NSSplitViewItem(viewController: documentController))

        window = makeLibraryWindow()
        libraryPresentation = PaperbranchWindowPresentation(
            window: window,
            webView: coordinator.webView,
            onSelectDocument: { [weak self] url in self?.routeFinderOpen([url]) },
            onSelectOutline: { [weak self] id in self?.selectOutline(id) },
            restoreAppKitContent: { [weak self] in self?.documentController.restoreDocumentView() },
            onToggleSidebar: { [weak self] in self?.toggleLibrarySidebar() },
            onOpen: { [weak self] in self?.handleOpen() },
            onSetFolderExpanded: { [weak self] node, expanded in
                self?.libraryWorkflow.setFolder(node, expanded: expanded)
                self?.showLibrary()
            },
            onChooseLibrary: { [weak self] in self?.handleChooseLibrary() },
            onReconnect: { [weak self] in self?.reconnectLibrary() }
        )
        coordinator.load(url: HarnessLocation.url)
        isApplicationReady = true
    }

    func makeLibraryWindow() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 720), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Paperbranch"
        window.contentViewController = splitController
        window.delegate = self
        let toolbar = NSToolbar(identifier: "PaperbranchToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
        // Assigning the content view controller shrinks the window to the split view's fitting size.
        window.setContentSize(NSSize(width: 960, height: 720))
        window.center()
        window.identifier = Self.libraryWindowIdentifier
        // Not AppKit's frame autosave: it drops a visible toolbar's height when saving and adds it back when
        // restoring, and Variant B hides the toolbar, so the window grew by that height at every launch.
        if let saved = UserDefaults.standard.string(forKey: Self.libraryWindowFrameKey) {
            let frame = NSRectFromString(saved)
            if frame.width > 0, frame.height > 0, NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) {
                window.setFrame(frame, display: false)
            }
        }
        return window
    }

    nonisolated static let libraryWindowFrameKey = "Paperbranch.libraryWindowFrame"
    private static let libraryWindowIdentifier = NSUserInterfaceItemIdentifier("PaperbranchLibraryWindow")

    func windowDidResize(_ notification: Notification) { saveLibraryWindowFrame(notification) }
    func windowDidMove(_ notification: Notification) { saveLibraryWindowFrame(notification) }

    /// Saves the Library window's full frame, which is the same in both presentations.
    private func saveLibraryWindowFrame(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window.identifier == Self.libraryWindowIdentifier,
              !window.styleMask.contains(.fullScreen) else { return }
        UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: Self.libraryWindowFrameKey)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        routeFinderOpen([URL(fileURLWithPath: filename)])
        return true
    }

    func application(_ application: NSApplication, openFiles filenames: [String]) {
        routeFinderOpen(filenames.map(URL.init(fileURLWithPath:)))
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [.toggleLibrarySidebar, .flexibleSpace, .chooseLibrary] }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [.toggleLibrarySidebar, .flexibleSpace, .chooseLibrary] }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: id)
        if id == .toggleLibrarySidebar {
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

    func routeFinderOpen(_ urls: [URL]) {
        guard isApplicationReady else { pendingFinderURLs.append(contentsOf: urls); return }
        // A Library document other than the open one replaces it, so unsaved edits there ask first (Ticket 35).
        let replacing = Set(urls.map(\.standardizedFileURL).filter { $0 != documentSession.fileURL && isInLibrary($0) })
        guard documentSession.isDirty, !replacing.isEmpty else { return openRouted(urls) }
        confirmLibraryDocumentSwitch { [weak self] proceed in
            guard let self else { return }
            if proceed { return self.openRouted(urls) }
            // Cancel keeps the edited document, so the sidebar's selection returns to it.
            self.sidebarController.select(url: self.documentSession.fileURL)
            self.refreshWindowPresentation()
            let others = urls.filter { !replacing.contains($0.standardizedFileURL) }
            if !others.isEmpty { self.openRouted(others) }
        }
    }

    private func isInLibrary(_ url: URL) -> Bool {
        libraryWorkflow.library?.root.flattened().contains { $0.kind == .document && $0.url == url } ?? false
    }

    /// Asks with the close alert. Save uses the conflict-aware save path, so a document changed on disk
    /// still gets the overwrite warning, and cancelling that warning cancels the switch.
    private func confirmLibraryDocumentSwitch(_ completion: @escaping (Bool) -> Void) {
        let session: DocumentSession = documentSession
        beginUnsavedChangesAlert(for: session, on: window) { [weak self] response in
            guard let self else { return }
            switch response {
            case .alertFirstButtonReturn: self.save(session, in: self.window, afterSave: { completion(true) }, afterCancel: { completion(false) })
            case .alertThirdButtonReturn: completion(true)
            default: completion(false)
            }
        }
    }

    /// The design skill's "Unsaved edits on switch or close": Save is the default and Discard is destructive.
    private func beginUnsavedChangesAlert(for session: DocumentSession, on window: NSWindow, completion: @escaping (NSApplication.ModalResponse) -> Void) {
        let alert = NSAlert(); alert.messageText = "Save changes to \(session.fileURL?.lastPathComponent ?? "this document")?"; alert.informativeText = "Your edits will be lost if you do not save them."
        let save = alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Discard").hasDestructiveAction = true
        alert.beginSheetModal(for: window, completionHandler: completion)
        // With a destructive button present AppKit leaves Return unassigned once the sheet appears, so Save gets it here.
        save.keyEquivalent = "\r"
    }

    private func openRouted(_ urls: [URL]) {
        Task { [weak self] in guard let self else { return }; do {
            let results = try await finderOpenWorkflow.applicationDidReceiveFinderOpen(urls)
            for result in results {
                switch result {
                case let .opened(state):
                    if state.kind == .library { try await openLibraryDocument(at: state.documentURL) }
                    else { try await openStandaloneDocument(at: state.documentURL) }
                case let .focused(state):
                    if state.kind == .library { showFocusedLibraryDocument(at: state.documentURL) }
                    else { standaloneWindows[state.documentURL]?.window.makeKeyAndOrderFront(nil) }
                }
            }
        } catch { presentError(error, for: urls.first) } }
    }

    private func openLibraryDocument(at url: URL) async throws {
        try await documentSession.open(url)
        sidebarController.select(url: url)
        updateWindowTitle()
        refreshWindowPresentation()
        window.makeKeyAndOrderFront(nil)
    }

    /// The document is already open in the Library window, and focusing it may have selected it again (Ticket 51).
    private func showFocusedLibraryDocument(at url: URL) {
        sidebarController.select(url: url)
        refreshWindowPresentation()
        window.makeKeyAndOrderFront(nil)
    }

    private func selectOutline(_ id: String) {
        Task { [weak self] in _ = try? await self?.documentSession.coordinator.selectOutline(id: id) }
    }

    func openStandaloneDocument(at url: URL) async throws {
        let standalone = StandaloneDocumentWindow(delegate: self)
        standalone.session.dirtyStateDidChange = { [weak standalone] _ in
            standalone?.updateTitle()
            standalone?.refresh()
        }
        standalone.session.availabilityDidChange = { [weak standalone] _ in
            standalone?.updateTitle()
            standalone?.refresh()
        }
        standalone.session.conflictDidChange = { [weak self, weak standalone] conflict in
            guard let self, let standalone else { return }
            standalone.updateTitle()
            standalone.refresh()
            self.presentConflict(conflict, for: standalone.session, in: standalone.window)
        }
        standalone.session.navigationStateDidChange = { [weak standalone] outline, progress, _ in
            standalone?.showNavigation(outline: outline, progress: progress)
        }
        try await standalone.session.open(url)
        standalone.updateTitle()
        standalone.refresh()
        standalone.window.makeKeyAndOrderFront(nil)
        standaloneWindows[url.standardizedFileURL] = standalone
    }

    @objc private func handleSave() {
        guard let session = activeDocumentSession, session.fileURL != nil else { return }
        save(session, in: window(for: session))
    }

    /// Takes Command-S before the Document view does. WKWebView claims every key equivalent while it has
    /// focus, and in the Variant B presentation its handback of an unhandled Command-S never reached the File menu.
    func handleKeyDown(_ event: NSEvent, keyWindow: NSWindow?) -> NSEvent? {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.capsLock, .numericPad, .function]) == .command,
              event.charactersIgnoringModifiers?.lowercased() == "s",
              let keyWindow, keyWindow.attachedSheet == nil,
              let session = documentSession(for: keyWindow), session.fileURL != nil
        else { return event }
        save(session, in: keyWindow)
        return nil
    }

    @objc private func toggleLibrarySidebar() {
        splitController.splitViewItems.first?.isCollapsed.toggle()
        libraryWorkflow.toggleSidebar()
        refreshWindowPresentation()
    }

    private func restoreLibrary() {
        do {
            switch try libraryWorkflow.restoreLibrary() {
            case .restored:
                showLibrary()
                if let selected = libraryWorkflow.selectedDocumentURL { routeFinderOpen([selected]) }
            case .unavailable:
                sidebarController.showUnavailableLibrary(name: unavailableLibraryName)
                refreshWindowPresentation()
            }
        } catch {
            sidebarController.showUnavailableLibrary(name: unavailableLibraryName)
            refreshWindowPresentation()
        }
    }

    private var unavailableLibraryName: String? {
        if case let .unavailable(name) = libraryWorkflow.availability { return name }
        return nil
    }

    /// The Library unavailable state's Reconnect: try the saved Library again, keeping the window as it is.
    private func reconnectLibrary() {
        restoreLibrary()
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
            sidebarController.showUnavailableLibrary(name: unavailableLibraryName)
            refreshWindowPresentation()
        }
    }

    func showLibrary() {
        guard let library = libraryWorkflow.library else { return }
        sidebarController.show(library, sidebarState: libraryWorkflow.sidebarState, selectedDocumentURL: libraryWorkflow.selectedDocumentURL)
        splitController.splitViewItems.first?.isCollapsed = libraryWorkflow.sidebarState.isCollapsed
        refreshWindowPresentation()
    }

    @discardableResult
    private func refreshWindowPresentation() -> Bool {
        libraryPresentation.render(.init(
            library: libraryWorkflow.library,
            libraryAvailability: libraryWorkflow.availability,
            sidebarState: libraryWorkflow.sidebarState,
            selectedDocumentURL: libraryWorkflow.selectedDocumentURL,
            document: .init(
                url: documentSession.fileURL,
                kind: .library,
                availability: documentSession.availability,
                isDirty: documentSession.isDirty,
                conflict: documentSession.conflict
            ),
            outline: documentOutline,
            readingProgress: readingProgress,
            wordCount: documentWordCount
        ))
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

    /// Updates the saved document's own window, which need not be the key window when the save finishes.
    private func updateTitle(for session: DocumentSession) {
        if let standalone = standaloneWindows.values.first(where: { $0.session === session }) { standalone.updateTitle() }
        else { updateWindowTitle() }
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
        // Wording and buttons from the design skill's "Conflict alert" (Ticket 44). Return keeps the edits, so the
        // default button never loses work, and Reload from Disk is marked destructive.
        alert.messageText = "Changes conflict in \(url.lastPathComponent)"
        alert.informativeText = "This document changed on disk while you have unsaved edits. Keep your edits, or reload the version on disk and lose them."
        let keep = alert.addButton(withTitle: "Keep My Edits")
        alert.addButton(withTitle: "Reload from Disk").hasDestructiveAction = true
        alert.beginSheetModal(for: owner) { [weak self] response in
            guard let self else { return }
            if response == .alertSecondButtonReturn {
                Task { do { try await session.reloadDiskVersion(); self.updateWindowTitle() } catch { self.presentError(error, for: session.fileURL) } }
            } else {
                session.keepEditing()
                self.updateWindowTitle()
            }
        }
        // With a destructive button present AppKit leaves Return unassigned, and it settles key equivalents when the
        // sheet appears, so Return is given to Keep My Edits here.
        keep.keyEquivalent = "\r"
    }

    private func save(_ session: DocumentSession, in owner: NSWindow, afterSave: @escaping () -> Void = {}, afterCancel: @escaping () -> Void = {}) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await session.save()
                self.updateTitle(for: session)
                afterSave()
            } catch let error as DocumentSessionError {
                if case .overwriteConfirmationRequired = error {
                    self.presentOverwriteConfirmation(for: session, in: owner, afterOverwrite: afterSave, afterCancel: afterCancel)
                } else {
                    self.presentError(error, for: session.fileURL)
                    afterCancel()
                }
            } catch {
                self.presentError(error, for: session.fileURL)
                afterCancel()
            }
        }
    }

    private func presentOverwriteConfirmation(for session: DocumentSession, in owner: NSWindow, afterOverwrite: @escaping () -> Void = {}, afterCancel: @escaping () -> Void = {}) {
        let alert = NSAlert()
        alert.messageText = "Overwrite newer disk version of \(session.fileURL?.lastPathComponent ?? "this document")?"
        alert.informativeText = "Paperbranch will replace the version changed outside the app with your in-memory edits."
        // Cancel is the default, so Return writes nothing. Overwrite is second and marked destructive.
        // AppKit gives a button titled Cancel the Escape key and leaves Return unassigned. Return is set below, which
        // takes Escape away from it, so a monitor routes Escape to Cancel while this alert is up.
        let cancel = alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Overwrite").hasDestructiveAction = true
        let escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak alert] event in
            nonisolated(unsafe) let event = event
            let cancelled = MainActor.assumeIsolated { alert.map { Self.cancelOnEscape(event, in: $0.window) } ?? false }
            return cancelled ? nil : event
        }
        alert.beginSheetModal(for: owner) { [weak self] response in
            if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
            guard response == .alertSecondButtonReturn, let self else { return afterCancel() }
            Task { do { try await session.save(overwritingExternalChanges: true); self.updateTitle(for: session); afterOverwrite() } catch { self.presentError(error, for: session.fileURL); afterCancel() } }
        }
        // AppKit settles the buttons' key equivalents when the sheet appears, which cleared one set any earlier.
        cancel.keyEquivalent = "\r"
    }

    /// Presses an alert's Cancel button for an Escape key aimed at that alert's window.
    static func cancelOnEscape(_ event: NSEvent, in alertWindow: NSWindow) -> Bool {
        guard event.type == .keyDown, event.keyCode == 53, event.windowNumber == alertWindow.windowNumber,
              let cancel = alertWindow.contentView.flatMap({ firstButton(titled: "Cancel", in: $0) }) else { return false }
        cancel.performClick(nil)
        return true
    }

    private static func firstButton(titled title: String, in view: NSView) -> NSButton? {
        if let button = view as? NSButton, button.title == title { return button }
        return view.subviews.lazy.compactMap { firstButton(titled: title, in: $0) }.first
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let session = documentSession(for: sender), session.isDirty, !windowsAllowedToClose.contains(sender) else { return true }
        beginUnsavedChangesAlert(for: session, on: sender) { [weak self] response in guard let self else { return }; switch response {
        case .alertFirstButtonReturn: save(session, in: sender, afterSave: { self.windowsAllowedToClose.insert(sender); sender.performClose(nil) })
        // The alert sheet is still attached inside this handler, and AppKit ignores a close then.
        case .alertThirdButtonReturn: windowsAllowedToClose.insert(sender); DispatchQueue.main.async { sender.performClose(nil) }
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

private extension NSToolbarItem.Identifier {
    static let chooseLibrary = NSToolbarItem.Identifier("ChooseLibrary")
    // AppKit builds its own item for the standard `.toggleSidebar` identifier, which bypasses the Library workflow.
    static let toggleLibrarySidebar = NSToolbarItem.Identifier("ToggleLibrarySidebar")
}
