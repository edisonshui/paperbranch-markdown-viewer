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
    /// The editor's count for the meta line. Nil for a blocked document, which has no meta line.
    public let wordCount: Int?

    public init(
        library: LibraryBrowser?,
        sidebarState: LibrarySidebarState,
        selectedDocumentURL: URL?,
        document: PaperbranchDocumentPresentationState?,
        outline: [DocumentOutlineEntry] = [],
        readingProgress: Double = 0,
        wordCount: Int? = nil
    ) {
        self.library = library
        self.sidebarState = sidebarState
        self.selectedDocumentURL = selectedDocumentURL?.standardizedFileURL
        self.document = document
        self.outline = outline
        self.readingProgress = max(0, min(1, readingProgress))
        self.wordCount = wordCount
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
    private let onOpen: () -> Void
    private let onSetFolderExpanded: (LibraryNode, Bool) -> Void
    private let restoreAppKitContent: () -> Void
    private let appKitContentViewController: NSViewController?
    private let appKitContentView: NSView?
    private let hostingView = NSHostingView(rootView: AnyView(EmptyView()))
    private var renderedDocumentURLs: Set<URL> = []
    private var renderedOutlineIDs: Set<String> = []
    private var renderedFolderURLs: Set<URL> = []
    private var isShowingSwiftUI = false

    public init(
        window: NSWindow,
        webView: WKWebView,
        onSelectDocument: @escaping (URL) -> Void = { _ in },
        onSelectOutline: @escaping (String) -> Void = { _ in },
        restoreAppKitContent: @escaping () -> Void = {},
        onToggleSidebar: @escaping () -> Void = {},
        onOpen: @escaping () -> Void = {},
        onSetFolderExpanded: @escaping (LibraryNode, Bool) -> Void = { _, _ in }
    ) {
        self.window = window
        self.webView = webView
        self.onSelectDocument = onSelectDocument
        self.onSelectOutline = onSelectOutline
        self.restoreAppKitContent = restoreAppKitContent
        self.onToggleSidebar = onToggleSidebar
        self.onOpen = onOpen
        self.onSetFolderExpanded = onSetFolderExpanded
        appKitContentViewController = window.contentViewController
        appKitContentView = window.contentView
    }

    /// Returns whether SwiftUI is visible. An ineligible snapshot restores AppKit before the caller can display that state.
    /// Unsaved edits, a conflict, a collapsed sidebar, and a document switch still loading all stay in Variant B,
    /// because swapping the whole window for them made editing and switching jump. AppKit covers only a missing or
    /// empty Library, an unavailable document, and unsaved work behind the empty reader, which Variant B has no state for.
    @discardableResult
    public func render(_ state: PaperbranchWindowPresentationState) -> Bool {
        let documentURLs = Set(state.library?.root.flattened().compactMap { $0.kind == .document ? $0.url : nil } ?? [])
        guard let library = state.library,
              let document = state.document,
              document.kind == .library,
              !documentURLs.isEmpty,
              state.selectedDocumentURL.map(documentURLs.contains) ?? true,
              document.availability == .available,
              // The empty reader hides the open document, so unsaved work there stays visible in AppKit.
              state.selectedDocumentURL != nil || (!document.isDirty && document.conflict == nil)
        else {
            restoreAppKitPresentation()
            return false
        }
        // During a switch the snapshot still holds the previous document's facts, which do not describe the selection.
        let showsSelectedDocument = state.selectedDocumentURL != nil && document.url == state.selectedDocumentURL
        let documentStatus: String? = !showsSelectedDocument ? nil : document.conflict != nil ? "Changed on disk" : document.isDirty ? "Edited" : nil

        // The outline belongs to the selected document, so an empty reader drops the previous document's outline.
        let outline = state.selectedDocumentURL == nil ? [] : state.outline
        renderedDocumentURLs = documentURLs
        renderedOutlineIDs = Set(outline.map(\.id))
        renderedFolderURLs = Set(library.root.flattened().compactMap { $0.kind == .folder ? $0.url : nil })
        hostingView.rootView = AnyView(PaperbranchLibraryWindowView(
            library: library,
            sidebarState: state.sidebarState,
            selectedDocumentURL: state.selectedDocumentURL,
            documentStatus: documentStatus,
            isSidebarCollapsed: state.sidebarState.isCollapsed,
            wordCount: state.wordCount,
            outline: outline,
            readingProgress: state.readingProgress,
            webView: webView,
            selectDocument: selectDocument(at:),
            selectOutline: selectOutline(id:),
            setFolder: setFolder(_:expanded:),
            toggleSidebar: toggleSidebar,
            open: open
        ))
        hostingView.setAccessibilityLabel("Paperbranch Library")
        hostingView.setAccessibilityIdentifier("paperbranch.library.window")
        if !isShowingSwiftUI {
            // Changing the title bar keeps the content size, so keep the user's frame.
            let frame = window.frame
            window.contentViewController = nil
            window.contentView = hostingView
            // Variant B has no title bar row, so the reader top bar names the document and the window buttons sit over the sidebar header.
            // The title stays set for the Window menu and Mission Control.
            window.styleMask.insert(.fullSizeContentView)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.toolbar?.isVisible = false
            window.setFrame(frame, display: true)
            isShowingSwiftUI = true
        }
        return true
    }

    /// Restores the exact AppKit window content synchronously. AppKit continues to own delegates, commands, sheets, and workflows.
    public func restoreAppKitPresentation() {
        guard isShowingSwiftUI else { return }
        restoreAppKitContent()
        // Assigning a content view controller resizes the window to that controller's detached view, and the title bar change
        // keeps the content size, so keep the user's frame.
        let frame = window.frame
        window.styleMask.remove(.fullSizeContentView)
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.toolbar?.isVisible = true
        if let appKitContentViewController {
            window.contentViewController = appKitContentViewController
        } else {
            window.contentView = appKitContentView
        }
        window.setFrame(frame, display: true)
        renderedDocumentURLs = []
        renderedOutlineIDs = []
        renderedFolderURLs = []
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

    /// Dispatches a folder expansion change only for a folder in the rendered Library.
    public func setFolder(_ node: LibraryNode, expanded: Bool) {
        guard node.kind == .folder, renderedFolderURLs.contains(node.url) else { return }
        onSetFolderExpanded(node, expanded)
    }

    /// Runs the existing Open command. Its panel is a sheet on this window, so the reader stays showing until a document is routed.
    public func open() {
        onOpen()
    }

    /// Lets the existing toggle own the collapsed state. The next snapshot hides or shows the Variant B sidebar.
    public func toggleSidebar() {
        onToggleSidebar()
    }
}

private struct PaperbranchLibraryWindowView: View {
    let library: LibraryBrowser
    let sidebarState: LibrarySidebarState
    let selectedDocumentURL: URL?
    /// "Edited" or "Changed on disk" for the selected document, shown after its name in the top bar.
    let documentStatus: String?
    let isSidebarCollapsed: Bool
    let wordCount: Int?
    let outline: [DocumentOutlineEntry]
    let readingProgress: Double
    let webView: WKWebView
    let selectDocument: (URL) -> Void
    let selectOutline: (String) -> Void
    let setFolder: (LibraryNode, Bool) -> Void
    let toggleSidebar: () -> Void
    let open: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            if !isSidebarCollapsed {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 9) {
                            Text("P")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(red: 0.10, green: 0.10, blue: 0.09))
                                .frame(width: 25, height: 25)
                                .background(Color(red: 0.91, green: 0.56, blue: 0.41), in: RoundedRectangle(cornerRadius: 7))
                            // The sidebar is dark in every appearance, so the wordmark keeps Variant B's light ink.
                            Text("Paperbranch")
                                .font(.system(size: 16, weight: .bold))
                                .tracking(-0.3)
                                .foregroundStyle(Color(red: 0.91, green: 0.89, blue: 0.85))
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("paperbranch.library.wordmark")
                        // Clears the window buttons, which AppKit keeps at the window's top left.
                        .padding(.top, 20)
                        .padding(.bottom, 16)
                        // Open now sits above the tree so a long Library cannot push it out of view.
                        if let selectedDocumentURL {
                            PaperbranchSidebarLabel("OPEN NOW")
                            PaperbranchOpenNowView(name: selectedDocumentURL.lastPathComponent, wordCount: wordCount)
                        }
                        PaperbranchSidebarLabel("LIBRARY")
                        ForEach(library.root.children) { node in
                            PaperbranchLibraryNodeView(node: node, sidebarState: sidebarState, selectedDocumentURL: selectedDocumentURL, depth: 0, selectDocument: selectDocument, setFolder: setFolder)
                        }
                        if !outline.isEmpty {
                            Divider().overlay(Color.white.opacity(0.08)).padding(.vertical, 12)
                            PaperbranchSidebarLabel("ON THIS PAGE")
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
            }
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
                    .accessibilityLabel(isSidebarCollapsed ? "Show Library sidebar" : "Collapse Library sidebar")
                    .accessibilityIdentifier("paperbranch.reader.toggle-sidebar")
                    Spacer()
                    if let selectedDocumentURL {
                        HStack(spacing: 8) {
                            Text(selectedDocumentURL.lastPathComponent)
                                .foregroundStyle(Color(red: 0.67, green: 0.65, blue: 0.61))
                            if let documentStatus {
                                Text(documentStatus)
                                    .foregroundStyle(Color(red: 0.91, green: 0.56, blue: 0.41))
                            }
                        }
                        .font(.system(size: 12))
                        Spacer()
                    }
                    Button(action: open) {
                        Text("Open")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(red: 0.95, green: 0.94, blue: 0.90))
                            .padding(.horizontal, 16)
                            .frame(height: 32)
                            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open")
                    .accessibilityIdentifier("paperbranch.reader.open")
                }
                .frame(height: 66)
                .frame(maxWidth: 1_120)
                .padding(.horizontal, 24)
                // With the sidebar hidden, the window buttons sit over the top bar's leading edge.
                .padding(.leading, isSidebarCollapsed ? 60 : 0)
                .background(PaperbranchWindowDragArea())
                .accessibilityElement(children: .contain)
                .accessibilityLabel(selectedDocumentURL.map { ["Reader top bar for \($0.lastPathComponent)", documentStatus].compactMap { $0 }.joined(separator: ", ") } ?? "Reader top bar")
                .accessibilityIdentifier("paperbranch.reader.topbar")

                if selectedDocumentURL == nil {
                    Text("Choose a document from the Library")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(red: 0.56, green: 0.55, blue: 0.50))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Empty reader")
                        .accessibilityIdentifier("paperbranch.reader.empty")
                } else {
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
                    // The Document view ends the article with its footer, so it scrolls with the document.
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.13, green: 0.14, blue: 0.12))
        }
        .background(Color(red: 0.13, green: 0.14, blue: 0.12))
        // The window's content runs under its transparent title bar, so the reader top bar starts at the window's top edge.
        .ignoresSafeArea()
    }
}

private struct PaperbranchSidebarLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(1.1)
            .foregroundStyle(Color(red: 0.46, green: 0.47, blue: 0.44))
    }
}

/// Variant B's Open now entry: the selected document's name and word count, kept as quiet as the tree around it.
private struct PaperbranchOpenNowView: View {
    let name: String
    let wordCount: Int?

    private var wordCountText: String? {
        wordCount.map { "\($0.formatted()) \($0 == 1 ? "word" : "words")" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name).font(.system(size: 13, weight: .medium)).foregroundStyle(Color(red: 0.85, green: 0.84, blue: 0.80)).lineLimit(1).truncationMode(.middle)
            if let wordCountText {
                Text(wordCountText).font(.system(size: 11)).foregroundStyle(Color(red: 0.47, green: 0.48, blue: 0.45))
            }
        }
        .padding(.bottom, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(["Open now: \(name)", wordCountText].compactMap { $0 }.joined(separator: ", "))
        .accessibilityIdentifier("paperbranch.library.open-now")
    }
}

private struct PaperbranchLibraryNodeView: View {
    let node: LibraryNode
    let sidebarState: LibrarySidebarState
    let selectedDocumentURL: URL?
    let depth: Int
    let selectDocument: (URL) -> Void
    let setFolder: (LibraryNode, Bool) -> Void

    var body: some View {
        switch node.kind {
        case .folder:
            let expanded = sidebarState.isExpanded(node)
            VStack(alignment: .leading, spacing: 4) {
                Button(action: { setFolder(node, !expanded) }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .rotationEffect(.degrees(expanded ? 90 : 0))
                            .frame(width: 10)
                        Text(node.name).font(.system(size: 12, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color(red: 0.62, green: 0.62, blue: 0.58))
                .padding(.leading, CGFloat(depth) * 16)
                .accessibilityLabel("Folder: \(node.name), \(expanded ? "expanded" : "collapsed")")
                .accessibilityIdentifier("paperbranch.library.folder")
                if expanded {
                    ForEach(node.children) { child in
                        PaperbranchLibraryNodeView(node: child, sidebarState: sidebarState, selectedDocumentURL: selectedDocumentURL, depth: depth + 1, selectDocument: selectDocument, setFolder: setFolder)
                    }
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

/// The transparent title bar only covers the top of the reader top bar, so the rest of the bar moves the window too.
private struct PaperbranchWindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> PaperbranchWindowDragView { PaperbranchWindowDragView() }
    func updateNSView(_ nsView: PaperbranchWindowDragView, context: Context) {}
}

private final class PaperbranchWindowDragView: NSView {
    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
}

private struct PaperbranchWebView: NSViewRepresentable {
    let webView: WKWebView
    func makeNSView(context: Context) -> PaperbranchWebViewCanvas { PaperbranchWebViewCanvas(webView: webView) }
    func updateNSView(_ nsView: PaperbranchWebViewCanvas, context: Context) {}
}

/// SwiftUI owns the canvas host while this AppKit view owns the injected WebKit view's layout.
/// Returning `WKWebView` directly left an already-loaded document accessible but unpainted.
private final class PaperbranchWebViewCanvas: NSView {
    private let webView: WKWebView

    init(webView: WKWebView) {
        self.webView = webView
        super.init(frame: .zero)
        attachWebView()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// SwiftUI reuses this canvas across presentation swaps, while AppKit restoration moves the web view back out.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { attachWebView() }
    }

    private func attachWebView() {
        guard webView.superview !== self else { return }
        webView.removeFromSuperview()
        webView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}
