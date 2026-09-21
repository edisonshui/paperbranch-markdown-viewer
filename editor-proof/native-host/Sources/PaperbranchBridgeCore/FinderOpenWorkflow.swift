import Foundation

public enum DocumentWindowKind: Equatable {
    case library
    case standalone
}

/// Observable document-window state for the Finder-open application seam.
public struct DocumentWindowState: Equatable {
    public let documentURL: URL
    public let kind: DocumentWindowKind

    public init(documentURL: URL, kind: DocumentWindowKind) {
        self.documentURL = documentURL.standardizedFileURL
        self.kind = kind
    }
}

public enum FinderOpenResult: Equatable {
    case opened(DocumentWindowState)
    case focused(DocumentWindowState)
}

/// Routes Finder-open events by current Library membership. The AppKit shell
/// owns the actual windows, while this workflow makes their user-visible
/// routing state testable with real files.
@MainActor
public final class FinderOpenWorkflow {
    private let libraryWorkflow: LibraryWorkflow
    private let makeDocumentSession: (() -> DocumentSession)?
    private var sessions: [URL: DocumentSession] = [:]
    public private(set) var openWindows: [DocumentWindowState] = []
    public private(set) var focusedDocumentURL: URL?

    public init(libraryWorkflow: LibraryWorkflow, makeDocumentSession: (() -> DocumentSession)? = nil) {
        self.libraryWorkflow = libraryWorkflow
        self.makeDocumentSession = makeDocumentSession
    }

    @discardableResult
    public func applicationDidReceiveFinderOpen(_ urls: [URL]) async throws -> [FinderOpenResult] {
        var results: [FinderOpenResult] = []
        for url in urls {
            results.append(try await open(url))
        }
        return results
    }

    public func documentSession(for url: URL) -> DocumentSession? {
        sessions[url.standardizedFileURL]
    }

    public func documentWindowDidClose(for url: URL) {
        let documentURL = url.standardizedFileURL
        sessions[documentURL] = nil
        openWindows.removeAll { $0.documentURL == documentURL }
        if focusedDocumentURL == documentURL { focusedDocumentURL = nil }
    }

    private func open(_ url: URL) async throws -> FinderOpenResult {
        guard DocumentSession.accepts(url) else { throw DocumentSessionError.unsupportedFile(url) }
        let documentURL = url.standardizedFileURL
        if sessions[documentURL] != nil {
            focusedDocumentURL = documentURL
            return .focused(try existingWindow(for: documentURL))
        }
        if makeDocumentSession == nil, let existing = openWindows.first(where: { $0.documentURL == documentURL }) {
            focusedDocumentURL = documentURL
            return .focused(existing)
        }

        let opensInLibrary = isInLibrary(documentURL)
        if opensInLibrary, let priorLibraryWindow = openWindows.first(where: { $0.kind == .library }) {
            sessions[priorLibraryWindow.documentURL] = nil
            openWindows.removeAll { $0.kind == .library }
        }

        if let makeDocumentSession {
            let session = makeDocumentSession()
            try await session.open(documentURL)
            sessions[documentURL] = session
        }

        let state: DocumentWindowState
        if opensInLibrary {
            libraryWorkflow.selectDocument(at: documentURL)
            state = DocumentWindowState(documentURL: documentURL, kind: .library)
        } else {
            state = DocumentWindowState(documentURL: documentURL, kind: .standalone)
        }
        openWindows.append(state)
        focusedDocumentURL = documentURL
        return .opened(state)
    }

    private func existingWindow(for url: URL) throws -> DocumentWindowState {
        guard let existing = openWindows.first(where: { $0.documentURL == url }) else {
            throw DocumentSessionError.noDocument
        }
        return existing
    }

    private func isInLibrary(_ url: URL) -> Bool {
        libraryWorkflow.library?.root.flattened().contains { node in
            node.kind == .document && node.url == url
        } ?? false
    }
}
