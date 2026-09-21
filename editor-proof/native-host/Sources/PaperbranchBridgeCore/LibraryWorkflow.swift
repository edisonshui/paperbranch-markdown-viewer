import Foundation

public struct LibraryBookmarkRecord: Codable, Equatable {
    public let bookmark: Data
    public var selectedDocumentURL: URL?
    public var isSidebarCollapsed: Bool
    public var collapsedFolderURLs: Set<URL>

    public init(bookmark: Data, selectedDocumentURL: URL? = nil, isSidebarCollapsed: Bool = false, collapsedFolderURLs: Set<URL> = []) {
        self.bookmark = bookmark
        self.selectedDocumentURL = selectedDocumentURL
        self.isSidebarCollapsed = isSidebarCollapsed
        self.collapsedFolderURLs = collapsedFolderURLs
    }
}

public protocol LibraryBookmarkStore: AnyObject {
    func load() -> LibraryBookmarkRecord?
    func save(_ record: LibraryBookmarkRecord)
    func clear()
}

public final class UserDefaultsLibraryBookmarkStore: LibraryBookmarkStore {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "Paperbranch.libraryBookmark") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> LibraryBookmarkRecord? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(LibraryBookmarkRecord.self, from: data)
    }

    public func save(_ record: LibraryBookmarkRecord) {
        defaults.set(try? JSONEncoder().encode(record), forKey: key)
    }

    public func clear() { defaults.removeObject(forKey: key) }
}

public protocol LibraryBookmarkCodec {
    func makeBookmark(for url: URL) throws -> Data
    func resolveBookmark(_ data: Data) throws -> URL
}

public struct SecurityScopedLibraryBookmarkCodec: LibraryBookmarkCodec {
    public init() {}

    public func makeBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    public func resolveBookmark(_ data: Data) throws -> URL {
        var stale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ).standardizedFileURL
        guard !stale else { throw LibraryAccessError.unavailable }
        return url
    }
}

public enum LibraryAccessError: LocalizedError {
    case unavailable

    public var errorDescription: String? { "Library access is unavailable. Reconnect or choose another Library." }
}

/// Owns the app's security-scoped Library access for the current launch.
/// The bookmark itself is persisted, while access is reacquired and verified
/// every time a Library is restored.
public final class LibraryAccess {
    private let store: LibraryBookmarkStore
    private let codec: LibraryBookmarkCodec
    private var accessedURL: URL?

    public init(store: LibraryBookmarkStore = UserDefaultsLibraryBookmarkStore(), codec: LibraryBookmarkCodec = SecurityScopedLibraryBookmarkCodec()) {
        self.store = store
        self.codec = codec
    }

    deinit { stopAccessing() }

    public func choose(_ url: URL) throws -> URL {
        let resolved = url.standardizedFileURL
        let bookmark = try codec.makeBookmark(for: resolved)
        startAccessing(resolved)
        store.save(LibraryBookmarkRecord(bookmark: bookmark))
        return resolved
    }

    public func restore() throws -> (url: URL, record: LibraryBookmarkRecord) {
        guard let record = store.load() else { throw LibraryAccessError.unavailable }
        let url = try codec.resolveBookmark(record.bookmark)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw LibraryAccessError.unavailable
        }
        startAccessing(url)
        return (url, record)
    }

    public func saveSidebarState(selectedDocumentURL: URL?, sidebarState: LibrarySidebarState) {
        guard var record = store.load() else { return }
        record.selectedDocumentURL = selectedDocumentURL?.standardizedFileURL
        record.isSidebarCollapsed = sidebarState.isCollapsed
        record.collapsedFolderURLs = sidebarState.collapsedFolderURLs
        store.save(record)
    }

    public func clear() { stopAccessing(); store.clear() }

    private func startAccessing(_ url: URL) {
        stopAccessing()
        _ = url.startAccessingSecurityScopedResource()
        accessedURL = url
    }

    private func stopAccessing() {
        accessedURL?.stopAccessingSecurityScopedResource()
        accessedURL = nil
    }
}

public enum LibraryRestoreStatus: Equatable {
    case restored
    case unavailable
}

/// Observable application-workflow state. The AppKit shell presents this in
/// its sidebar, while tests can drive it with real folders without relying on
/// private view-controller details.
public final class LibraryWorkflow {
    private let bookmarks: LibraryAccess
    public private(set) var library: LibraryBrowser?
    public private(set) var selectedDocumentURL: URL?
    public var sidebarState = LibrarySidebarState()

    public init(bookmarks: LibraryAccess = LibraryAccess()) { self.bookmarks = bookmarks }

    public func chooseLibrary(at url: URL) throws {
        let rootURL = try bookmarks.choose(url)
        library = try LibraryBrowser.choose(rootURL)
        selectedDocumentURL = nil
        sidebarState = LibrarySidebarState()
        persistState()
    }

    public func restoreLibrary() throws -> LibraryRestoreStatus {
        do {
            let restored = try bookmarks.restore()
            library = try LibraryBrowser.choose(restored.url)
            selectedDocumentURL = restored.record.selectedDocumentURL
            sidebarState.restore(isCollapsed: restored.record.isSidebarCollapsed, collapsedFolders: restored.record.collapsedFolderURLs)
            preserveValidSidebarState()
            return .restored
        } catch {
            library = nil
            return .unavailable
        }
    }

    public func selectDocument(at url: URL?) {
        guard let url, library?.root.flattened().contains(where: { $0.kind == .document && $0.url == url.standardizedFileURL }) == true else {
            selectedDocumentURL = nil
            persistState()
            return
        }
        selectedDocumentURL = url.standardizedFileURL
        persistState()
    }

    public func toggleFolder(_ node: LibraryNode) {
        sidebarState.toggleFolder(node)
        persistState()
    }

    public func setFolder(_ node: LibraryNode, expanded: Bool) {
        sidebarState.setExpanded(node, expanded: expanded)
        persistState()
    }

    public func toggleSidebar() {
        sidebarState.toggleCollapsed()
        persistState()
    }

    public func refreshLibrary() throws {
        try library?.refresh()
        preserveValidSidebarState()
    }

    public func libraryAccessBecameUnavailable() {
        library = nil
    }

    public func persistState() { bookmarks.saveSidebarState(selectedDocumentURL: selectedDocumentURL, sidebarState: sidebarState) }

    private func preserveValidSidebarState() {
        guard let library else { return }
        sidebarState.discardFoldersNotIn(library)
        if let selectedDocumentURL, !library.root.flattened().contains(where: { $0.kind == .document && $0.url == selectedDocumentURL }) {
            self.selectedDocumentURL = nil
        }
        persistState()
    }
}
