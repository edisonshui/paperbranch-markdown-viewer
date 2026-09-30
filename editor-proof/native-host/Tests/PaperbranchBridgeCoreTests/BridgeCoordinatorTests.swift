import AppKit
import WebKit
import XCTest

@testable import PaperbranchBridgeCore
@testable import PaperbranchEditorProofHost

/// Drives a real (off-screen, never shown in a window) `WKWebView` loading
/// the same editor-proof harness Playwright tests, through
/// `BridgeCoordinator`, exactly the way the native host does. This is the
/// programmatic verification for the parts of Ticket 01's remaining
/// checkboxes that do not require a human to physically press a key in a
/// focused window:
///
/// - Command-S "reaches the native host and requests the current
///   serialized Markdown without writing a file": verified here as
///   `BridgeCoordinator.requestSave()` returning the live serialized
///   Markdown with no disk write anywhere in this code path. What is NOT
///   verified here is the literal OS key-equivalent delivery for a
///   physical Cmd-S keystroke into a focused, on-screen window -- that
///   requires a visible window with real first-responder focus, which is
///   either a human at the keyboard or Accessibility-permissioned UI
///   scripting. See native-host/README.md.
/// - Simulated external-content messages: fully covered here, since they
///   are ordinary async calls into the page, not OS input events.
/// - Bridge surface restriction: verified here (only `"paperbranch"` is
///   registered, and the JS surface exposes only fixed content operations).
///
/// Run with `native-host/test.sh`, which starts the same Vite dev server
/// the Playwright suite uses before running `swift test`.
final class BridgeCoordinatorTests: XCTestCase {
    @MainActor
    func testPresentationActivatesOnlyForCleanExpandedLibraryDocumentAndOtherwiseRestoresAppKit() throws {
        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-guarded-presentation")
        defer { try? FileManager.default.removeItem(at: libraryURL) }
        let documentURL = libraryURL.appendingPathComponent("Selected.md")
        try "# Selected\n".write(to: documentURL, atomically: true, encoding: .utf8)
        let folderURL = libraryURL.appendingPathComponent("Folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try "# Nested\n".write(to: folderURL.appendingPathComponent("Nested.md"), atomically: true, encoding: .utf8)
        let library = try LibraryBrowser.choose(libraryURL)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 720), styleMask: [.titled], backing: .buffered, defer: false)
        let appKitContent = NSView()
        window.contentView = appKitContent
        let webView = WKWebView()
        let presentation = PaperbranchWindowPresentation(window: window, webView: webView)

        XCTAssertTrue(presentation.render(.init(
            library: library,
            sidebarState: LibrarySidebarState(),
            selectedDocumentURL: documentURL,
            document: .init(url: documentURL, kind: .library, availability: .available, isDirty: false, conflict: nil)
        )))
        XCTAssertTrue(presentation.window === window)
        window.contentView?.layoutSubtreeIfNeeded()
        XCTAssertTrue(windowContainsView(window, target: webView))

        var collapsedSidebar = LibrarySidebarState()
        collapsedSidebar.toggleCollapsed()
        var collapsedFolder = LibrarySidebarState()
        collapsedFolder.setExpanded(try XCTUnwrap(library.root.children.first(where: { $0.kind == .folder })), expanded: false)
        let excludedStates: [PaperbranchWindowPresentationState] = [
            .init(library: library, sidebarState: LibrarySidebarState(), selectedDocumentURL: documentURL, document: .init(url: documentURL, kind: .library, availability: .available, isDirty: true, conflict: nil)),
            .init(library: library, sidebarState: LibrarySidebarState(), selectedDocumentURL: documentURL, document: .init(url: documentURL, kind: .library, availability: .available, isDirty: false, conflict: .externalChange(documentURL))),
            .init(library: nil, sidebarState: LibrarySidebarState(), selectedDocumentURL: documentURL, document: .init(url: documentURL, kind: .library, availability: .available, isDirty: false, conflict: nil)),
            .init(library: library, sidebarState: collapsedSidebar, selectedDocumentURL: documentURL, document: .init(url: documentURL, kind: .library, availability: .available, isDirty: false, conflict: nil)),
            .init(library: library, sidebarState: collapsedFolder, selectedDocumentURL: documentURL, document: .init(url: documentURL, kind: .library, availability: .available, isDirty: false, conflict: nil)),
            .init(library: library, sidebarState: LibrarySidebarState(), selectedDocumentURL: nil, document: nil),
            .init(library: library, sidebarState: LibrarySidebarState(), selectedDocumentURL: documentURL, document: .init(url: documentURL, kind: .library, availability: .unavailable, isDirty: false, conflict: nil)),
            .init(library: library, sidebarState: LibrarySidebarState(), selectedDocumentURL: documentURL, document: .init(url: documentURL, kind: .standalone, availability: .available, isDirty: false, conflict: nil)),
            .init(library: library, sidebarState: LibrarySidebarState(), selectedDocumentURL: documentURL, document: .init(url: nil, kind: .library, availability: .available, isDirty: false, conflict: nil)),
        ]

        for state in excludedStates {
            XCTAssertFalse(presentation.render(state))
            XCTAssertTrue(window.contentView === appKitContent)
        }
    }

    @MainActor
    func testPresentationSwapsKeepTheLibraryWindowFrame() throws {
        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-window-presentation-frame")
        defer { try? FileManager.default.removeItem(at: libraryURL) }
        let documentURL = libraryURL.appendingPathComponent("Reading.md")
        try "# Reading\n".write(to: documentURL, atomically: true, encoding: .utf8)

        // Mirrors the app: the AppKit content is a view controller whose detached view keeps its old size.
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 220), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        let appKitContent = NSViewController()
        appKitContent.view = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 220))
        window.contentViewController = appKitContent
        let presentation = PaperbranchWindowPresentation(window: window, webView: WKWebView())
        let state = PaperbranchWindowPresentationState(
            library: try LibraryBrowser.choose(libraryURL),
            sidebarState: LibrarySidebarState(),
            selectedDocumentURL: documentURL,
            document: .init(url: documentURL, kind: .library, availability: .available, isDirty: false, conflict: nil)
        )
        XCTAssertTrue(presentation.render(state))
        window.setFrame(NSRect(x: 0, y: 0, width: 1440, height: 900), display: false)
        let chosenFrame = window.frame

        presentation.restoreAppKitPresentation()
        XCTAssertTrue(window.contentViewController === appKitContent)
        XCTAssertEqual(window.frame, chosenFrame)
        XCTAssertTrue(presentation.render(state))
        XCTAssertEqual(window.frame, chosenFrame)
        presentation.restoreAppKitPresentation()
        XCTAssertEqual(window.frame, chosenFrame)
    }

    @MainActor
    func testUnchangedLibraryRefreshDoesNotSwapPresentations() throws {
        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-window-presentation-refresh")
        defer { try? FileManager.default.removeItem(at: libraryURL) }
        let documentURL = libraryURL.appendingPathComponent("Reading.md")
        try "# Reading\n".write(to: documentURL, atomically: true, encoding: .utf8)
        let folderURL = libraryURL.appendingPathComponent("Folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try "# Nested\n".write(to: folderURL.appendingPathComponent("Nested.md"), atomically: true, encoding: .utf8)
        let library = try LibraryBrowser.choose(libraryURL)

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900), styleMask: [.titled], backing: .buffered, defer: false)
        let appKitContent = NSView()
        window.contentView = appKitContent
        let presentation = PaperbranchWindowPresentation(window: window, webView: WKWebView())
        let sidebar = LibrarySidebarViewController()
        _ = sidebar.view
        // AppDelegate routes sidebar selections through routeFinderOpen, which restores AppKit first.
        var routedSelections: [URL] = []
        sidebar.selectDocument = { url in
            routedSelections.append(url)
            presentation.restoreAppKitPresentation()
        }
        let state = PaperbranchWindowPresentationState(
            library: library,
            sidebarState: LibrarySidebarState(),
            selectedDocumentURL: documentURL,
            document: .init(url: documentURL, kind: .library, availability: .available, isDirty: false, conflict: nil)
        )
        sidebar.show(library, sidebarState: state.sidebarState, selectedDocumentURL: documentURL)
        XCTAssertTrue(presentation.render(state))
        let swiftUIContent = try XCTUnwrap(window.contentView)

        // The 1 s refresh: refreshLibraryIfNeeded() then showLibrary().
        try library.refresh()
        sidebar.show(library, sidebarState: state.sidebarState, selectedDocumentURL: documentURL)
        XCTAssertTrue(window.contentView === swiftUIContent)
        XCTAssertTrue(presentation.render(state))

        XCTAssertEqual(routedSelections, [])
        XCTAssertTrue(window.contentView === swiftUIContent)
    }

    @MainActor
    func testExpandedLibraryPresentationShowsSelectedDocumentAndInjectedWebView() throws {
        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-window-presentation")
        defer { try? FileManager.default.removeItem(at: libraryURL) }
        let documentURL = libraryURL.appendingPathComponent("Selected.md")
        try "# Selected\n".write(to: documentURL, atomically: true, encoding: .utf8)

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 720), styleMask: [.titled], backing: .buffered, defer: false)
        let webView = WKWebView()
        let presentation = PaperbranchWindowPresentation(window: window, webView: webView)
        presentation.render(.init(
            library: try LibraryBrowser.choose(libraryURL),
            sidebarState: LibrarySidebarState(),
            selectedDocumentURL: documentURL,
            document: .init(url: documentURL, kind: .library, availability: .available, isDirty: false, conflict: nil)
        ))

        window.contentView?.layoutSubtreeIfNeeded()

        let root = try XCTUnwrap(window.contentView)
        XCTAssertEqual(root.accessibilityLabel(), "Paperbranch Library")
        let selectedDocument = try XCTUnwrap(accessibilityElement("paperbranch.library.selected-document", in: renderedAccessibilityElements(in: root)))
        XCTAssertEqual(selectedDocument.value(forKey: "accessibilityLabel") as? String, "Selected Markdown document: Selected.md")
        XCTAssertTrue(windowContainsView(window, target: webView))
    }

    @MainActor
    func testExpandedLibraryPresentationShowsVariantBReaderChromeAroundInjectedDocumentView() throws {
        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-window-presentation-reader-chrome")
        defer { try? FileManager.default.removeItem(at: libraryURL) }
        let documentURL = libraryURL.appendingPathComponent("Reading.md")
        try "# Reading\n\nA document for focused reading.\n".write(to: documentURL, atomically: true, encoding: .utf8)

        // Wide enough that the reader column is wider than Variant B's constrained canvas.
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900), styleMask: [.titled], backing: .buffered, defer: false)
        let webView = WKWebView()
        let appKitDocumentView = NSView()
        webView.translatesAutoresizingMaskIntoConstraints = false
        appKitDocumentView.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: appKitDocumentView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: appKitDocumentView.trailingAnchor),
            webView.topAnchor.constraint(equalTo: appKitDocumentView.topAnchor),
            webView.bottomAnchor.constraint(equalTo: appKitDocumentView.bottomAnchor),
        ])
        let presentation = PaperbranchWindowPresentation(window: window, webView: webView)
        XCTAssertTrue(presentation.render(.init(
            library: try LibraryBrowser.choose(libraryURL),
            sidebarState: LibrarySidebarState(),
            selectedDocumentURL: documentURL,
            document: .init(url: documentURL, kind: .library, availability: .available, isDirty: false, conflict: nil)
        )))

        let root = try XCTUnwrap(window.contentView)
        root.layoutSubtreeIfNeeded()
        let elements = renderedAccessibilityElements(in: root)
        XCTAssertNil(root.accessibilityValue())

        let sidebar = try XCTUnwrap(accessibilityElement("paperbranch.library.sidebar", in: elements))
        let topBar = try XCTUnwrap(accessibilityElement("paperbranch.reader.topbar", in: elements))
        let canvas = try XCTUnwrap(accessibilityElement("paperbranch.reader.document-canvas", in: elements))
        let footer = try XCTUnwrap(accessibilityElement("paperbranch.reader.footer", in: elements))
        XCTAssertNotEqual(root.accessibilityIdentifier(), "paperbranch.library.sidebar")
        XCTAssertTrue(accessibilityDescendants(of: topBar).contains { $0.value(forKey: "accessibilityValue") as? String == "Reading.md" })
        XCTAssertTrue(accessibilityDescendants(of: canvas).contains { $0 === webView })

        // Accessibility frames use bottom-left screen coordinates.
        let rootFrame = accessibilityFrame(of: root)
        let sidebarFrame = accessibilityFrame(of: sidebar)
        let readerColumn = NSRect(x: sidebarFrame.maxX, y: rootFrame.minY, width: rootFrame.maxX - sidebarFrame.maxX, height: rootFrame.height)
        let canvasFrame = accessibilityFrame(of: canvas)
        let webViewFrame = accessibilityFrame(of: webView)
        XCTAssertFalse(webViewFrame.isEmpty)
        XCTAssertTrue(canvasFrame.contains(webViewFrame))
        XCTAssertLessThan(canvasFrame.width, readerColumn.width)
        XCTAssertEqual(canvasFrame.midX, readerColumn.midX, accuracy: 1)
        XCTAssertGreaterThanOrEqual(accessibilityFrame(of: topBar).minY, canvasFrame.maxY)
        XCTAssertLessThanOrEqual(accessibilityFrame(of: footer).maxY, canvasFrame.minY)

        XCTAssertTrue(windowContainsView(window, target: webView))
        XCTAssertFalse(appKitDocumentView.constraints.contains { constraint in
            constraint.firstItem as? WKWebView === webView || constraint.secondItem as? WKWebView === webView
        })
    }

    @MainActor
    func testReaderSidebarToggleRestoresAppKitThenDelegatesToExistingSidebarWorkflow() throws {
        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-window-presentation-sidebar-toggle")
        defer { try? FileManager.default.removeItem(at: libraryURL) }
        let documentURL = libraryURL.appendingPathComponent("Reading.md")
        try "# Reading\n".write(to: documentURL, atomically: true, encoding: .utf8)

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 720), styleMask: [.titled], backing: .buffered, defer: false)
        let appKitContent = NSView()
        window.contentView = appKitContent
        var sidebarToggleCount = 0
        let presentation = PaperbranchWindowPresentation(
            window: window,
            webView: WKWebView(),
            onToggleSidebar: { sidebarToggleCount += 1 }
        )
        XCTAssertTrue(presentation.render(.init(
            library: try LibraryBrowser.choose(libraryURL),
            sidebarState: LibrarySidebarState(),
            selectedDocumentURL: documentURL,
            document: .init(url: documentURL, kind: .library, availability: .available, isDirty: false, conflict: nil)
        )))

        presentation.toggleSidebar()

        XCTAssertTrue(window.contentView === appKitContent)
        XCTAssertEqual(sidebarToggleCount, 1)
    }

    @MainActor
    func testReturningToReaderAfterAppKitRestoreShowsInjectedWebViewAgain() throws {
        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-window-presentation-return")
        defer { try? FileManager.default.removeItem(at: libraryURL) }
        let documentURL = libraryURL.appendingPathComponent("Reading.md")
        try "# Reading\n".write(to: documentURL, atomically: true, encoding: .utf8)

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900), styleMask: [.titled], backing: .buffered, defer: false)
        let appKitContent = NSView()
        window.contentView = appKitContent
        let webView = WKWebView()
        // Mirrors DocumentPresentationViewController.restoreDocumentView().
        let presentation = PaperbranchWindowPresentation(window: window, webView: webView, restoreAppKitContent: {
            webView.removeFromSuperview()
            appKitContent.addSubview(webView)
        })
        let state = PaperbranchWindowPresentationState(
            library: try LibraryBrowser.choose(libraryURL),
            sidebarState: LibrarySidebarState(),
            selectedDocumentURL: documentURL,
            document: .init(url: documentURL, kind: .library, availability: .available, isDirty: false, conflict: nil)
        )
        XCTAssertTrue(presentation.render(state))
        window.contentView?.layoutSubtreeIfNeeded()
        XCTAssertTrue(windowContainsView(window, target: webView))

        presentation.restoreAppKitPresentation()
        XCTAssertTrue(webView.superview === appKitContent)

        XCTAssertTrue(presentation.render(state))
        window.contentView?.layoutSubtreeIfNeeded()
        XCTAssertTrue(windowContainsView(window, target: webView))
        XCTAssertFalse(webView.superview === appKitContent)
    }

    @MainActor
    func testLibraryWindowIsDarkWhileStandaloneWindowsFollowTheSystem() throws {
        let libraryWindow = AppDelegate().makeLibraryWindow()
        defer { libraryWindow.setFrameAutosaveName("") }
        let standalone = StandaloneDocumentWindow(delegate: AppDelegate())

        XCTAssertEqual(libraryWindow.appearance?.name, .darkAqua)
        XCTAssertNil(standalone.window.appearance)
    }

    @MainActor
    func testLibraryWindowOpensAtDefaultContentSizeWithoutSavedFrame() throws {
        UserDefaults.standard.removeObject(forKey: libraryWindowFrameKey)
        defer { UserDefaults.standard.removeObject(forKey: libraryWindowFrameKey) }

        let window = AppDelegate().makeLibraryWindow()
        defer { window.setFrameAutosaveName("") }

        XCTAssertEqual(window.contentView?.frame.size, NSSize(width: 960, height: 720))
    }

    @MainActor
    func testLibraryWindowSavesItsFrameAndRestoresItAtNextLaunch() throws {
        UserDefaults.standard.removeObject(forKey: libraryWindowFrameKey)
        defer { UserDefaults.standard.removeObject(forKey: libraryWindowFrameKey) }
        let chosenFrame = NSRect(x: 120, y: 90, width: 1100, height: 700)

        let firstLaunch = AppDelegate().makeLibraryWindow()
        firstLaunch.setFrame(chosenFrame, display: false)
        firstLaunch.setFrameAutosaveName("")
        XCTAssertNotNil(UserDefaults.standard.string(forKey: libraryWindowFrameKey))

        let nextLaunch = AppDelegate().makeLibraryWindow()
        defer { nextLaunch.setFrameAutosaveName("") }
        XCTAssertEqual(nextLaunch.frame, chosenFrame)
    }

    @MainActor
    func testLibraryToolbarSidebarItemRoutesThroughLibrarySidebarToggle() throws {
        let delegate = AppDelegate()
        let toolbar = NSToolbar(identifier: "PaperbranchToolbarTest-\(UUID().uuidString)")
        toolbar.delegate = delegate
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 720), styleMask: [.titled], backing: .buffered, defer: false)
        window.toolbar = toolbar

        // AppKit's built-in sidebar item toggles the split view directly, bypassing the Library workflow.
        XCTAssertFalse(toolbar.items.contains { $0.itemIdentifier == .toggleSidebar })
        let sidebarItem = try XCTUnwrap(toolbar.items.first { $0.label == "Library" })
        XCTAssertTrue(sidebarItem.target === delegate)
        XCTAssertEqual(sidebarItem.action, NSSelectorFromString("toggleLibrarySidebar"))
    }

    @MainActor
    func testExpandedLibraryPresentationShowsNavigationStateAndRoutesOutlineSelection() throws {
        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-window-presentation-navigation")
        defer { try? FileManager.default.removeItem(at: libraryURL) }
        let documentURL = libraryURL.appendingPathComponent("Selected.md")
        try "# Selected\n\n## Details\n".write(to: documentURL, atomically: true, encoding: .utf8)

        var selectedOutlineID: String?
        let window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        let presentation = PaperbranchWindowPresentation(
            window: window,
            webView: WKWebView(),
            onSelectOutline: { selectedOutlineID = $0 }
        )
        presentation.render(.init(
            library: try LibraryBrowser.choose(libraryURL),
            sidebarState: LibrarySidebarState(),
            selectedDocumentURL: documentURL,
            document: .init(url: documentURL, kind: .library, availability: .available, isDirty: false, conflict: nil),
            outline: [
                .init(id: "heading-0", text: "Selected", level: 1),
                .init(id: "heading-1", text: "Details", level: 2),
            ],
            readingProgress: 0.42
        ))

        let elements = renderedAccessibilityElements(in: try XCTUnwrap(window.contentView))
        XCTAssertEqual(accessibilityElement("paperbranch.library.outline.heading-0", in: elements)?.value(forKey: "accessibilityLabel") as? String, "Selected")
        XCTAssertEqual(accessibilityElement("paperbranch.library.outline.heading-1", in: elements)?.value(forKey: "accessibilityLabel") as? String, "Details")
        XCTAssertEqual(try XCTUnwrap(accessibilityElement("paperbranch.reader.progress", in: elements)?.value(forKey: "accessibilityValue") as? Double), 0.42, accuracy: 0.001)
        presentation.selectOutline(id: "heading-1")
        XCTAssertEqual(selectedOutlineID, "heading-1")
    }

    @MainActor
    func testExpandedLibraryPresentationIgnoresSelectionOutsideItsLibrary() throws {
        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-window-presentation-library")
        let outsideURL = try makeTemporaryDirectory(named: "paperbranch-window-presentation-outside")
        defer {
            try? FileManager.default.removeItem(at: libraryURL)
            try? FileManager.default.removeItem(at: outsideURL)
        }
        try "# Available\n".write(to: libraryURL.appendingPathComponent("Available.md"), atomically: true, encoding: .utf8)
        let outsideDocumentURL = outsideURL.appendingPathComponent("Outside.md")
        try "# Outside\n".write(to: outsideDocumentURL, atomically: true, encoding: .utf8)

        let window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        let presentation = PaperbranchWindowPresentation(window: window, webView: WKWebView())
        XCTAssertFalse(presentation.render(.init(
            library: try LibraryBrowser.choose(libraryURL),
            sidebarState: LibrarySidebarState(),
            selectedDocumentURL: outsideDocumentURL,
            document: .init(url: outsideDocumentURL, kind: .library, availability: .available, isDirty: false, conflict: nil)
        )))
    }

    @MainActor
    func testRenderedLibraryDocumentSelectionInvokesInjectedAction() throws {
        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-window-presentation-selection")
        defer { try? FileManager.default.removeItem(at: libraryURL) }
        let documentURL = libraryURL.appendingPathComponent("Selected.md")
        try "# Selected\n".write(to: documentURL, atomically: true, encoding: .utf8)

        var selectedDocumentURL: URL?
        let window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        let presentation = PaperbranchWindowPresentation(window: window, webView: WKWebView()) {
            selectedDocumentURL = $0
        }
        presentation.render(.init(
            library: try LibraryBrowser.choose(libraryURL),
            sidebarState: LibrarySidebarState(),
            selectedDocumentURL: documentURL,
            document: .init(url: documentURL, kind: .library, availability: .available, isDirty: false, conflict: nil)
        ))
        presentation.selectDocument(at: documentURL)

        XCTAssertEqual(selectedDocumentURL, documentURL.standardizedFileURL)
    }

    @MainActor
    func testLibraryDocumentWorkflowReceivesNavigationStateAndRoutesOutlineSelection() async throws {
        let directory = try makeTemporaryDirectory(named: "paperbranch-document-navigation")
        defer { try? FileManager.default.removeItem(at: directory) }
        let firstURL = directory.appendingPathComponent("first.md")
        let secondURL = directory.appendingPathComponent("second.md")
        try "# First\n\n## Details\n".write(to: firstURL, atomically: true, encoding: .utf8)
        try "No headings here.\n\n".write(to: secondURL, atomically: true, encoding: .utf8)

        let coordinator = makeCoordinator()
        try await waitForHarnessReady(coordinator)
        let session = DocumentSession(coordinator: coordinator)
        var outline: [DocumentOutlineEntry] = []
        var progress = -1.0
        session.navigationStateDidChange = { receivedOutline, receivedProgress in
            outline = receivedOutline
            progress = receivedProgress
        }
        try await session.open(firstURL)

        XCTAssertEqual(outline.map(\.text), ["First", "Details"])
        let selected = try await coordinator.selectOutline(id: "heading-1")
        XCTAssertTrue(selected)

        try await session.open(secondURL)
        XCTAssertEqual(outline, [])
        XCTAssertEqual(progress, 0)
    }
    func testApplicationBundleRegistersMarkdownEditorDocumentTypes() throws {
        let plistURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Info.plist")
        let data = try Data(contentsOf: plistURL)
        let plist = try XCTUnwrap(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        let documentTypes = try XCTUnwrap(plist["CFBundleDocumentTypes"] as? [[String: Any]])
        let markdownExtensions = Set(documentTypes.flatMap { $0["CFBundleTypeExtensions"] as? [String] ?? [] })

        XCTAssertEqual(markdownExtensions, ["md", "markdown"])
        XCTAssertEqual(documentTypes.first?["CFBundleTypeRole"] as? String, "Editor")
    }

    func testChoosingNestedLibraryBuildsVisibleMarkdownHierarchy() throws {
        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-library")
        defer { try? FileManager.default.removeItem(at: libraryURL) }

        try "# Root\n".write(to: libraryURL.appendingPathComponent("Readme.MD"), atomically: true, encoding: .utf8)
        let essays = libraryURL.appendingPathComponent("Essays", isDirectory: true)
        try FileManager.default.createDirectory(at: essays, withIntermediateDirectories: true)
        try "# Autumn\n".write(to: essays.appendingPathComponent("Autumn.markdown"), atomically: true, encoding: .utf8)
        try "not markdown".write(to: essays.appendingPathComponent("draft.txt"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: libraryURL.appendingPathComponent("Empty", isDirectory: true), withIntermediateDirectories: true)

        let library = try LibraryBrowser.choose(libraryURL)

        XCTAssertEqual(library.root.name, libraryURL.lastPathComponent)
        XCTAssertEqual(library.root.children.map(\.name), ["Essays", "Readme.MD"])
        XCTAssertEqual(library.root.children[0].children.map(\.name), ["Autumn.markdown"])
        XCTAssertFalse(library.root.flattened().contains { $0.name == "draft.txt" })
        XCTAssertFalse(library.root.flattened().contains { $0.name == "Empty" })
    }

    func testLibrarySidebarStateTracksFolderAndWholeSidebarCollapse() throws {
        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-sidebar")
        defer { try? FileManager.default.removeItem(at: libraryURL) }
        let folder = libraryURL.appendingPathComponent("Essays", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "# Essay\n".write(to: folder.appendingPathComponent("one.md"), atomically: true, encoding: .utf8)
        let library = try LibraryBrowser.choose(libraryURL)
        let essays = try XCTUnwrap(library.root.children.first)

        var sidebar = LibrarySidebarState()
        XCTAssertTrue(sidebar.isExpanded(essays))
        sidebar.toggleFolder(essays)
        XCTAssertFalse(sidebar.isExpanded(essays))
        XCTAssertFalse(sidebar.isCollapsed)
        sidebar.toggleCollapsed()
        XCTAssertTrue(sidebar.isCollapsed)
        sidebar.toggleCollapsed()
        XCTAssertFalse(sidebar.isCollapsed)
    }

    func testLibraryWorkflowRestoresAndRefreshesPreservingValidSidebarState() throws {
        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-restored-library")
        defer { try? FileManager.default.removeItem(at: libraryURL) }
        let essays = libraryURL.appendingPathComponent("Essays", isDirectory: true)
        try FileManager.default.createDirectory(at: essays, withIntermediateDirectories: true)
        let selected = essays.appendingPathComponent("selected.md")
        try "# Selected\n".write(to: selected, atomically: true, encoding: .utf8)

        let bookmarkStore = TestLibraryBookmarkStore()
        let firstLaunch = LibraryWorkflow(bookmarks: LibraryAccess(store: bookmarkStore, codec: TestLibraryBookmarkCodec()))
        try firstLaunch.chooseLibrary(at: libraryURL)
        firstLaunch.selectDocument(at: selected)
        firstLaunch.toggleFolder(try XCTUnwrap(firstLaunch.library?.root.children.first))

        let restoredLaunch = LibraryWorkflow(bookmarks: LibraryAccess(store: bookmarkStore, codec: TestLibraryBookmarkCodec()))
        XCTAssertEqual(try restoredLaunch.restoreLibrary(), .restored)
        XCTAssertEqual(restoredLaunch.selectedDocumentURL, selected.standardizedFileURL)
        XCTAssertFalse(restoredLaunch.sidebarState.isExpanded(try XCTUnwrap(restoredLaunch.library?.root.children.first)))

        try "# Added\n".write(to: essays.appendingPathComponent("added.markdown"), atomically: true, encoding: .utf8)
        try restoredLaunch.refreshLibrary()
        XCTAssertEqual(restoredLaunch.selectedDocumentURL, selected.standardizedFileURL)
        XCTAssertEqual(restoredLaunch.library?.root.children.first?.children.map(\.name), ["added.markdown", "selected.md"])
        XCTAssertFalse(restoredLaunch.sidebarState.isExpanded(try XCTUnwrap(restoredLaunch.library?.root.children.first)))
    }

    @MainActor
    func testStoppedApplicationRoutesFinderOpenedLibraryDocumentToLibraryWindow() async throws {
        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-finder-library")
        defer { try? FileManager.default.removeItem(at: libraryURL) }
        let documentURL = libraryURL.appendingPathComponent("From Finder.MD")
        try "# From Finder\n".write(to: documentURL, atomically: true, encoding: .utf8)

        let library = LibraryWorkflow(bookmarks: LibraryAccess(store: TestLibraryBookmarkStore(), codec: TestLibraryBookmarkCodec()))
        try library.chooseLibrary(at: libraryURL)
        let application = FinderOpenWorkflow(libraryWorkflow: library) {
            DocumentSession(coordinator: self.makeCoordinator())
        }

        try await application.applicationDidReceiveFinderOpen([documentURL])

        XCTAssertEqual(library.selectedDocumentURL, documentURL.standardizedFileURL)
        XCTAssertEqual(application.openWindows, [DocumentWindowState(documentURL: documentURL, kind: .library)])
        XCTAssertEqual(application.focusedDocumentURL, documentURL.standardizedFileURL)
    }

    @MainActor
    func testRunningApplicationOpensAndSavesSeparateFinderStandaloneDocuments() async throws {
        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-finder-standalone-library")
        let outsideURL = try makeTemporaryDirectory(named: "paperbranch-finder-outside")
        defer {
            try? FileManager.default.removeItem(at: libraryURL)
            try? FileManager.default.removeItem(at: outsideURL)
        }
        let firstURL = outsideURL.appendingPathComponent("first.md")
        let secondURL = outsideURL.appendingPathComponent("second.markdown")
        let firstOriginal = "# First Standalone\n"
        try firstOriginal.write(to: firstURL, atomically: true, encoding: .utf8)
        try "# Second Standalone\n".write(to: secondURL, atomically: true, encoding: .utf8)

        let library = LibraryWorkflow(bookmarks: LibraryAccess(store: TestLibraryBookmarkStore(), codec: TestLibraryBookmarkCodec()))
        try library.chooseLibrary(at: libraryURL)
        var coordinators: [BridgeCoordinator] = []
        let application = FinderOpenWorkflow(libraryWorkflow: library) {
            let coordinator = self.makeCoordinator()
            coordinators.append(coordinator)
            return DocumentSession(coordinator: coordinator)
        }

        try await application.applicationDidReceiveFinderOpen([firstURL])
        try await application.applicationDidReceiveFinderOpen([secondURL])
        let firstSession = try XCTUnwrap(application.documentSession(for: firstURL))
        let secondSession = try XCTUnwrap(application.documentSession(for: secondURL))
        XCTAssertFalse(firstSession === secondSession)
        XCTAssertEqual(library.selectedDocumentURL, nil)
        XCTAssertEqual(application.openWindows, [
            DocumentWindowState(documentURL: firstURL, kind: .standalone),
            DocumentWindowState(documentURL: secondURL, kind: .standalone),
        ])

        try await insertExclamationMark(in: coordinators[0])
        let becameDirty = try await pollIsDirty(coordinators[0], expecting: true)
        XCTAssertTrue(becameDirty)
        XCTAssertEqual(try String(contentsOf: firstURL, encoding: .utf8), firstOriginal)
        try await firstSession.save()
        XCTAssertTrue(try String(contentsOf: firstURL, encoding: .utf8).contains("First Standalone!"))
        XCTAssertFalse(firstSession.isDirty)

        try await application.applicationDidReceiveFinderOpen([firstURL])
        XCTAssertTrue(try XCTUnwrap(application.documentSession(for: firstURL)) === firstSession)
        XCTAssertEqual(application.openWindows.count, 2)
        XCTAssertEqual(application.focusedDocumentURL, firstURL.standardizedFileURL)

        application.documentWindowDidClose(for: firstURL)
        try await application.applicationDidReceiveFinderOpen([firstURL])
        XCTAssertFalse(try XCTUnwrap(application.documentSession(for: firstURL)) === firstSession)
        XCTAssertEqual(application.openWindows.count, 2)
    }

    func testSecurityScopedBookmarkPersistsAndRestoresLibrary() throws {
        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-security-scoped-library")
        defer { try? FileManager.default.removeItem(at: libraryURL) }
        let suiteName = "PaperbranchBridgeCoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsLibraryBookmarkStore(defaults: defaults)

        let choosingLaunch = LibraryWorkflow(bookmarks: LibraryAccess(store: store))
        try choosingLaunch.chooseLibrary(at: libraryURL)

        let restoredLaunch = LibraryWorkflow(bookmarks: LibraryAccess(store: store))
        XCTAssertEqual(try restoredLaunch.restoreLibrary(), .restored)
        XCTAssertEqual(restoredLaunch.library?.rootURL, libraryURL.standardizedFileURL)
    }

    @MainActor
    func testUnavailableLibraryDoesNotDiscardDirtyDocumentViewEdits() async throws {
        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-unavailable-library")
        defer { try? FileManager.default.removeItem(at: libraryURL) }
        let documentURL = libraryURL.appendingPathComponent("draft.md")
        try "# Draft\n".write(to: documentURL, atomically: true, encoding: .utf8)

        let store = TestLibraryBookmarkStore()
        let choosingLaunch = LibraryWorkflow(bookmarks: LibraryAccess(store: store, codec: TestLibraryBookmarkCodec()))
        try choosingLaunch.chooseLibrary(at: libraryURL)

        let coordinator = makeCoordinator()
        try await waitForHarnessReady(coordinator)
        let session = DocumentSession(coordinator: coordinator)
        try await session.open(documentURL)
        try await insertExclamationMark(in: coordinator)
        let becameDirty = try await pollIsDirty(coordinator, expecting: true)
        XCTAssertTrue(becameDirty)
        let dirtyContent = try await coordinator.requestSave()

        let unavailableLaunch = LibraryWorkflow(bookmarks: LibraryAccess(store: store, codec: UnavailableLibraryBookmarkCodec()))
        XCTAssertEqual(try unavailableLaunch.restoreLibrary(), .unavailable)
        XCTAssertNil(unavailableLaunch.library)
        XCTAssertTrue(session.isDirty)
        let remainingContent = try await coordinator.requestSave()
        XCTAssertEqual(remainingContent, dirtyContent)
    }

    @MainActor
    func testLibraryWorkflowSelectsNestedDocumentsWithoutWritingOnSwitch() async throws {
        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-library-workflow")
        defer { try? FileManager.default.removeItem(at: libraryURL) }
        let essays = libraryURL.appendingPathComponent("Essays", isDirectory: true)
        try FileManager.default.createDirectory(at: essays, withIntermediateDirectories: true)
        let firstURL = essays.appendingPathComponent("first.MD")
        let secondURL = libraryURL.appendingPathComponent("second.markdown")
        let firstOriginal = "# First Library Document\n"
        let secondOriginal = "# Second Library Document\n"
        try firstOriginal.write(to: firstURL, atomically: true, encoding: .utf8)
        try secondOriginal.write(to: secondURL, atomically: true, encoding: .utf8)

        let library = try LibraryBrowser.choose(libraryURL)
        XCTAssertEqual(library.root.children.map(\.name), ["Essays", "second.markdown"])
        XCTAssertEqual(library.root.children[0].children.map(\.url), [firstURL.standardizedFileURL])

        let coordinator = makeCoordinator()
        try await waitForHarnessReady(coordinator)
        let session = DocumentSession(coordinator: coordinator)
        try await session.open(firstURL)
        try await insertExclamationMark(in: coordinator)
        let becameDirty = try await pollIsDirty(coordinator, expecting: true)
        XCTAssertTrue(becameDirty)

        // Selecting another Library document replaces the formatted Document
        // view in memory. It cannot save the dirty first document or touch
        // the selected second document without an explicit Command-S path.
        try await session.open(secondURL)
        XCTAssertEqual(try String(contentsOf: firstURL, encoding: .utf8), firstOriginal)
        XCTAssertEqual(try String(contentsOf: secondURL, encoding: .utf8), secondOriginal)
        let selectedDocument = try await coordinator.requestSave()
        XCTAssertTrue(selectedDocument.contains("Second Library Document"))

        var sidebar = LibrarySidebarState()
        sidebar.toggleCollapsed()
        XCTAssertTrue(sidebar.isCollapsed)
        sidebar.toggleCollapsed()
        XCTAssertFalse(sidebar.isCollapsed)
    }

    @MainActor
    private func makeCoordinator() -> BridgeCoordinator {
        let coordinator = BridgeCoordinator()
        coordinator.load(url: HarnessLocation.url)
        return coordinator
    }

    @MainActor
    private func waitForHarnessReady(_ coordinator: BridgeCoordinator) async throws {
        // The harness installs window.editorContract synchronously as part
        // of its module script; poll until navigation + module evaluation
        // has completed.
        for _ in 0..<50 {
            let ready =
                (try? await coordinator.webView.evaluateJavaScript(
                    "typeof window.editorContract !== 'undefined'"
                )) as? Bool ?? false
            if ready { return }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTFail("editor-proof harness did not become ready at \(HarnessLocation.url)")
    }

    @MainActor
    private func loadFixture(_ coordinator: BridgeCoordinator, markdown: String) async throws {
        // loadMarkdown is async on the JS side, so this must await the
        // returned Promise via callAsyncJavaScript, not plain
        // evaluateJavaScript (see BridgeCoordinator.externalReplace).
        _ = try await coordinator.webView.callAsyncJavaScript(
            "return await window.editorContract.loadMarkdown(markdown);",
            arguments: ["markdown": markdown],
            contentWorld: .page
        )
    }

    @MainActor
    func testRequestSaveReturnsSerializedMarkdownWithoutTouchingDisk() async throws {
        let coordinator = makeCoordinator()
        try await waitForHarnessReady(coordinator)
        try await loadFixture(coordinator, markdown: "# Native host proof\n")

        let before = try snapshotProofDirectoryContents()
        let saved = try await coordinator.requestSave()
        let after = try snapshotProofDirectoryContents()

        XCTAssertTrue(saved.contains("Native host proof"))
        // The only observable effect of a save request is the returned
        // string -- nothing on disk changed.
        XCTAssertEqual(before, after)
    }

    @MainActor
    func testOpenEditAndSaveWritesOnlyAfterExplicitSave() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("paperbranch-workflow-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let documentURL = directory.appendingPathComponent("workflow.markdown")
        let original = "# Workflow proof\n\nThe original text.\n"
        try original.write(to: documentURL, atomically: true, encoding: .utf8)

        let coordinator = makeCoordinator()
        try await waitForHarnessReady(coordinator)
        let session = DocumentSession(coordinator: coordinator)
        try await session.open(documentURL)

        try await insertExclamationMark(in: coordinator)
        let editorIsDirty = try await pollIsDirty(coordinator, expecting: true)
        XCTAssertTrue(editorIsDirty)
        XCTAssertTrue(session.isDirty)

        // Editing happens only in WKWebView memory. The real file remains
        // byte-for-byte unchanged until the native Save command is invoked.
        XCTAssertEqual(try String(contentsOf: documentURL, encoding: .utf8), original)

        try await session.save()
        let saved = try String(contentsOf: documentURL, encoding: .utf8)
        XCTAssertNotEqual(saved, original)
        XCTAssertTrue(saved.contains("Workflow proof!"))
        XCTAssertFalse(session.isDirty)
    }

    @MainActor
    func testLocalImageRemainsVisibleThroughEditSaveAndReopen() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("paperbranch-local-image-workflow-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let documentURL = directory.appendingPathComponent("image document.md")
        try "# Local image\n\n![A local image](photo.png)\n".write(to: documentURL, atomically: true, encoding: .utf8)
        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL8KwAAAABJRU5ErkJggg==")!
        try png.write(to: directory.appendingPathComponent("photo.png"))

        let coordinator = makeCoordinator()
        try await waitForHarnessReady(coordinator)
        let session = DocumentSession(coordinator: coordinator)
        try await session.open(documentURL)
        let initiallyVisible = try await pollImageIsVisible(in: coordinator)
        XCTAssertTrue(initiallyVisible)

        try await insertExclamationMark(in: coordinator)
        _ = try await pollIsDirty(coordinator, expecting: true)
        try await session.save()
        XCTAssertTrue(try String(contentsOf: documentURL, encoding: .utf8).contains("photo.png"))

        try await session.open(documentURL)
        let visibleAfterReopen = try await pollImageIsVisible(in: coordinator)
        XCTAssertTrue(visibleAfterReopen)
    }

    @MainActor
    func testFailedSaveKeepsTheDocumentDirty() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("paperbranch-failed-save-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let documentURL = directory.appendingPathComponent("failure.md")
        try "# Failure proof\n".write(to: documentURL, atomically: true, encoding: .utf8)

        let coordinator = makeCoordinator()
        try await waitForHarnessReady(coordinator)
        let session = DocumentSession(coordinator: coordinator)
        try await session.open(documentURL)
        try await insertExclamationMark(in: coordinator)
        _ = try await pollIsDirty(coordinator, expecting: true)

        // Removing the containing directory after opening forces the real
        // coordinated write to fail. The editor must remain dirty.
        try FileManager.default.removeItem(at: directory)
        await XCTAssertThrowsErrorAsync { try await session.save() }
        XCTAssertTrue(session.isDirty)
        XCTAssertNotNil(session.lastError)
    }

    @MainActor
    func testExternalReplaceAppliesWhenClean() async throws {
        let coordinator = makeCoordinator()
        try await waitForHarnessReady(coordinator)
        try await loadFixture(coordinator, markdown: "# Original\n")

        let applied = try await coordinator.externalReplace(markdown: "# Replaced externally\n")
        XCTAssertTrue(applied)

        let current = try await coordinator.requestSave()
        XCTAssertTrue(current.contains("Replaced externally"))
    }

    @MainActor
    func testCleanDocumentReloadsAfterAnotherProgramModifiesItsRealFile() async throws {
        let directory = try makeTemporaryDirectory(named: "paperbranch-external-modification")
        defer { try? FileManager.default.removeItem(at: directory) }
        let documentURL = directory.appendingPathComponent("observed.md")
        try "# Original\n".write(to: documentURL, atomically: true, encoding: .utf8)

        let coordinator = makeCoordinator()
        try await waitForHarnessReady(coordinator)
        let session = DocumentSession(coordinator: coordinator)
        try await session.open(documentURL)

        try "# Changed outside Paperbranch\n".write(to: documentURL, atomically: false, encoding: .utf8)

        let reloaded = try await pollMarkdown(in: coordinator, containing: "Changed outside Paperbranch")
        XCTAssertTrue(reloaded)
        XCTAssertEqual(session.fileURL, documentURL.standardizedFileURL)
        XCTAssertFalse(session.isDirty)
    }

    @MainActor
    func testCleanDocumentReloadsAfterAtomicReplacement() async throws {
        let directory = try makeTemporaryDirectory(named: "paperbranch-atomic-replacement")
        defer { try? FileManager.default.removeItem(at: directory) }
        let documentURL = directory.appendingPathComponent("observed.md")
        try "# Original\n".write(to: documentURL, atomically: true, encoding: .utf8)

        let coordinator = makeCoordinator()
        try await waitForHarnessReady(coordinator)
        let session = DocumentSession(coordinator: coordinator)
        try await session.open(documentURL)

        try "# Atomically replaced\n".write(to: documentURL, atomically: true, encoding: .utf8)

        let reloaded = try await pollMarkdown(in: coordinator, containing: "Atomically replaced")
        XCTAssertTrue(reloaded)
        XCTAssertEqual(session.fileURL, documentURL.standardizedFileURL)
    }

    @MainActor
    func testPaperbranchCompletedSaveDoesNotReloadItsOwnContent() async throws {
        let directory = try makeTemporaryDirectory(named: "paperbranch-own-save")
        defer { try? FileManager.default.removeItem(at: directory) }
        let documentURL = directory.appendingPathComponent("saved.md")
        try "# Original\n".write(to: documentURL, atomically: true, encoding: .utf8)

        let coordinator = makeCoordinator()
        try await waitForHarnessReady(coordinator)
        let session = DocumentSession(coordinator: coordinator)
        try await session.open(documentURL)
        try await insertExclamationMark(in: coordinator)
        let becameDirty = try await pollIsDirty(coordinator, expecting: true)
        XCTAssertTrue(becameDirty)

        try await session.save()
        let saved = try await coordinator.requestSave()
        try await Task.sleep(nanoseconds: 300_000_000)
        let current = try await coordinator.requestSave()

        XCTAssertEqual(current, saved)
        XCTAssertEqual(try String(contentsOf: documentURL, encoding: .utf8), saved)
        XCTAssertFalse(session.isDirty)
    }

    @MainActor
    func testCleanDocumentShowsUnavailableStateAfterMovement() async throws {
        let directory = try makeTemporaryDirectory(named: "paperbranch-moved-document")
        defer { try? FileManager.default.removeItem(at: directory) }
        let documentURL = directory.appendingPathComponent("moved.md")
        let movedURL = directory.appendingPathComponent("moved elsewhere.md")
        try "# Original\n".write(to: documentURL, atomically: true, encoding: .utf8)

        let coordinator = makeCoordinator()
        try await waitForHarnessReady(coordinator)
        let session = DocumentSession(coordinator: coordinator)
        try await session.open(documentURL)
        try FileManager.default.moveItem(at: documentURL, to: movedURL)

        let becameUnavailable = await pollAvailability(of: session, expecting: .unavailable)
        let editorContent = try await coordinator.requestSave()
        XCTAssertTrue(becameUnavailable)
        XCTAssertTrue(editorContent.contains("Original"))
    }

    @MainActor
    func testCleanDocumentShowsUnavailableStateAfterDeletion() async throws {
        let directory = try makeTemporaryDirectory(named: "paperbranch-deleted-document")
        defer { try? FileManager.default.removeItem(at: directory) }
        let documentURL = directory.appendingPathComponent("deleted.md")
        try "# Original\n".write(to: documentURL, atomically: true, encoding: .utf8)

        let coordinator = makeCoordinator()
        try await waitForHarnessReady(coordinator)
        let session = DocumentSession(coordinator: coordinator)
        try await session.open(documentURL)
        try FileManager.default.removeItem(at: documentURL)

        let becameUnavailable = await pollAvailability(of: session, expecting: .unavailable)
        let editorContent = try await coordinator.requestSave()
        XCTAssertTrue(becameUnavailable)
        XCTAssertTrue(editorContent.contains("Original"))
    }

    @MainActor
    func testDirtyDocumentPreservesEditsAfterExternalModification() async throws {
        let directory = try makeTemporaryDirectory(named: "paperbranch-dirty-external-change")
        defer { try? FileManager.default.removeItem(at: directory) }
        let documentURL = directory.appendingPathComponent("dirty.md")
        try "# Original\n".write(to: documentURL, atomically: true, encoding: .utf8)

        let coordinator = makeCoordinator()
        try await waitForHarnessReady(coordinator)
        let session = DocumentSession(coordinator: coordinator)
        try await session.open(documentURL)
        try await insertExclamationMark(in: coordinator)
        let becameDirty = try await pollIsDirty(coordinator, expecting: true)
        XCTAssertTrue(becameDirty)
        let dirtyContent = try await coordinator.requestSave()

        try "# Changed outside Paperbranch\n".write(to: documentURL, atomically: false, encoding: .utf8)
        try await Task.sleep(nanoseconds: 300_000_000)

        let current = try await coordinator.requestSave()
        XCTAssertEqual(current, dirtyContent)
        XCTAssertTrue(session.isDirty)
    }

    @MainActor
    func testDirtyDocumentShowsConflictForExternalModificationWithoutReplacingEdits() async throws {
        let directory = try makeTemporaryDirectory(named: "paperbranch-dirty-conflict")
        defer { try? FileManager.default.removeItem(at: directory) }
        let documentURL = directory.appendingPathComponent("conflicted.md")
        try "# Original\n".write(to: documentURL, atomically: true, encoding: .utf8)

        let coordinator = makeCoordinator()
        try await waitForHarnessReady(coordinator)
        let session = DocumentSession(coordinator: coordinator)
        try await session.open(documentURL)
        try await insertExclamationMark(in: coordinator)
        let becameDirty = try await pollIsDirty(coordinator, expecting: true)
        XCTAssertTrue(becameDirty)
        let keptContent = try await coordinator.requestSave()

        try "# Changed outside Paperbranch\n".write(to: documentURL, atomically: false, encoding: .utf8)

        let becameConflicted = await pollConflict(of: session, expecting: .externalChange(documentURL))
        let currentContent = try await coordinator.requestSave()
        XCTAssertTrue(becameConflicted)
        XCTAssertEqual(currentContent, keptContent)
        XCTAssertTrue(session.isDirty)
    }

    @MainActor
    func testReloadDiskVersionReplacesConflictedEditsAndClearsStates() async throws {
        let directory = try makeTemporaryDirectory(named: "paperbranch-reload-conflict")
        defer { try? FileManager.default.removeItem(at: directory) }
        let documentURL = directory.appendingPathComponent("reload.md")
        try "# Original\n".write(to: documentURL, atomically: true, encoding: .utf8)

        let coordinator = makeCoordinator()
        try await waitForHarnessReady(coordinator)
        let session = DocumentSession(coordinator: coordinator)
        try await session.open(documentURL)
        try await insertExclamationMark(in: coordinator)
        let becameDirty = try await pollIsDirty(coordinator, expecting: true)
        XCTAssertTrue(becameDirty)
        try "# Disk version\n".write(to: documentURL, atomically: false, encoding: .utf8)
        let becameConflicted = await pollConflict(of: session, expecting: .externalChange(documentURL))
        XCTAssertTrue(becameConflicted)

        try await session.reloadDiskVersion()

        let current = try await coordinator.requestSave()
        XCTAssertTrue(current.contains("Disk version"))
        XCTAssertFalse(session.isDirty)
        XCTAssertNil(session.conflict)
    }

    @MainActor
    func testKeepEditingRetainsConflictedEditsWithoutWritingDisk() async throws {
        let directory = try makeTemporaryDirectory(named: "paperbranch-keep-conflict")
        defer { try? FileManager.default.removeItem(at: directory) }
        let documentURL = directory.appendingPathComponent("keep.md")
        try "# Original\n".write(to: documentURL, atomically: true, encoding: .utf8)

        let coordinator = makeCoordinator()
        try await waitForHarnessReady(coordinator)
        let session = DocumentSession(coordinator: coordinator)
        try await session.open(documentURL)
        try await insertExclamationMark(in: coordinator)
        let becameDirty = try await pollIsDirty(coordinator, expecting: true)
        XCTAssertTrue(becameDirty)
        let keptContent = try await coordinator.requestSave()
        let diskContent = "# Disk version\n"
        try diskContent.write(to: documentURL, atomically: false, encoding: .utf8)
        let becameConflicted = await pollConflict(of: session, expecting: .externalChange(documentURL))
        XCTAssertTrue(becameConflicted)

        session.keepEditing()

        let current = try await coordinator.requestSave()
        XCTAssertEqual(current, keptContent)
        XCTAssertEqual(try String(contentsOf: documentURL, encoding: .utf8), diskContent)
        XCTAssertTrue(session.isDirty)
        XCTAssertNil(session.conflict)
    }

    @MainActor
    func testSaveAfterKeepingConflictRequiresConfirmationAndLeavesBothVersionsUnchanged() async throws {
        let directory = try makeTemporaryDirectory(named: "paperbranch-cancel-overwrite")
        defer { try? FileManager.default.removeItem(at: directory) }
        let documentURL = directory.appendingPathComponent("overwrite.md")
        try "# Original\n".write(to: documentURL, atomically: true, encoding: .utf8)

        let coordinator = makeCoordinator()
        try await waitForHarnessReady(coordinator)
        let session = DocumentSession(coordinator: coordinator)
        try await session.open(documentURL)
        try await insertExclamationMark(in: coordinator)
        let becameDirty = try await pollIsDirty(coordinator, expecting: true)
        XCTAssertTrue(becameDirty)
        let keptContent = try await coordinator.requestSave()
        try "# First disk version\n".write(to: documentURL, atomically: false, encoding: .utf8)
        let becameConflicted = await pollConflict(of: session, expecting: .externalChange(documentURL))
        XCTAssertTrue(becameConflicted)
        session.keepEditing()
        let latestDiskContent = "# Latest disk version\n"
        try latestDiskContent.write(to: documentURL, atomically: false, encoding: .utf8)

        await XCTAssertThrowsErrorAsync { try await session.save() }

        XCTAssertEqual(try String(contentsOf: documentURL, encoding: .utf8), latestDiskContent)
        let currentContent = try await coordinator.requestSave()
        XCTAssertEqual(currentContent, keptContent)
        XCTAssertTrue(session.isDirty)
    }

    @MainActor
    func testConfirmedSaveAfterKeepingConflictOverwritesLatestDiskVersion() async throws {
        let directory = try makeTemporaryDirectory(named: "paperbranch-confirm-overwrite")
        defer { try? FileManager.default.removeItem(at: directory) }
        let documentURL = directory.appendingPathComponent("confirm.md")
        try "# Original\n".write(to: documentURL, atomically: true, encoding: .utf8)

        let coordinator = makeCoordinator()
        try await waitForHarnessReady(coordinator)
        let session = DocumentSession(coordinator: coordinator)
        try await session.open(documentURL)
        try await insertExclamationMark(in: coordinator)
        let becameDirty = try await pollIsDirty(coordinator, expecting: true)
        XCTAssertTrue(becameDirty)
        let keptContent = try await coordinator.requestSave()
        try "# External version\n".write(to: documentURL, atomically: false, encoding: .utf8)
        let becameConflicted = await pollConflict(of: session, expecting: .externalChange(documentURL))
        XCTAssertTrue(becameConflicted)
        session.keepEditing()

        try await session.save(overwritingExternalChanges: true)

        XCTAssertEqual(try String(contentsOf: documentURL, encoding: .utf8), keptContent)
        XCTAssertFalse(session.isDirty)
        XCTAssertNil(session.conflict)
    }

    @MainActor
    func testRepeatedExternalChangesKeepEditsAndReloadTheLatestDiskVersion() async throws {
        let directory = try makeTemporaryDirectory(named: "paperbranch-repeated-conflict")
        defer { try? FileManager.default.removeItem(at: directory) }
        let documentURL = directory.appendingPathComponent("repeated.md")
        try "# Original\n".write(to: documentURL, atomically: true, encoding: .utf8)

        let coordinator = makeCoordinator()
        try await waitForHarnessReady(coordinator)
        let session = DocumentSession(coordinator: coordinator)
        try await session.open(documentURL)
        try await insertExclamationMark(in: coordinator)
        let becameDirty = try await pollIsDirty(coordinator, expecting: true)
        XCTAssertTrue(becameDirty)
        let keptContent = try await coordinator.requestSave()
        try "# First external version\n".write(to: documentURL, atomically: false, encoding: .utf8)
        let becameConflicted = await pollConflict(of: session, expecting: .externalChange(documentURL))
        XCTAssertTrue(becameConflicted)
        session.keepEditing()

        let latestDiskContent = "# Second external version\n"
        try latestDiskContent.write(to: documentURL, atomically: true, encoding: .utf8)
        let conflictedAgain = await pollConflict(of: session, expecting: .externalChange(documentURL))
        XCTAssertTrue(conflictedAgain)
        let currentContent = try await coordinator.requestSave()
        XCTAssertEqual(currentContent, keptContent)

        try await session.reloadDiskVersion()
        XCTAssertEqual(try String(contentsOf: documentURL, encoding: .utf8), latestDiskContent)
        let reloadedContent = try await coordinator.requestSave()
        XCTAssertTrue(reloadedContent.contains("Second external version"))
    }

    @MainActor
    func testConflictedDocumentRemainsDirtyForTheStandardCloseWorkflow() async throws {
        let directory = try makeTemporaryDirectory(named: "paperbranch-conflicted-close")
        defer { try? FileManager.default.removeItem(at: directory) }
        let documentURL = directory.appendingPathComponent("close.md")
        try "# Original\n".write(to: documentURL, atomically: true, encoding: .utf8)

        let coordinator = makeCoordinator()
        try await waitForHarnessReady(coordinator)
        let session = DocumentSession(coordinator: coordinator)
        try await session.open(documentURL)
        try await insertExclamationMark(in: coordinator)
        let becameDirty = try await pollIsDirty(coordinator, expecting: true)
        XCTAssertTrue(becameDirty)
        try "# External version\n".write(to: documentURL, atomically: false, encoding: .utf8)
        let becameConflicted = await pollConflict(of: session, expecting: .externalChange(documentURL))

        XCTAssertTrue(becameConflicted)
        XCTAssertTrue(session.isDirty, "AppDelegate routes dirty sessions through Save, Cancel, and Discard before close")
    }

    @MainActor
    func testExternalReplacePreservesDirtyContent() async throws {
        let coordinator = makeCoordinator()
        try await waitForHarnessReady(coordinator)
        try await loadFixture(coordinator, markdown: "# Original\n")

        // Let Milkdown's own mount-time listener callback (fired once for
        // the initial load, comparing the loaded content against itself)
        // settle before making an edit, so it cannot race with -- and
        // overwrite -- the dirty state the edit below sets.
        _ = try await coordinator.webView.callAsyncJavaScript(
            "return await new Promise(resolve => setTimeout(() => resolve(true), 50));",
            contentWorld: .page
        )

        // Force a genuine dirty transaction inside Milkdown by inserting
        // text at the end of the document body via the DOM, dispatched as
        // a real ProseMirror-observed input event.
        _ = try await coordinator.webView.evaluateJavaScript(
            """
            (function() {
              const root = document.querySelector('#editor-root .ProseMirror');
              const heading = root.querySelector('h1');
              root.focus();
              const range = document.createRange();
              range.selectNodeContents(heading);
              range.collapse(false);
              const selection = window.getSelection();
              selection.removeAllRanges();
              selection.addRange(range);
              document.execCommand('insertText', false, '!');
            })();
            """
        )
        // ProseMirror syncs its model from the DOM selectionchange/input
        // events asynchronously (the same reason
        // tests/support/editing.ts's placeCursorAtEnd and the browser
        // suite's "an edit marks the document dirty" test both wait --
        // the latter via Playwright's expect.poll -- rather than asserting
        // immediately), so this polls for the transition instead of
        // asserting right away.
        let dirtyBeforeReplace = try await pollIsDirty(coordinator, expecting: true)
        XCTAssertTrue(dirtyBeforeReplace, "expected the inserted text to mark the document dirty")

        let dirtyContent = try await coordinator.requestSave()

        let applied = try await coordinator.externalReplace(markdown: "# Replaced externally\n")
        XCTAssertFalse(applied, "a dirty document must not be replaced by external content")

        let stillDirtyContent = try await coordinator.requestSave()
        XCTAssertEqual(stillDirtyContent, dirtyContent)
    }

    @MainActor
    func testExternalReplaceOfUnsafeContentIsBlockedNotLoaded() async throws {
        let coordinator = makeCoordinator()
        try await waitForHarnessReady(coordinator)
        try await loadFixture(coordinator, markdown: "# Original\n")

        let mathDoc = "Inline math $E = mc^2$ here.\n"
        let applied = try await coordinator.externalReplace(markdown: mathDoc)
        XCTAssertTrue(applied, "the admission check itself is the applied decision")

        let admission =
            try await coordinator.webView.evaluateJavaScript(
                "document.getElementById('editor-root').dataset.admission"
            ) as? String
        XCTAssertEqual(admission, "blocked")

        let returned = try await coordinator.requestSave()
        XCTAssertEqual(returned, mathDoc, "a blocked document's source must be preserved byte-for-byte")
    }

    @MainActor
    func testOnlyTheNarrowMessageHandlerIsRegistered() async throws {
        let coordinator = makeCoordinator()
        try await waitForHarnessReady(coordinator)

        // The bridge exposes exactly two native-facing calls and nothing
        // resembling file access.
        let surface =
            try await coordinator.webView.evaluateJavaScript(
                "Object.keys(window.paperbranchNativeBridge).sort()"
            ) as? [String]
        XCTAssertEqual(surface, ["externalReplace", "loadDocument", "requestSave", "saveSucceeded", "selectOutline"])

        XCTAssertEqual(BridgeCoordinator.messageHandlerName, "paperbranch")
    }

    @MainActor
    private func isDirty(_ coordinator: BridgeCoordinator) async throws -> Bool {
        (try await coordinator.webView.evaluateJavaScript("window.editorContract.isDirty()"))
            as? Bool ?? false
    }

    @MainActor
    private func pollIsDirty(
        _ coordinator: BridgeCoordinator,
        expecting expected: Bool,
        attempts: Int = 20,
        intervalNanoseconds: UInt64 = 50_000_000
    ) async throws -> Bool {
        var last = false
        for _ in 0..<attempts {
            last = try await isDirty(coordinator)
            if last == expected { return last }
            try await Task.sleep(nanoseconds: intervalNanoseconds)
        }
        return last
    }

    @MainActor
    private func pollMarkdown(
        in coordinator: BridgeCoordinator,
        containing expected: String,
        attempts: Int = 40,
        intervalNanoseconds: UInt64 = 50_000_000
    ) async throws -> Bool {
        for _ in 0..<attempts {
            if try await coordinator.requestSave().contains(expected) { return true }
            try await Task.sleep(nanoseconds: intervalNanoseconds)
        }
        return false
    }

    @MainActor
    private func pollAvailability(
        of session: DocumentSession,
        expecting expected: DocumentAvailability,
        attempts: Int = 40,
        intervalNanoseconds: UInt64 = 50_000_000
    ) async -> Bool {
        for _ in 0..<attempts {
            if session.availability == expected { return true }
            try? await Task.sleep(nanoseconds: intervalNanoseconds)
        }
        return false
    }

    @MainActor
    private func pollConflict(
        of session: DocumentSession,
        expecting expected: DocumentConflict,
        attempts: Int = 40,
        intervalNanoseconds: UInt64 = 50_000_000
    ) async -> Bool {
        for _ in 0..<attempts {
            if session.conflict == expected { return true }
            try? await Task.sleep(nanoseconds: intervalNanoseconds)
        }
        return false
    }

    @MainActor
    private func insertExclamationMark(in coordinator: BridgeCoordinator) async throws {
        _ = try await coordinator.webView.callAsyncJavaScript(
            """
            const root = document.querySelector('#editor-root .ProseMirror');
            const heading = root.querySelector('h1');
            root.focus();
            const range = document.createRange();
            range.selectNodeContents(heading);
            range.collapse(false);
            const selection = window.getSelection();
            selection.removeAllRanges();
            selection.addRange(range);
            document.execCommand('insertText', false, '!');
            return true;
            """,
            contentWorld: .page
        )
    }

    @MainActor
    private func pollImageIsVisible(in coordinator: BridgeCoordinator) async throws -> Bool {
        for _ in 0..<20 {
            let visible = (try await coordinator.webView.evaluateJavaScript(
                "(() => { const image = document.querySelector('.paperbranch-local-image'); return !!image && image.complete && image.naturalWidth > 0 && image.src.startsWith('paperbranch-image:'); })()"
            )) as? Bool ?? false
            if visible { return true }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        return false
    }

    private func snapshotProofDirectoryContents() throws -> [String] {
        let editorProofDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // PaperbranchBridgeCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // native-host
        return try FileManager.default.contentsOfDirectory(atPath: editorProofDirectory.path).sorted()
    }

    private func makeTemporaryDirectory(named name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func XCTAssertThrowsErrorAsync(
        _ expression: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await expression()
            XCTFail("expected operation to throw", file: file, line: line)
        } catch {}
    }
}

/// Reads SwiftUI's rendered accessibility tree. SwiftUI builds that tree only for an assistive client, so this sets the same flag VoiceOver sets.
@MainActor
private func renderedAccessibilityElements(in root: NSView) -> [NSObject] {
    let application = NSApplication.shared
    let enhancedUserInterface = NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface")
    application.accessibilitySetValue(true, forAttribute: enhancedUserInterface)
    defer { application.accessibilitySetValue(false, forAttribute: enhancedUserInterface) }
    return accessibilityDescendants(of: root)
}

/// SwiftUI's accessibility nodes do not bridge to `NSAccessibilityProtocol`, so the tree is read through key-value coding.
@MainActor
private func accessibilityDescendants(of element: NSObject) -> [NSObject] {
    let children = element.value(forKey: "accessibilityChildren") as? [NSObject] ?? []
    return children.flatMap { [$0] + accessibilityDescendants(of: $0) }
}

@MainActor
private func accessibilityElement(_ identifier: String, in elements: [NSObject]) -> NSObject? {
    elements.first { $0.value(forKey: "accessibilityIdentifier") as? String == identifier }
}

@MainActor
private func accessibilityFrame(of element: NSObject) -> NSRect {
    (element.value(forKey: "accessibilityFrame") as? NSValue)?.rectValue ?? .zero
}

/// AppKit's user-defaults key for the Library window's frame autosave name.
private let libraryWindowFrameKey = "NSWindow Frame PaperbranchLibraryWindow"

@MainActor
private func windowContainsView(_ window: NSWindow, target: NSView) -> Bool {
    guard let root = window.contentView else { return false }
    return root === target || root.subviews.contains { windowContainsView($0, target: target) }
}

@MainActor
private func windowContainsView(_ view: NSView, target: NSView) -> Bool {
    view === target || view.subviews.contains { windowContainsView($0, target: target) }
}

private final class TestLibraryBookmarkStore: LibraryBookmarkStore {
    private var record: LibraryBookmarkRecord?
    func load() -> LibraryBookmarkRecord? { record }
    func save(_ record: LibraryBookmarkRecord) { self.record = record }
    func clear() { record = nil }
}

private struct TestLibraryBookmarkCodec: LibraryBookmarkCodec {
    func makeBookmark(for url: URL) throws -> Data { Data(url.path.utf8) }
    func resolveBookmark(_ data: Data) throws -> URL {
        guard let path = String(data: data, encoding: .utf8) else { throw LibraryAccessError.unavailable }
        return URL(fileURLWithPath: path)
    }
}

private struct UnavailableLibraryBookmarkCodec: LibraryBookmarkCodec {
    func makeBookmark(for url: URL) throws -> Data { Data() }
    func resolveBookmark(_ data: Data) throws -> URL { throw LibraryAccessError.unavailable }
}
