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
    /// Why there is no Library, when there is none: never chosen, or chosen and unreachable.
    public let libraryAvailability: LibraryAvailability
    public let sidebarState: LibrarySidebarState
    public let selectedDocumentURL: URL?
    public let document: PaperbranchDocumentPresentationState?
    public let outline: [DocumentOutlineEntry]
    public let readingProgress: Double
    /// The editor's count for the meta line. Nil for a blocked document, which has no meta line.
    public let wordCount: Int?

    public init(
        library: LibraryBrowser?,
        libraryAvailability: LibraryAvailability? = nil,
        sidebarState: LibrarySidebarState,
        selectedDocumentURL: URL?,
        document: PaperbranchDocumentPresentationState?,
        outline: [DocumentOutlineEntry] = [],
        readingProgress: Double = 0,
        wordCount: Int? = nil
    ) {
        self.library = library
        self.libraryAvailability = library != nil ? .available : libraryAvailability ?? .notChosen
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
    private let onChooseLibrary: () -> Void
    private let onReconnect: () -> Void
    private let restoreAppKitContent: () -> Void
    private let appKitContentViewController: NSViewController?
    private let appKitContentView: NSView?
    private let appKitToolbar: NSToolbar?
    /// Empty and unified, so AppKit centers the window buttons in the 52 px top bar's row.
    private let chromeToolbar: NSToolbar = {
        let toolbar = NSToolbar(identifier: "PaperbranchChromeToolbar-\(UUID().uuidString)")
        toolbar.allowsUserCustomization = false
        return toolbar
    }()
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
        onSetFolderExpanded: @escaping (LibraryNode, Bool) -> Void = { _, _ in },
        onChooseLibrary: @escaping () -> Void = {},
        onReconnect: @escaping () -> Void = {}
    ) {
        self.window = window
        self.webView = webView
        self.onSelectDocument = onSelectDocument
        self.onSelectOutline = onSelectOutline
        self.restoreAppKitContent = restoreAppKitContent
        self.onToggleSidebar = onToggleSidebar
        self.onOpen = onOpen
        self.onChooseLibrary = onChooseLibrary
        self.onReconnect = onReconnect
        self.onSetFolderExpanded = onSetFolderExpanded
        appKitContentViewController = window.contentViewController
        appKitContentView = window.contentView
        appKitToolbar = window.toolbar
    }

    /// Returns whether SwiftUI is visible. An ineligible snapshot restores AppKit before the caller can display that state.
    /// Every Library window state has a Variant B home: editing, conflicts, a collapsed sidebar, a switch still loading,
    /// and the state views for a missing Library, an empty Library, and an unavailable document (Ticket 43). AppKit
    /// covers only unsaved work that a state view or the empty reader would hide, a Standalone snapshot, no document
    /// session yet, and a selection outside the Library.
    @discardableResult
    public func render(_ state: PaperbranchWindowPresentationState) -> Bool {
        let documentURLs = Set(state.library?.root.flattened().compactMap { $0.kind == .document ? $0.url : nil } ?? [])
        let hidesOpenDocument = state.library == nil || state.selectedDocumentURL == nil
        guard let document = state.document,
              document.kind == .library,
              state.library == nil || (state.selectedDocumentURL.map(documentURLs.contains) ?? true),
              !(hidesOpenDocument && (document.isDirty || document.conflict != nil))
        else {
            restoreAppKitPresentation()
            return false
        }
        // During a switch the snapshot still holds the previous document's facts, which do not describe the selection.
        let showsSelectedDocument = state.selectedDocumentURL != nil && document.url == state.selectedDocumentURL
        let documentStatus: PBDocumentStatus? = !showsSelectedDocument ? nil : document.conflict != nil ? .changedOnDisk : document.isDirty ? .edited : nil

        // The outline belongs to the selected document, so an empty reader drops the previous document's outline.
        let outline = state.selectedDocumentURL == nil ? [] : state.outline
        renderedDocumentURLs = documentURLs
        renderedOutlineIDs = Set(outline.map(\.id))
        renderedFolderURLs = Set(state.library?.root.flattened().compactMap { $0.kind == .folder ? $0.url : nil } ?? [])
        let content: PaperbranchReaderContent
        if state.library == nil {
            if case let .unavailable(name) = state.libraryAvailability { content = .libraryUnavailable(name: name) } else { content = .choosingLibrary }
        } else if let selected = state.selectedDocumentURL {
            content = showsSelectedDocument && document.availability == .unavailable ? .documentUnavailable(name: selected.lastPathComponent) : .document
        } else {
            content = .noSelection
        }
        hostingView.rootView = AnyView(PaperbranchLibraryWindowView(
            library: state.library,
            content: content,
            sidebarState: state.sidebarState,
            selectedDocumentURL: state.selectedDocumentURL,
            documentStatus: documentStatus,
            isEdited: showsSelectedDocument && document.isDirty,
            isSidebarCollapsed: state.sidebarState.isCollapsed,
            wordCount: state.wordCount,
            outline: outline,
            readingProgress: state.readingProgress,
            webView: webView,
            selectDocument: selectDocument(at:),
            selectOutline: selectOutline(id:),
            setFolder: setFolder(_:expanded:),
            toggleSidebar: toggleSidebar,
            open: open,
            chooseLibrary: onChooseLibrary,
            reconnect: onReconnect
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
            window.toolbar = chromeToolbar
            window.toolbarStyle = .unified
            window.titlebarSeparatorStyle = .none
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
        window.toolbar = appKitToolbar
        window.toolbar?.isVisible = true
        window.titlebarSeparatorStyle = .automatic
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

/// What the reader shows below the top bar.
private enum PaperbranchReaderContent: Equatable {
    case choosingLibrary
    case libraryUnavailable(name: String)
    case noSelection
    case documentUnavailable(name: String)
    case document

    var isDocumentUnavailable: Bool {
        if case .documentUnavailable = self { return true }
        return false
    }
}

private struct PaperbranchLibraryWindowView: View {
    let library: LibraryBrowser?
    let content: PaperbranchReaderContent
    let sidebarState: LibrarySidebarState
    let selectedDocumentURL: URL?
    let documentStatus: PBDocumentStatus?
    let isEdited: Bool
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
    let chooseLibrary: () -> Void
    let reconnect: () -> Void

    var body: some View {
        GeometryReader { proxy in
            // The outline is a right panel in windows 1240 px and wider, and sits under the Library tree below that.
            let showsOutlinePanel = proxy.size.width >= PBSize.outlineMinWindow
            HStack(spacing: 0) {
                if !isSidebarCollapsed {
                    sidebar(showsOutline: !showsOutlinePanel)
                }
                reader(showsOutlinePanel: showsOutlinePanel)
            }
        }
        .background(PBColor.paper)
        // The window's content runs under its transparent title bar, so the top bar starts at the window's top edge.
        .ignoresSafeArea()
    }

    private func sidebar(showsOutline: Bool) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                PBWordmark()
                    .accessibilityIdentifier("paperbranch.library.wordmark")
                    .padding(.horizontal, PBSize.space2)
                    // The window buttons fill the top bar's row above the wordmark.
                    .padding(.top, PBSize.topbarHeight)
                    .padding(.bottom, PBSize.space2)
                // Choosing a Library shows the wordmark only; Library unavailable adds the label and one caption.
                if case let .libraryUnavailable(name) = content {
                    PBSectionLabel(text: "Library")
                    Text("\(name) is unavailable.")
                        .font(.system(size: PBSize.textCaption))
                        .foregroundStyle(PBColor.inkMuted)
                        .padding(.horizontal, PBSize.space2)
                }
                if let library {
                // Open now sits above the tree so a long Library cannot push it out of view.
                if let selectedDocumentURL {
                    PBSectionLabel(text: "Open now")
                    PBOpenNowCard(name: selectedDocumentURL.lastPathComponent, wordCount: wordCount, isEdited: isEdited)
                        .accessibilityIdentifier("paperbranch.library.open-now")
                }
                PBSectionLabel(text: "Library")
                ForEach(library.root.children) { node in
                    PaperbranchLibraryNodeRows(node: node, sidebarState: sidebarState, selectedDocumentURL: selectedDocumentURL, depth: 0, selectDocument: selectDocument, setFolder: setFolder)
                }
                if showsOutline && !outline.isEmpty {
                    PBOutlineRows(entries: outline, select: selectOutline)
                        .padding(.top, PBSize.space3)
                }
                }
            }
            .padding(.horizontal, PBSize.space2)
            .padding(.bottom, PBSize.space4)
        }
        .frame(width: PBSize.sidebarWidth)
        .frame(maxHeight: .infinity)
        .background(PBColor.sidebar)
        .overlay(alignment: .trailing) { Rectangle().fill(PBColor.rule).frame(width: 1) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Paperbranch Library")
        .accessibilityIdentifier("paperbranch.library.sidebar")
    }

    private func reader(showsOutlinePanel: Bool) -> some View {
        VStack(spacing: 0) {
            PBTopBar(
                title: content == .document || content.isDocumentUnavailable ? selectedDocumentURL?.lastPathComponent : nil,
                status: content == .document ? documentStatus : nil,
                // With the sidebar hidden, the toggle sits beside the window buttons.
                leadingInset: isSidebarCollapsed ? 64 : 0,
                sidebarToggle: (isSidebarCollapsed ? "Show Library sidebar" : "Collapse Library sidebar", toggleSidebar),
                // The state views for a missing Library carry their own actions, as in the guideline's mockups.
                open: library == nil ? nil : open
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel(selectedDocumentURL.map { ["Reader top bar for \($0.lastPathComponent)", documentStatus?.text].compactMap { $0 }.joined(separator: ", ") } ?? "Reader top bar")
            .accessibilityIdentifier("paperbranch.reader.topbar")

            switch content {
            case .choosingLibrary:
                PBStateView(
                    symbol: "folder",
                    title: "Choose a Library",
                    message: "Pick a folder of Markdown documents. Paperbranch shows its folders in the sidebar and opens it again next time.",
                    secondary: .init(title: "Open a Document…", perform: open),
                    primary: .init(title: "Choose Library…", perform: chooseLibrary)
                )
            case let .libraryUnavailable(name):
                PBStateView(
                    symbol: "folder.badge.questionmark",
                    title: "Library unavailable",
                    message: "Paperbranch can't reach \(name). The folder may have moved, or its drive may be disconnected.",
                    secondary: .init(title: "Choose Another Library…", perform: chooseLibrary),
                    primary: .init(title: "Reconnect", perform: reconnect)
                )
            case let .documentUnavailable(name):
                // No buttons: the Library tree is the way back.
                PBStateView(
                    symbol: "doc.text",
                    title: "Document unavailable",
                    message: "\(name) may have been moved or deleted. Choose another document from the Library."
                )
            case .noSelection:
                Text("Choose a document from the Library")
                    .font(.system(size: PBSize.textUI))
                    .foregroundStyle(PBColor.inkMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Empty reader")
                    .accessibilityIdentifier("paperbranch.reader.empty")
            case .document:
                PBReadingProgress(progress: readingProgress)
                HStack(spacing: 0) {
                    // The Document view spans the reader; its own CSS centers the 680 px column and ends the article with its footer.
                    PaperbranchWebView(webView: webView)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityIdentifier("paperbranch.document.view")
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Document canvas")
                        .accessibilityIdentifier("paperbranch.reader.document-canvas")
                    if showsOutlinePanel && !outline.isEmpty {
                        PBOutlinePanel(entries: outline, select: selectOutline)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PBColor.paper)
    }
}

/// A Library node and, for an expanded folder, its children, as PBLibraryRow rows.
private struct PaperbranchLibraryNodeRows: View {
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
            PBLibraryRow(name: node.name, kind: .folder(expanded: expanded), depth: depth, isSelected: false,
                         accessibilityText: "Folder: \(node.name), \(expanded ? "expanded" : "collapsed")") { setFolder(node, !expanded) }
                .accessibilityIdentifier("paperbranch.library.folder")
            if expanded {
                ForEach(node.children) { child in
                    PaperbranchLibraryNodeRows(node: child, sidebarState: sidebarState, selectedDocumentURL: selectedDocumentURL, depth: depth + 1, selectDocument: selectDocument, setFolder: setFolder)
                }
            }
        case .document:
            let selected = node.url == selectedDocumentURL
            PBLibraryRow(name: node.name, kind: .document, depth: depth, isSelected: selected,
                         accessibilityText: selected ? "Selected Markdown document: \(node.name)" : "Markdown document: \(node.name)") { selectDocument(node.url) }
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
