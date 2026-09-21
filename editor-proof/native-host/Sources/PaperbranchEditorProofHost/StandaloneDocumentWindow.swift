import AppKit
import PaperbranchBridgeCore

@MainActor
final class StandaloneDocumentWindow {
    let coordinator: BridgeCoordinator
    let session: DocumentSession
    let presentation: DocumentPresentationViewController
    let window: NSWindow

    init(delegate: NSWindowDelegate) {
        coordinator = BridgeCoordinator()
        session = DocumentSession(coordinator: coordinator)
        presentation = DocumentPresentationViewController(webView: coordinator.webView)
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.delegate = delegate
        window.contentViewController = presentation
        coordinator.load(url: HarnessLocation.url)
    }

    func updateTitle() {
        guard let url = session.fileURL else {
            window.title = "Paperbranch"
            window.isDocumentEdited = false
            return
        }
        if session.availability != .available { window.title = "\(url.lastPathComponent) (Unavailable)" }
        else if session.conflict != nil { window.title = "\(url.lastPathComponent) (Conflict)" }
        else { window.title = url.lastPathComponent }
        window.isDocumentEdited = session.isDirty
    }
}
