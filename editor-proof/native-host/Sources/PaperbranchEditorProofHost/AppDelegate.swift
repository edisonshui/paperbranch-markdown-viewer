import AppKit
import PaperbranchBridgeCore
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow!
    private var documentSession: DocumentSession!
    private var allowClosingDirtyWindow = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let coordinator = BridgeCoordinator()
        documentSession = DocumentSession(coordinator: coordinator)
        documentSession.dirtyStateDidChange = { [weak self] _ in self?.updateWindowTitle() }

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Paperbranch"
        window.contentView = coordinator.webView
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)

        installMenu()
        coordinator.load(url: HarnessLocation.url)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func installMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "Quit Paperbranch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu

        let openItem = NSMenuItem(title: "Open…", action: #selector(handleOpen), keyEquivalent: "o")
        openItem.keyEquivalentModifierMask = [.command]
        openItem.target = self
        fileMenu.addItem(openItem)

        let saveItem = NSMenuItem(title: "Save", action: #selector(handleSave), keyEquivalent: "s")
        saveItem.keyEquivalentModifierMask = [.command]
        saveItem.target = self
        fileMenu.addItem(saveItem)
        NSApp.mainMenu = mainMenu
    }

    @objc private func handleOpen() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "md")!, .init(filenameExtension: "markdown")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.openDocument(at: url)
        }
    }

    private func openDocument(at url: URL) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await documentSession.open(url)
                updateWindowTitle()
            } catch {
                presentError(error, for: url)
            }
        }
    }

    // AppKit resolves this key equivalent through the main menu before the
    // WKWebView receives it, so this native command works with editor focus.
    @objc private func handleSave() {
        Task { [weak self] in
            guard let self, documentSession.fileURL != nil else { return }
            do {
                try await documentSession.save()
                updateWindowTitle()
            } catch {
                presentError(error, for: documentSession.fileURL)
            }
        }
    }

    private func updateWindowTitle() {
        guard let fileURL = documentSession.fileURL else {
            window.title = "Paperbranch"
            window.isDocumentEdited = false
            return
        }
        window.title = fileURL.lastPathComponent
        window.isDocumentEdited = documentSession.isDirty
    }

    private func presentError(_ error: Error, for url: URL?) {
        let alert = NSAlert(error: error)
        alert.messageText = "Could not save \(url?.lastPathComponent ?? "document")"
        alert.beginSheetModal(for: window)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard documentSession.isDirty, !allowClosingDirtyWindow else { return true }
        let alert = NSAlert()
        alert.messageText = "Save changes to \(documentSession.fileURL?.lastPathComponent ?? "this document")?"
        alert.informativeText = "Your edits will be lost if you do not save them."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Discard")
        alert.beginSheetModal(for: sender) { [weak self] response in
            guard let self else { return }
            switch response {
            case .alertFirstButtonReturn:
                Task {
                    do {
                        try await self.documentSession.save()
                        self.allowClosingDirtyWindow = true
                        sender.performClose(nil)
                    } catch {
                        self.presentError(error, for: self.documentSession.fileURL)
                    }
                }
            case .alertThirdButtonReturn:
                allowClosingDirtyWindow = true
                sender.performClose(nil)
            default:
                break
            }
        }
        return false
    }
}
