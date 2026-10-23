import AppKit
import PaperbranchBridgeCore

@MainActor
final class StandaloneDocumentWindow {
    let coordinator: BridgeCoordinator
    let session: DocumentSession
    let presentation: PaperbranchStandalonePresentation
    let window: NSWindow
    private var outline: [DocumentOutlineEntry] = []
    private var readingProgress = 0.0

    init(delegate: NSWindowDelegate) {
        coordinator = BridgeCoordinator()
        session = DocumentSession(coordinator: coordinator)
        let coordinator = coordinator
        presentation = PaperbranchStandalonePresentation(webView: coordinator.webView) { id in
            Task { _ = try? await coordinator.selectOutline(id: id) }
        }
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        // AppDelegate owns this window, so closing it must not release it a second time.
        window.isReleasedWhenClosed = false
        window.delegate = delegate
        // The guideline's Standalone chrome (Ticket 45): top bar with the window buttons, progress line, Document view.
        presentation.install(in: window)
        window.setContentSize(NSSize(width: 800, height: 640))
        window.center()
        refresh()
        coordinator.load(url: HarnessLocation.url)
    }

    /// Keeps the latest outline and progress, then redraws the chrome.
    func showNavigation(outline: [DocumentOutlineEntry], progress: Double) {
        self.outline = outline
        readingProgress = progress
        refresh()
    }

    func refresh() {
        presentation.render(.init(
            documentURL: session.fileURL,
            isDirty: session.isDirty,
            conflict: session.conflict,
            availability: session.availability,
            outline: outline,
            readingProgress: readingProgress
        ))
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
