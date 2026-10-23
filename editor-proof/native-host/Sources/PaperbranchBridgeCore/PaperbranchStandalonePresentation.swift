import AppKit
import SwiftUI
import WebKit

/// The facts a Standalone window shows: its document, status, and navigation.
public struct PaperbranchStandaloneState {
    public let documentURL: URL?
    public let isDirty: Bool
    public let conflict: DocumentConflict?
    public let availability: DocumentAvailability
    public let outline: [DocumentOutlineEntry]
    public let readingProgress: Double

    public init(documentURL: URL?, isDirty: Bool, conflict: DocumentConflict?, availability: DocumentAvailability, outline: [DocumentOutlineEntry] = [], readingProgress: Double = 0) {
        self.documentURL = documentURL
        self.isDirty = isDirty
        self.conflict = conflict
        self.availability = availability
        self.outline = outline
        self.readingProgress = max(0, min(1, readingProgress))
    }
}

/// A Standalone window's chrome from the design skill's "Standalone window" screen (Ticket 45): the top bar holds
/// the window buttons and the document name with its status, then the progress line and the Document view, with the
/// outline panel at 1240 px and wider. No Library parts: no sidebar, toggle, Open button, or Open now card.
@MainActor
public final class PaperbranchStandalonePresentation {
    public let hostingView = NSHostingView(rootView: AnyView(EmptyView()))
    private let webView: WKWebView
    private let onSelectOutline: (String) -> Void
    /// Empty and unified, so AppKit centers the window buttons in the 52 px top bar's row.
    private let chromeToolbar: NSToolbar = {
        let toolbar = NSToolbar(identifier: "PaperbranchStandaloneChromeToolbar-\(UUID().uuidString)")
        toolbar.allowsUserCustomization = false
        return toolbar
    }()

    public init(webView: WKWebView, onSelectOutline: @escaping (String) -> Void = { _ in }) {
        self.webView = webView
        self.onSelectOutline = onSelectOutline
        hostingView.setAccessibilityIdentifier("paperbranch.standalone.window")
    }

    /// Puts the chrome in the window: content under a transparent title bar, with the title kept for the Window menu.
    public func install(in window: NSWindow) {
        let size = window.contentView?.frame.size ?? window.frame.size
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbar = chromeToolbar
        window.toolbarStyle = .unified
        window.titlebarSeparatorStyle = .none
        window.contentView = hostingView
        window.setContentSize(size)
    }

    public func render(_ state: PaperbranchStandaloneState) {
        let status: PBDocumentStatus? = state.conflict != nil ? .changedOnDisk : state.isDirty ? .edited : nil
        hostingView.rootView = AnyView(PaperbranchStandaloneWindowView(
            name: state.documentURL?.lastPathComponent,
            status: status,
            isAvailable: state.availability == .available,
            outline: state.outline,
            readingProgress: state.readingProgress,
            webView: webView,
            selectOutline: onSelectOutline
        ))
    }
}

private struct PaperbranchStandaloneWindowView: View {
    let name: String?
    let status: PBDocumentStatus?
    let isAvailable: Bool
    let outline: [DocumentOutlineEntry]
    let readingProgress: Double
    let webView: WKWebView
    let selectOutline: (String) -> Void

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                // The window buttons sit at the top bar's leading edge, so the bar starts clear of them.
                PBTopBar(title: name, status: status, leadingInset: 64)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(name.map { ["Reader top bar for \($0)", status?.text].compactMap { $0 }.joined(separator: ", ") } ?? "Reader top bar")
                    .accessibilityIdentifier("paperbranch.reader.topbar")
                if isAvailable {
                    // The reading progress line is drawn by the Document view itself (Ticket 49).
                    HStack(spacing: 0) {
                        PaperbranchWebView(webView: webView)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .accessibilityIdentifier("paperbranch.document.view")
                            .accessibilityElement(children: .contain)
                            .accessibilityLabel("Document canvas")
                            .accessibilityIdentifier("paperbranch.reader.document-canvas")
                        if proxy.size.width >= PBSize.outlineMinWindow && !outline.isEmpty {
                            PBOutlinePanel(entries: outline, select: selectOutline)
                        }
                    }
                } else {
                    // A Standalone window has no Library tree to return to, so the sentence stops at the cause.
                    PBStateView(symbol: "doc.text", title: "Document unavailable", message: "\(name ?? "This document") may have been moved or deleted.")
                }
            }
        }
        .background(PBColor.paper)
        .ignoresSafeArea()
    }
}
