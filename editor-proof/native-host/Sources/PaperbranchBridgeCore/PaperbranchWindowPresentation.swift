import AppKit
import SwiftUI
import WebKit

/// The semantic facts that decide whether the SwiftUI Library presentation is safe to show.
public struct PaperbranchDocumentPresentationState {
    public let url: URL?
    public let kind: DocumentWindowKind
    public let availability: DocumentAvailability
    public let isDirty: Bool
    public let conflict: DocumentConflict?

    public init(url: URL?, kind: DocumentWindowKind, availability: DocumentAvailability, isDirty: Bool, conflict: DocumentConflict?) {
        self.url = url?.standardizedFileURL
        self.kind = kind
        self.availability = availability
        self.isDirty = isDirty
        self.conflict = conflict
    }
}

/// Snapshot consumed by the window-presentation seam. A missing document means a pending open or an empty Library.
public struct PaperbranchWindowPresentationState {
    public let library: LibraryBrowser?
    public let sidebarState: LibrarySidebarState
    public let selectedDocumentURL: URL?
    public let document: PaperbranchDocumentPresentationState?
    public let outline: [DocumentOutlineEntry]
    public let readingProgress: Double

    public init(
        library: LibraryBrowser?,
        sidebarState: LibrarySidebarState,
        selectedDocumentURL: URL?,
        document: PaperbranchDocumentPresentationState?,
        outline: [DocumentOutlineEntry] = [],
        readingProgress: Double = 0
    ) {
        self.library = library
        self.sidebarState = sidebarState
        self.selectedDocumentURL = selectedDocumentURL?.standardizedFileURL
        self.document = document
        self.outline = outline
        self.readingProgress = max(0, min(1, readingProgress))
    }
}

/// Owns only the presentation swap for the existing Library window. Its one-snapshot interface keeps eligibility and synchronous restoration local.
@MainActor
public final class PaperbranchWindowPresentation {
    public let window: NSWindow

    private let webView: WKWebView
    private let onSelectDocument: (URL) -> Void
    private let onSelectOutline: (String) -> Void
    private let onToggleSidebar: () -> Void
    private let restoreAppKitContent: () -> Void
    private let appKitContentViewController: NSViewController?
    private let appKitContentView: NSView?
    private let hostingView = NSHostingView(rootView: AnyView(EmptyView()))
    private var renderedDocumentURLs: Set<URL> = []
    private var renderedOutlineIDs: Set<String> = []
    private var isShowingSwiftUI = false

    public init(
        window: NSWindow,
        webView: WKWebView,
        onSelectDocument: @escaping (URL) -> Void = { _ in },
        onSelectOutline: @escaping (String) -> Void = { _ in },
        restoreAppKitContent: @escaping () -> Void = {},
        onToggleSidebar: @escaping () -> Void = {}
    ) {
        self.window = window
        self.webView = webView
        self.onSelectDocument = onSelectDocument
        self.onSelectOutline = onSelectOutline
        self.restoreAppKitContent = restoreAppKitContent
        self.onToggleSidebar = onToggleSidebar
        appKitContentViewController = window.contentViewController
        appKitContentView = window.contentView
    }

    /// Returns whether SwiftUI is visible. An ineligible snapshot restores AppKit before the caller can display that state.
    @discardableResult
    public func render(_ state: PaperbranchWindowPresentationState) -> Bool {
        guard let library = state.library,
              let selectedDocumentURL = state.selectedDocumentURL,
              let document = state.document,
              document.kind == .library,
              document.url == selectedDocumentURL,
              document.availability == .available,
              !document.isDirty,
              document.conflict == nil,
              !state.sidebarState.isCollapsed,
              everyFolderIsExpanded(in: library, sidebarState: state.sidebarState),
              library.root.flattened().contains(where: { $0.kind == .document && $0.url == selectedDocumentURL })
        else {
            restoreAppKitPresentation()
            return false
        }

        renderedDocumentURLs = Set(library.root.flattened().compactMap { $0.kind == .document ? $0.url : nil })
        renderedOutlineIDs = Set(state.outline.map(\.id))
        hostingView.rootView = AnyView(PaperbranchLibraryWindowView(
            library: library,
            selectedDocumentURL: selectedDocumentURL,
            outline: state.outline,
            readingProgress: state.readingProgress,
            webView: webView,
            selectDocument: selectDocument(at:),
            selectOutline: selectOutline(id:),
            toggleSidebar: toggleSidebar
        ))
        hostingView.setAccessibilityLabel("Paperbranch Library")
        hostingView.setAccessibilityIdentifier("paperbranch.library.window")
        if !isShowingSwiftUI {
            window.contentViewController = nil
            window.contentView = hostingView
            isShowingSwiftUI = true
        }
        return true
    }

    /// Restores the exact AppKit window content synchronously. AppKit continues to own delegates, commands, sheets, and workflows.
    public func restoreAppKitPresentation() {
        guard isShowingSwiftUI else { return }
        restoreAppKitContent()
        if let appKitContentViewController {
            window.contentViewController = appKitContentViewController
        } else {
            window.contentView = appKitContentView
        }
        renderedDocumentURLs = []
        renderedOutlineIDs = []
        isShowingSwiftUI = false
    }

    /// Dispatches a selection only when it belongs to the rendered Library.
    public func selectDocument(at url: URL) {
        let url = url.standardizedFileURL
        guard renderedDocumentURLs.contains(url) else { return }
        onSelectDocument(url)
    }

    /// Dispatches an outline action only for navigation state rendered by this presentation.
    public func selectOutline(id: String) {
        guard renderedOutlineIDs.contains(id) else { return }
        onSelectOutline(id)
    }

    /// Returns the Library window to AppKit before letting its existing toggle own the collapsed state.
    public func toggleSidebar() {
        restoreAppKitPresentation()
        onToggleSidebar()
    }

    private func everyFolderIsExpanded(in library: LibraryBrowser, sidebarState: LibrarySidebarState) -> Bool {
        library.root.flattened().filter { $0.kind == .folder }.allSatisfy(sidebarState.isExpanded)
    }
}

private struct PaperbranchLibraryWindowView: View {
    let library: LibraryBrowser
    let selectedDocumentURL: URL
    let outline: [DocumentOutlineEntry]
    let readingProgress: Double
    let webView: WKWebView
    let selectDocument: (URL) -> Void
    let selectOutline: (String) -> Void
    let toggleSidebar: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 9) {
                        Text("P")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.10, green: 0.10, blue: 0.09))
                            .frame(width: 25, height: 25)
                            .background(Color(red: 0.91, green: 0.56, blue: 0.41), in: RoundedRectangle(cornerRadius: 7))
                        Text("Paperbranch").font(.system(size: 14, weight: .semibold))
                    }
                    .padding(.bottom, 16)
                    Text("LIBRARY")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.1)
                        .foregroundStyle(Color(red: 0.46, green: 0.47, blue: 0.44))
                    ForEach(library.root.children) { node in
                        PaperbranchLibraryNodeView(node: node, selectedDocumentURL: selectedDocumentURL, depth: 0, selectDocument: selectDocument)
                    }
                    if !outline.isEmpty {
                        Divider().overlay(Color.white.opacity(0.08)).padding(.vertical, 12)
                        Text("ON THIS PAGE")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.1)
                            .foregroundStyle(Color(red: 0.46, green: 0.47, blue: 0.44))
                        ForEach(outline, id: \.id) { entry in
                            Button(action: { selectOutline(entry.id) }) {
                                Text(entry.text).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundStyle(Color(red: 0.66, green: 0.66, blue: 0.62))
                            .padding(.leading, CGFloat(max(0, entry.level - 1)) * 12)
                            .accessibilityIdentifier("paperbranch.library.outline.\(entry.id)")
                        }
                    }
                }.padding(16)
            }
            .frame(minWidth: 240, idealWidth: 252, maxWidth: 280)
            .background(Color(red: 0.10, green: 0.10, blue: 0.09))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Paperbranch Library")
            .accessibilityIdentifier("paperbranch.library.sidebar")
            VStack(spacing: 0) {
                HStack {
                    Button(action: toggleSidebar) {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(red: 0.77, green: 0.76, blue: 0.71))
                            .frame(width: 36, height: 32)
                            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Collapse Library sidebar")
                    .accessibilityIdentifier("paperbranch.reader.toggle-sidebar")
                    Spacer()
                    Text(selectedDocumentURL.lastPathComponent)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0.67, green: 0.65, blue: 0.61))
                    Spacer()
                    Text("Reading")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0.84, green: 0.82, blue: 0.77))
                }
                .frame(height: 66)
                .frame(maxWidth: 1_120)
                .padding(.horizontal, 24)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Reader top bar for \(selectedDocumentURL.lastPathComponent)")
                .accessibilityIdentifier("paperbranch.reader.topbar")

                ZStack(alignment: .top) {
                    Rectangle()
                        .fill(Color(red: 0.91, green: 0.56, blue: 0.41))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .scaleEffect(x: readingProgress, y: 1, anchor: .leading)
                        .accessibilityRepresentation { ProgressView("Reading progress", value: readingProgress) }
                        .accessibilityIdentifier("paperbranch.reader.progress")
                    ZStack {
                        PaperbranchWebView(webView: webView)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .accessibilityIdentifier("paperbranch.document.view")
                    }
                        .frame(maxWidth: 710)
                        .padding(.top, 50)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Document canvas")
                        .accessibilityIdentifier("paperbranch.reader.document-canvas")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack {
                    Text("End of document")
                    Spacer()
                    Text("Local Markdown")
                }
                .font(.system(size: 12))
                .foregroundStyle(Color(red: 0.56, green: 0.55, blue: 0.50))
                .frame(maxWidth: 710)
                .padding(.top, 20)
                .padding(.bottom, 28)
                .overlay(alignment: .top) { Divider().overlay(Color.white.opacity(0.12)) }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Reader footer")
                .accessibilityIdentifier("paperbranch.reader.footer")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.13, green: 0.14, blue: 0.12))
        }
        .background(Color(red: 0.13, green: 0.14, blue: 0.12))
    }
}

private struct PaperbranchLibraryNodeView: View {
    let node: LibraryNode
    let selectedDocumentURL: URL
    let depth: Int
    let selectDocument: (URL) -> Void

    var body: some View {
        switch node.kind {
        case .folder:
            VStack(alignment: .leading, spacing: 4) {
                Text(node.name).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color(red: 0.62, green: 0.62, blue: 0.58)).padding(.leading, CGFloat(depth) * 16)
                ForEach(node.children) { child in
                    PaperbranchLibraryNodeView(node: child, selectedDocumentURL: selectedDocumentURL, depth: depth + 1, selectDocument: selectDocument)
                }
            }
        case .document:
            let selected = node.url == selectedDocumentURL
            Button(action: { selectDocument(node.url) }) { Text(node.name).frame(maxWidth: .infinity, alignment: .leading) }
                .buttonStyle(.plain).font(.system(size: 13)).foregroundStyle(selected ? Color(red: 0.95, green: 0.63, blue: 0.49) : Color(red: 0.66, green: 0.66, blue: 0.62)).padding(.leading, CGFloat(depth) * 16).padding(.vertical, 4)
                .background(selected ? Color(red: 0.91, green: 0.56, blue: 0.41).opacity(0.12) : .clear).clipShape(RoundedRectangle(cornerRadius: 5))
                .accessibilityLabel(selected ? "Selected Markdown document: \(node.name)" : "Markdown document: \(node.name)")
                .accessibilityIdentifier(selected ? "paperbranch.library.selected-document" : "paperbranch.library.document")
        }
    }
}

private struct PaperbranchWebView: NSViewRepresentable {
    let webView: WKWebView
    func makeNSView(context: Context) -> PaperbranchWebViewCanvas { PaperbranchWebViewCanvas(webView: webView) }
    func updateNSView(_ nsView: PaperbranchWebViewCanvas, context: Context) {}
}

/// SwiftUI owns the canvas host while this AppKit view owns the injected WebKit view's layout.
/// Returning `WKWebView` directly left an already-loaded document accessible but unpainted.
private final class PaperbranchWebViewCanvas: NSView {
    init(webView: WKWebView) {
        super.init(frame: .zero)
        webView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
