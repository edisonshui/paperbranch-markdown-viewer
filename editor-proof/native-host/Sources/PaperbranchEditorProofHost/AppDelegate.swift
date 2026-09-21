import AppKit
import PaperbranchBridgeCore

/// Minimal proof host: one window, one WKWebView loading the editor-proof
/// harness, and a Save menu item bound to Command-S. It owns no file
/// access whatsoever -- it only logs what `BridgeCoordinator.requestSave()`
/// returns. Building real file I/O, Library browsing, or persistence is
/// out of scope for Ticket 01.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var coordinator: BridgeCoordinator!

    func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator = BridgeCoordinator()
        coordinator.delegate = self

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Paperbranch editor proof host"
        window.contentView = coordinator.webView
        window.center()
        window.makeKeyAndOrderFront(nil)

        installMenu()

        coordinator.load(url: HarnessLocation.url)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func installMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(
            withTitle: "Quit Paperbranch editor proof host",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu

        // This is the item the "Command-S reaches the native host even
        // with focus inside the editor" checkbox is about: AppKit resolves
        // a key-equivalent against the main menu before delivering the
        // keyDown to the WKWebView's own key handling, so this fires
        // regardless of which view has first responder status.
        let saveItem = NSMenuItem(
            title: "Save",
            action: #selector(handleSave),
            keyEquivalent: "s"
        )
        saveItem.keyEquivalentModifierMask = [.command]
        saveItem.target = self
        fileMenu.addItem(saveItem)

        NSApp.mainMenu = mainMenu
    }

    @objc private func handleSave() {
        Task {
            do {
                let markdown = try await coordinator.requestSave()
                print(
                    "[paperbranch-proof-host] Command-S requested a save. "
                        + "Received \(markdown.count) characters of serialized Markdown. "
                        + "No file was written."
                )
            } catch {
                print("[paperbranch-proof-host] save request failed: \(error)")
            }
        }
    }
}

extension AppDelegate: BridgeCoordinatorDelegate {
    func bridgeCoordinator(_ coordinator: BridgeCoordinator, dirtyStateChanged dirty: Bool) {
        print("[paperbranch-proof-host] dirty state changed: \(dirty)")
    }
}
