import Foundation

public enum DocumentSessionError: LocalizedError {
    case unsupportedFile(URL)
    case noDocument
    case overwriteConfirmationRequired(URL)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedFile(url):
            return "\(url.lastPathComponent) is not a Markdown document."
        case .noDocument:
            return "No Markdown document is open."
        case let .overwriteConfirmationRequired(url):
            return "\(url.lastPathComponent) changed on disk and requires confirmation before overwrite."
        }
    }
}

public enum DocumentAvailability: Equatable {
    case available
    case unavailable
}

public enum DocumentConflict: Equatable {
    case externalChange(URL)
}

/// Native ownership for one open Markdown document. It is intentionally
/// responsible for paths and writes, leaving the web editor only content and
/// dirty-state messages.
@MainActor
public final class DocumentSession: NSObject, BridgeCoordinatorDelegate {
    public let coordinator: BridgeCoordinator
    public private(set) var fileURL: URL?
    public private(set) var isDirty = false
    public private(set) var availability: DocumentAvailability = .available
    public private(set) var conflict: DocumentConflict?
    public private(set) var lastError: Error?
    public var dirtyStateDidChange: ((Bool) -> Void)?
    public var availabilityDidChange: ((DocumentAvailability) -> Void)?
    public var conflictDidChange: ((DocumentConflict?) -> Void)?
    public var navigationStateDidChange: (([DocumentOutlineEntry], Double) -> Void)?
    private var lastDiskMarkdown: String?
    private var fileChangeMonitor: FileChangeMonitor?

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
        let documentURL = url.standardizedFileURL
        let markdown = try String(contentsOf: documentURL, encoding: .utf8)
        try await coordinator.waitForNativeBridge()
        coordinator.authorizeImages(for: documentURL)
        try await coordinator.loadDocument(markdown: markdown)
        fileChangeMonitor?.cancel()
        fileURL = documentURL
        lastDiskMarkdown = markdown
        isDirty = false
        setConflict(nil)
        setAvailability(.available)
        lastError = nil
        fileChangeMonitor = FileChangeMonitor(documentURL: documentURL) { [weak self] in
            Task { @MainActor [weak self] in
                await self?.reconcileFileSystemSignal()
            }
        }
    }

    /// Serializes and writes only for an explicit native save command. A
    /// failure deliberately leaves the editor baseline and dirty state alone.
    public func save(overwritingExternalChanges: Bool = false) async throws {
        guard let fileURL else { throw DocumentSessionError.noDocument }
        do {
            let currentDiskMarkdown = try String(contentsOf: fileURL, encoding: .utf8)
            if currentDiskMarkdown != lastDiskMarkdown, !overwritingExternalChanges {
                throw DocumentSessionError.overwriteConfirmationRequired(fileURL)
            }
            let markdown = try await coordinator.requestSave()
            try coordinatedWrite(markdown, to: fileURL)
            try await coordinator.saveSucceeded(markdown: markdown)
            lastDiskMarkdown = markdown
            isDirty = false
            setConflict(nil)
            lastError = nil
        } catch {
            lastError = error
            throw error
        }
    }

    /// Resolves an external-change conflict by replacing the in-memory
    /// Document view with the version currently on disk.
    public func reloadDiskVersion() async throws {
        guard let fileURL else { throw DocumentSessionError.noDocument }
        let markdown = try String(contentsOf: fileURL, encoding: .utf8)
        try await coordinator.loadDocument(markdown: markdown)
        lastDiskMarkdown = markdown
        isDirty = false
        setConflict(nil)
        setAvailability(.available)
    }

    /// Resolves the immediate prompt while retaining the in-memory Document
    /// view. The latest disk baseline remains recorded for a later save.
    public func keepEditing() {
        setConflict(nil)
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

    /// File-system events are only hints. This re-reads the known document
    /// path and compares real bytes with the session's completed disk version
    /// before it changes the editor.
    private func reconcileFileSystemSignal() async {
        guard let fileURL, let baselineMarkdown = lastDiskMarkdown else { return }
        do {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                if !isDirty { setAvailability(.unavailable) }
                return
            }
            let diskMarkdown = try String(contentsOf: fileURL, encoding: .utf8)
            guard diskMarkdown != baselineMarkdown else {
                setAvailability(.available)
                return
            }
            guard !isDirty else {
                lastDiskMarkdown = diskMarkdown
                setConflict(.externalChange(fileURL))
                return
            }
            guard try await coordinator.externalReplace(markdown: diskMarkdown) else { return }
            self.lastDiskMarkdown = diskMarkdown
            setAvailability(.available)
        } catch {
            if !isDirty { setAvailability(.unavailable) }
        }
    }

    private func setAvailability(_ availability: DocumentAvailability) {
        guard self.availability != availability else { return }
        self.availability = availability
        availabilityDidChange?(availability)
    }

    private func setConflict(_ conflict: DocumentConflict?) {
        guard self.conflict != conflict else { return }
        self.conflict = conflict
        conflictDidChange?(conflict)
    }

    public func bridgeCoordinatorDidFinishLoadingHarness(_ coordinator: BridgeCoordinator) {}

    public func bridgeCoordinator(_ coordinator: BridgeCoordinator, dirtyStateChanged dirty: Bool) {
        isDirty = dirty
        dirtyStateDidChange?(dirty)
    }

    public func bridgeCoordinator(_ coordinator: BridgeCoordinator, navigationStateChanged outline: [DocumentOutlineEntry], progress: Double) {
        navigationStateDidChange?(outline, progress)
    }
}
