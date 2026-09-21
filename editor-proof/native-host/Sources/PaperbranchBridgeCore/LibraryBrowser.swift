import Foundation

/// A read-only representation of the user-selected Library. Its nodes are
/// deliberately relative to the Library root so the sidebar can mirror the
/// on-disk hierarchy without receiving a file-writing capability.
public struct LibraryNode: Identifiable, Equatable {
    public enum Kind: Equatable {
        case folder
        case document
    }

    public let url: URL
    public let name: String
    public let kind: Kind
    public let children: [LibraryNode]

    public var id: URL { url }

    public func flattened() -> [LibraryNode] {
        [self] + children.flatMap { $0.flattened() }
    }
}

public enum LibraryBrowserError: LocalizedError {
    case notDirectory(URL)

    public var errorDescription: String? {
        switch self {
        case let .notDirectory(url):
            return "\(url.lastPathComponent) is not a folder."
        }
    }
}

/// User-visible sidebar state for the current Library window. Variant B keeps
/// the Library available on demand, while folders retain their own expansion
/// choices independently of the whole-sidebar collapse.
public struct LibrarySidebarState {
    public private(set) var isCollapsed = false
    private var collapsedFolders: Set<URL> = []

    public init() {}

    public func isExpanded(_ node: LibraryNode) -> Bool {
        node.kind == .folder && !collapsedFolders.contains(node.url)
    }

    public mutating func toggleFolder(_ node: LibraryNode) {
        guard node.kind == .folder else { return }
        if !collapsedFolders.insert(node.url).inserted {
            collapsedFolders.remove(node.url)
        }
    }

    public mutating func setExpanded(_ node: LibraryNode, expanded: Bool) {
        guard node.kind == .folder else { return }
        if expanded {
            collapsedFolders.remove(node.url)
        } else {
            collapsedFolders.insert(node.url)
        }
    }

    public mutating func toggleCollapsed() {
        isCollapsed.toggle()
    }

    public mutating func restore(isCollapsed: Bool, collapsedFolders: Set<URL>) {
        self.isCollapsed = isCollapsed
        self.collapsedFolders = collapsedFolders
    }

    public var collapsedFolderURLs: Set<URL> { collapsedFolders }

    public mutating func discardFoldersNotIn(_ library: LibraryBrowser) {
        let folders = Set(library.root.flattened().filter { $0.kind == .folder }.map(\.url))
        collapsedFolders.formIntersection(folders)
    }
}

/// Native ownership of current-session Library selection and enumeration.
/// Choosing a Library only reads directory metadata. It never changes a file
/// or folder inside the chosen Library.
public final class LibraryBrowser {
    public let rootURL: URL
    public private(set) var root: LibraryNode

    private init(rootURL: URL, root: LibraryNode) {
        self.rootURL = rootURL
        self.root = root
    }

    public static func choose(_ url: URL, fileManager: FileManager = .default) throws -> LibraryBrowser {
        let rootURL = url.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: rootURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw LibraryBrowserError.notDirectory(rootURL)
        }
        let root = try makeFolder(at: rootURL, fileManager: fileManager)
        return LibraryBrowser(rootURL: rootURL, root: root)
    }

    public func refresh(fileManager: FileManager = .default) throws {
        root = try Self.makeFolder(at: rootURL, fileManager: fileManager)
    }

    private static func makeFolder(at url: URL, fileManager: FileManager) throws -> LibraryNode {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey]
        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )

        let children = try contents.compactMap { childURL -> LibraryNode? in
            let values = try childURL.resourceValues(forKeys: keys)
            if values.isDirectory == true {
                let folder = try makeFolder(at: childURL, fileManager: fileManager)
                return folder.children.isEmpty ? nil : folder
            }
            guard values.isRegularFile == true, acceptsMarkdown(childURL) else { return nil }
            return LibraryNode(url: childURL.standardizedFileURL, name: childURL.lastPathComponent, kind: .document, children: [])
        }
        .sorted { lhs, rhs in
            if lhs.kind != rhs.kind { return lhs.kind == .folder }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }

        return LibraryNode(url: url.standardizedFileURL, name: url.lastPathComponent, kind: .folder, children: children)
    }

    private static func acceptsMarkdown(_ url: URL) -> Bool {
        ["md", "markdown"].contains(url.pathExtension.lowercased())
    }
}
