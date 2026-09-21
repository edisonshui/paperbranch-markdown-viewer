import Foundation

public enum DocumentSessionError: LocalizedError {
    case unsupportedFile(URL)
    case noDocument

    public var errorDescription: String? {
        switch self {
        case let .unsupportedFile(url):
            return "\(url.lastPathComponent) is not a Markdown document."
        case .noDocument:
            return "No Markdown document is open."
        }
    }
}

/// Native ownership for one open Markdown document. It is intentionally
/// responsible for paths and writes, leaving the web editor only content and
/// dirty-state messages.
@MainActor
public final class DocumentSession: NSObject, BridgeCoordinatorDelegate {
    public let coordinator: BridgeCoordinator
    public private(set) var fileURL: URL?
    public private(set) var isDirty = false
    public private(set) var lastError: Error?
    public var dirtyStateDidChange: ((Bool) -> Void)?

    public init(coordinator: BridgeCoordinator) {
        self.coordinator = coordinator
        super.init()
        coordinator.delegate = self
    }

    public static func accepts(_ url: URL) -> Bool {
        ["md", "markdown"].contains(url.pathExtension.lowercased())
    }

    public func open(_ url: URL) async throws {
        guard Self.accepts(url) else { throw DocumentSessionError.unsupportedFile(url) }
        let markdown = try String(contentsOf: url, encoding: .utf8)
        try await coordinator.waitForNativeBridge()
        coordinator.authorizeImages(for: url)
        try await coordinator.loadDocument(markdown: markdown)
        fileURL = url.standardizedFileURL
        isDirty = false
        lastError = nil
    }

    /// Serializes and writes only for an explicit native save command. A
    /// failure deliberately leaves the editor baseline and dirty state alone.
    public func save() async throws {
        guard let fileURL else { throw DocumentSessionError.noDocument }
        do {
            let markdown = try await coordinator.requestSave()
            try coordinatedWrite(markdown, to: fileURL)
            try await coordinator.saveSucceeded(markdown: markdown)
            isDirty = false
            lastError = nil
        } catch {
            lastError = error
            throw error
        }
    }

    private func coordinatedWrite(_ markdown: String, to url: URL) throws {
        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) {
            coordinatedURL in
            do {
                try markdown.write(to: coordinatedURL, atomically: true, encoding: .utf8)
            } catch {
                writeError = error
            }
        }
        if let coordinationError { throw coordinationError }
        if let writeError { throw writeError }
    }

    public func bridgeCoordinatorDidFinishLoadingHarness(_ coordinator: BridgeCoordinator) {}

    public func bridgeCoordinator(_ coordinator: BridgeCoordinator, dirtyStateChanged dirty: Bool) {
        isDirty = dirty
        dirtyStateDidChange?(dirty)
    }
}
