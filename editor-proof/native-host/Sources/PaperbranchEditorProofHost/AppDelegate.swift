import AppKit
import PaperbranchBridgeCore
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSToolbarDelegate {
    private var window: NSWindow!
    private var documentSession: DocumentSession!
    private var allowClosingDirtyWindow = false
    private let sidebarController = LibrarySidebarViewController()
    private let documentController = NSViewController()
    private let splitController = NSSplitViewController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let coordinator = BridgeCoordinator()
        documentSession = DocumentSession(coordinator: coordinator)
        documentSession.dirtyStateDidChange = { [weak self] _ in self?.updateWindowTitle() }
        sidebarController.chooseLibrary = { [weak self] in self?.handleChooseLibrary() }
        sidebarController.selectDocument = { [weak self] url in self?.openDocument(at: url) }
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
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

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
                let library = try LibraryBrowser.choose(url)
                self?.sidebarController.show(library)
                self?.splitController.splitViewItems.first?.isCollapsed = false
            } catch { self?.presentError(error, for: url) }
        }
    }

    @objc private func handleOpen() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "md")!, .init(filenameExtension: "markdown")!]
        panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
        panel.beginSheetModal(for: window) { [weak self] response in guard response == .OK, let url = panel.url else { return }; self?.openDocument(at: url) }
    }

    private func openDocument(at url: URL) {
        Task { [weak self] in guard let self else { return }; do {
            try await documentSession.open(url)
            sidebarController.select(url: url)
            updateWindowTitle()
        } catch { presentError(error, for: url) } }
    }

    @objc private func handleSave() {
        Task { [weak self] in guard let self, documentSession.fileURL != nil else { return }; do { try await documentSession.save(); updateWindowTitle() } catch { presentError(error, for: documentSession.fileURL) } }
    }

    @objc private func toggleLibrarySidebar() { splitController.splitViewItems.first?.isCollapsed.toggle() }

    private func updateWindowTitle() {
        guard let url = documentSession.fileURL else { window.title = "Paperbranch"; window.isDocumentEdited = false; return }
        window.title = url.lastPathComponent; window.isDocumentEdited = documentSession.isDirty
    }

    private func presentError(_ error: Error, for url: URL?) {
        let alert = NSAlert(error: error); alert.messageText = "Could not open or save \(url?.lastPathComponent ?? "document")"; alert.beginSheetModal(for: window)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard documentSession.isDirty, !allowClosingDirtyWindow else { return true }
        let alert = NSAlert(); alert.messageText = "Save changes to \(documentSession.fileURL?.lastPathComponent ?? "this document")?"; alert.informativeText = "Your edits will be lost if you do not save them."
        alert.addButton(withTitle: "Save"); alert.addButton(withTitle: "Cancel"); alert.addButton(withTitle: "Discard")
        alert.beginSheetModal(for: sender) { [weak self] response in guard let self else { return }; switch response {
        case .alertFirstButtonReturn: Task { do { try await self.documentSession.save(); self.allowClosingDirtyWindow = true; sender.performClose(nil) } catch { self.presentError(error, for: self.documentSession.fileURL) } }
        case .alertThirdButtonReturn: allowClosingDirtyWindow = true; sender.performClose(nil)
        default: break
        } }
        return false
    }
}

private extension NSToolbarItem.Identifier { static let chooseLibrary = NSToolbarItem.Identifier("ChooseLibrary") }
