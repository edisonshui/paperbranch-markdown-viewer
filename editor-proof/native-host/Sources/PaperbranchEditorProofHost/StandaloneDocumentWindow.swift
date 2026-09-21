import AppKit
import PaperbranchBridgeCore

@MainActor
final class StandaloneDocumentWindow {
    let coordinator: BridgeCoordinator
    let session: DocumentSession
    let window: NSWindow

    init(delegate: NSWindowDelegate) {
        coordinator = BridgeCoordinator()
        session = DocumentSession(coordinator: coordinator)
        let documentController = NSViewController()
        documentController.view = coordinator.webView
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.delegate = delegate
        window.contentViewController = documentController
        coordinator.load(url: HarnessLocation.url)
    }

    func updateTitle() {
        guard let url = session.fileURL else {
            window.title = "Paperbranch"
            window.isDocumentEdited = false
            return
        }
        window.title = url.lastPathComponent
        window.isDocumentEdited = session.isDirty
    }
}
