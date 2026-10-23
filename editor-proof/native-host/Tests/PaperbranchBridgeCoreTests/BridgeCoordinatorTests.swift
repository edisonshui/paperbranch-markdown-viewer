import AppKit
import SwiftUI
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
    func testPresentationStaysInVariantBForRoutineStatesAndRestoresAppKitOnlyForUnavailableOrEmptyStates() throws {
        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-guarded-presentation")
        defer { try? FileManager.default.removeItem(at: libraryURL) }
        let documentURL = libraryURL.appendingPathComponent("Selected.md")
        try "# Selected\n".write(to: documentURL, atomically: true, encoding: .utf8)
        let folderURL = libraryURL.appendingPathComponent("Folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let nestedURL = folderURL.appendingPathComponent("Nested.md")
        try "# Nested\n".write(to: nestedURL, atomically: true, encoding: .utf8)
        let library = try LibraryBrowser.choose(libraryURL)
        let emptyLibraryURL = try makeTemporaryDirectory(named: "paperbranch-guarded-presentation-empty")
        defer { try? FileManager.default.removeItem(at: emptyLibraryURL) }
        let emptyLibrary = try LibraryBrowser.choose(emptyLibraryURL)
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
        let variantB = try XCTUnwrap(window.contentView)

        // Editing, a conflict, a collapsed sidebar, and a document switch in progress are routine
        // and stay in Variant B. Swapping the whole window for them made every keystroke and click jump.
        var collapsedSidebar = LibrarySidebarState()
        collapsedSidebar.toggleCollapsed()
        let routineStates: [PaperbranchWindowPresentationState] = [
            .init(library: library, sidebarState: LibrarySidebarState(), selectedDocumentURL: documentURL, document: .init(url: documentURL, kind: .library, availability: .available, isDirty: true, conflict: nil)),
            .init(library: library, sidebarState: LibrarySidebarState(), selectedDocumentURL: documentURL, document: .init(url: documentURL, kind: .library, availability: .available, isDirty: true, conflict: .externalChange(documentURL))),
            .init(library: library, sidebarState: collapsedSidebar, selectedDocumentURL: documentURL, document: .init(url: documentURL, kind: .library, availability: .available, isDirty: false, conflict: nil)),
            .init(library: library, sidebarState: LibrarySidebarState(), selectedDocumentURL: nestedURL, document: .init(url: documentURL, kind: .library, availability: .available, isDirty: false, conflict: nil)),
            .init(library: library, sidebarState: LibrarySidebarState(), selectedDocumentURL: documentURL, document: .init(url: nil, kind: .library, availability: .available, isDirty: false, conflict: nil)),
        ]
        for state in routineStates {
            XCTAssertTrue(presentation.render(state))
            XCTAssertTrue(window.contentView === variantB)
        }

        // Ticket 43: a missing or empty Library and an unavailable document have designed state views in Variant B.
        for state: PaperbranchWindowPresentationState in [
            .init(library: nil, sidebarState: LibrarySidebarState(), selectedDocumentURL: documentURL, document: .init(url: documentURL, kind: .library, availability: .available, isDirty: false, conflict: nil)),
            .init(library: emptyLibrary, sidebarState: LibrarySidebarState(), selectedDocumentURL: nil, document: .init(url: nil, kind: .library, availability: .available, isDirty: false, conflict: nil)),
            .init(library: library, sidebarState: LibrarySidebarState(), selectedDocumentURL: documentURL, document: .init(url: documentURL, kind: .library, availability: .unavailable, isDirty: false, conflict: nil)),
        ] {
            XCTAssertTrue(presentation.render(state))
            XCTAssertTrue(window.contentView === variantB)
        }

        let excludedStates: [PaperbranchWindowPresentationState] = [
            .init(library: library, sidebarState: LibrarySidebarState(), selectedDocumentURL: nil, document: nil),
            .init(library: library, sidebarState: LibrarySidebarState(), selectedDocumentURL: documentURL, document: .init(url: documentURL, kind: .standalone, availability: .available, isDirty: false, conflict: nil)),
            .init(library: library, sidebarState: LibrarySidebarState(), selectedDocumentURL: libraryURL.appendingPathComponent("Elsewhere.md"), document: .init(url: documentURL, kind: .library, availability: .available, isDirty: false, conflict: nil)),
        ]
        for state in excludedStates {
            XCTAssertFalse(presentation.render(state))
            XCTAssertTrue(window.contentView === appKitContent)
        }
    }

    @MainActor
    func testReaderTopBarShowsUnsavedEditsAndConflictsAndCollapsedSidebarHidesOnlyTheSidebar() throws {
        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-reader-document-status")
        defer { try? FileManager.default.removeItem(at: libraryURL) }
        let documentURL = libraryURL.appendingPathComponent("Reading.md")
        try "# Reading\n".write(to: documentURL, atomically: true, encoding: .utf8)
        let library = try LibraryBrowser.choose(libraryURL)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1300, height: 800), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        let presentation = PaperbranchWindowPresentation(window: window, webView: WKWebView())
        func render(dirty: Bool, conflict: DocumentConflict?, sidebar: LibrarySidebarState = LibrarySidebarState()) throws -> [NSObject] {
            XCTAssertTrue(presentation.render(.init(library: library, sidebarState: sidebar, selectedDocumentURL: documentURL, document: .init(url: documentURL, kind: .library, availability: .available, isDirty: dirty, conflict: conflict))))
            let root = try XCTUnwrap(window.contentView)
            root.layoutSubtreeIfNeeded()
            return renderedAccessibilityElements(in: root)
        }
        func topBarLabel(_ elements: [NSObject]) -> String? {
            accessibilityElement("paperbranch.reader.topbar", in: elements)?.value(forKey: "accessibilityLabel") as? String
        }

        XCTAssertEqual(topBarLabel(try render(dirty: false, conflict: nil)), "Reader top bar for Reading.md")
        XCTAssertEqual(topBarLabel(try render(dirty: true, conflict: nil)), "Reader top bar for Reading.md, Edited")
        XCTAssertEqual(topBarLabel(try render(dirty: true, conflict: .externalChange(documentURL))), "Reader top bar for Reading.md, Changed on disk")

        var collapsed = LibrarySidebarState()
        collapsed.toggleCollapsed()
        let elements = try render(dirty: false, conflict: nil, sidebar: collapsed)
        XCTAssertNil(accessibilityElement("paperbranch.library.sidebar", in: elements))
        XCTAssertNotNil(accessibilityElement("paperbranch.reader.document-canvas", in: elements))
        let toggle = try XCTUnwrap(accessibilityElement("paperbranch.reader.toggle-sidebar", in: elements))
        XCTAssertEqual(toggle.value(forKey: "accessibilityLabel") as? String, "Show Library sidebar")
        // The window buttons sit at the top left, so the toggle moves clear of them.
        let zoomButton = try XCTUnwrap(window.standardWindowButton(.zoomButton))
        let zoomFrame = window.convertToScreen(zoomButton.convert(zoomButton.bounds, to: nil))
        XCTAssertGreaterThan(accessibilityFrame(of: toggle).minX, zoomFrame.maxX)
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
    func testReaderPresentationDropsTheTitleBarRowAndRestoreBringsItBack() throws {
        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-window-presentation-title-bar")
        defer { try? FileManager.default.removeItem(at: libraryURL) }
        let documentURL = libraryURL.appendingPathComponent("Reading.md")
        try "# Reading\n".write(to: documentURL, atomically: true, encoding: .utf8)

        // Mirrors makeLibraryWindow: a titled window with a toolbar and a view controller for its AppKit content.
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1300, height: 800), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Reading.md"
        let toolbar = NSToolbar(identifier: "PaperbranchTitleBarTest-\(UUID().uuidString)")
        window.toolbar = toolbar
        let appKitContent = NSViewController()
        appKitContent.view = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 220))
        window.contentViewController = appKitContent
        window.setFrame(NSRect(x: 0, y: 0, width: 1300, height: 800), display: false)
        let chosenFrame = window.frame
        let presentation = PaperbranchWindowPresentation(window: window, webView: WKWebView())
        let library = try LibraryBrowser.choose(libraryURL)
        let document = PaperbranchDocumentPresentationState(url: documentURL, kind: .library, availability: .available, isDirty: false, conflict: nil)
        let reading = PaperbranchWindowPresentationState(library: library, sidebarState: LibrarySidebarState(), selectedDocumentURL: documentURL, document: document)
        let emptyReader = PaperbranchWindowPresentationState(library: library, sidebarState: LibrarySidebarState(), selectedDocumentURL: nil, document: document)

        for state in [reading, emptyReader] {
            XCTAssertTrue(presentation.render(state))

            // No title bar row or toolbar: the content fills the window and the reader top bar names the document.
            XCTAssertTrue(window.styleMask.contains(.fullSizeContentView))
            XCTAssertTrue(window.titlebarAppearsTransparent)
            XCTAssertEqual(window.titleVisibility, .hidden)
            // An empty unified toolbar replaces the AppKit one, so the window buttons center in the top bar.
            XCTAssertFalse(window.toolbar === toolbar)
            XCTAssertTrue(window.toolbar?.items.isEmpty ?? false)
            XCTAssertEqual(window.title, "Reading.md")
            let root = try XCTUnwrap(window.contentView)
            XCTAssertEqual(root.frame.size, window.frame.size)
            root.layoutSubtreeIfNeeded()
            let elements = renderedAccessibilityElements(in: root)

            // Accessibility frames use bottom-left screen coordinates, and a containing element's frame spans its children.
            // The reader top bar shares the window buttons' row, and the buttons stay over the sidebar header.
            let topBar = accessibilityElement("paperbranch.reader.topbar", in: elements).map(accessibilityFrame(of:)) ?? .zero
            let sidebar = accessibilityElement("paperbranch.library.sidebar", in: elements).map(accessibilityFrame(of:)) ?? .zero
            let wordmark = accessibilityElement("paperbranch.library.wordmark", in: elements).map(accessibilityFrame(of:)) ?? .zero
            let closeButton = try XCTUnwrap(window.standardWindowButton(.closeButton))
            let closeFrame = window.convertToScreen(closeButton.convert(closeButton.bounds, to: nil))
            XCTAssertGreaterThan(topBar.maxY, closeFrame.minY)
            XCTAssertTrue(sidebar.contains(closeFrame))
            XCTAssertFalse(wordmark.isEmpty)
            XCTAssertLessThanOrEqual(wordmark.maxY, closeFrame.minY)

            presentation.restoreAppKitPresentation()
            XCTAssertTrue(window.contentViewController === appKitContent)
            XCTAssertFalse(window.styleMask.contains(.fullSizeContentView))
            XCTAssertFalse(window.titlebarAppearsTransparent)
            XCTAssertEqual(window.titleVisibility, .visible)
            XCTAssertTrue(window.toolbar === toolbar)
            XCTAssertTrue(toolbar.isVisible)
            XCTAssertEqual(window.title, "Reading.md")
            XCTAssertEqual(window.frame, chosenFrame)
        }
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
        // AppDelegate routes sidebar selections through routeFinderOpen, which opens the document.
        var routedSelections: [URL] = []
        sidebar.selectDocument = { url in routedSelections.append(url) }
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
    func testLibraryChromeFollowsTheAppearanceWithTokenColors() throws {
        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-window-presentation-appearance")
        defer { try? FileManager.default.removeItem(at: libraryURL) }
        let documentURL = libraryURL.appendingPathComponent("Reading.md")
        try "# Reading\n".write(to: documentURL, atomically: true, encoding: .utf8)
        let library = try LibraryBrowser.choose(libraryURL)

        // Ticket 41: the sidebar and wordmark follow the window's appearance with the design tokens.
        for (appearance, wordmarkIsLight) in [(NSAppearance.Name.aqua, false), (.darkAqua, true)] {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1300, height: 800), styleMask: [.titled], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: appearance)
            let presentation = PaperbranchWindowPresentation(window: window, webView: WKWebView())
            XCTAssertTrue(presentation.render(.init(
                library: library,
                sidebarState: LibrarySidebarState(),
                selectedDocumentURL: documentURL,
                document: .init(url: documentURL, kind: .library, availability: .available, isDirty: false, conflict: nil)
            )))
            let root = try XCTUnwrap(window.contentView)
            root.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(root.bitmapImageRepForCachingDisplay(in: root.bounds))
            root.cacheDisplay(in: root.bounds, to: bitmap)
            let scale = CGFloat(bitmap.pixelsWide) / root.bounds.width
            func pixel(_ point: NSPoint) -> NSColor? {
                let row = root.isFlipped ? Int(point.y * scale) : bitmap.pixelsHigh - 1 - Int(point.y * scale)
                return bitmap.colorAt(x: Int(point.x * scale), y: row)?.usingColorSpace(.sRGB)
            }
            func hex(_ color: NSColor?) -> String {
                guard let color else { return "none" }
                return String(format: "#%02X%02X%02X", Int((color.redComponent * 255).rounded()), Int((color.greenComponent * 255).rounded()), Int((color.blueComponent * 255).rounded()))
            }
            // The bitmap capture shifts colors in its own color space, so the reference is a --sidebar swatch
            // captured the same way, under the same appearance.
            let swatchWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 40, height: 40), styleMask: [.titled], backing: .buffered, defer: false)
            swatchWindow.appearance = NSAppearance(named: appearance)
            let swatch = NSHostingView(rootView: Rectangle().fill(PBColor.sidebar).frame(width: 40, height: 40))
            swatchWindow.contentView = swatch
            swatch.layoutSubtreeIfNeeded()
            let swatchBitmap = try XCTUnwrap(swatch.bitmapImageRepForCachingDisplay(in: swatch.bounds))
            swatch.cacheDisplay(in: swatch.bounds, to: swatchBitmap)
            let reference = hex(swatchBitmap.colorAt(x: 10, y: 10)?.usingColorSpace(.sRGB))
            XCTAssertNotEqual(reference, "#FFFFFF", "the swatch did not render")
            // An empty spot near the sidebar's bottom.
            XCTAssertEqual(hex(pixel(NSPoint(x: 20, y: root.isFlipped ? root.bounds.height - 20 : 20))), reference, "\(appearance.rawValue) sidebar")

            let wordmark = try XCTUnwrap(accessibilityElement("paperbranch.library.wordmark", in: renderedAccessibilityElements(in: root)))
            let frame = root.convert(window.convertFromScreen(accessibilityFrame(of: wordmark)), from: nil)
            var extreme: CGFloat = wordmarkIsLight ? 0 : 1
            // The text starts after the 25-point tile and its 9-point gap.
            for x in stride(from: frame.minX + 34, to: frame.maxX, by: 0.5) {
                for y in stride(from: frame.minY, to: frame.maxY, by: 0.5) {
                    guard let color = pixel(NSPoint(x: x, y: y)) else { continue }
                    let luminance = 0.2126 * color.redComponent + 0.7152 * color.greenComponent + 0.0722 * color.blueComponent
                    extreme = wordmarkIsLight ? max(extreme, luminance) : min(extreme, luminance)
                }
            }
            if wordmarkIsLight { XCTAssertGreaterThan(extreme, 0.8, "dark wordmark ink") } else { XCTAssertLessThan(extreme, 0.2, "light wordmark ink") }
        }
    }

    func testChromeUsesTokenColorsOnly() throws {
        let sources = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/PaperbranchBridgeCore")
        for name in ["PaperbranchWindowPresentation.swift", "PaperbranchComponents.swift"] {
            let source = try String(contentsOf: sources.appendingPathComponent(name), encoding: .utf8)
            XCTAssertFalse(source.contains("Color(red:"), "\(name) has a raw color literal")
        }
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
        // The Document view ends the article with its own footer, so no SwiftUI footer is pinned to the window.
        XCTAssertNil(accessibilityElement("paperbranch.reader.footer", in: elements))
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
        // The Document view spans the reader so its margins scroll and its scroll bar sits at the window's edge.
        // The editor's own CSS keeps the article a centered 710-point column.
        XCTAssertEqual(webViewFrame.width, readerColumn.width, accuracy: 1)
        XCTAssertEqual(canvasFrame.midX, readerColumn.midX, accuracy: 1)
        XCTAssertGreaterThanOrEqual(accessibilityFrame(of: topBar).minY, canvasFrame.maxY)
        XCTAssertEqual(canvasFrame.minY, rootFrame.minY, accuracy: 1)

        XCTAssertTrue(windowContainsView(window, target: webView))
        XCTAssertFalse(appKitDocumentView.constraints.contains { constraint in
            constraint.firstItem as? WKWebView === webView || constraint.secondItem as? WKWebView === webView
        })
    }

    @MainActor
    func testSidebarSlidesInOneMediumDurationAndNotUnderReduceMotion() throws {
        // Ticket 46: one --duration-medium slide, and no animation under Reduce Motion.
        XCTAssertEqual(PaperbranchWindowPresentation.sidebarSlideDuration(reduceMotion: false), PBMotion.medium)
        XCTAssertNil(PaperbranchWindowPresentation.sidebarSlideDuration(reduceMotion: true))

        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-sidebar-slide")
        defer { try? FileManager.default.removeItem(at: libraryURL) }
        let documentURL = libraryURL.appendingPathComponent("Reading.md")
        try "# Reading\n".write(to: documentURL, atomically: true, encoding: .utf8)
        let library = try LibraryBrowser.choose(libraryURL)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1300, height: 800), styleMask: [.titled], backing: .buffered, defer: false)
        let presentation = PaperbranchWindowPresentation(window: window, webView: WKWebView())
        let document = PaperbranchDocumentPresentationState(url: documentURL, kind: .library, availability: .available, isDirty: false, conflict: nil)
        XCTAssertTrue(presentation.render(.init(library: library, sidebarState: LibrarySidebarState(), selectedDocumentURL: documentURL, document: document)))
        let variantB = try XCTUnwrap(window.contentView)
        var collapsed = LibrarySidebarState()
        collapsed.toggleCollapsed()
        XCTAssertTrue(presentation.render(.init(library: library, sidebarState: collapsed, selectedDocumentURL: documentURL, document: document)))
        // The slide happens inside the same view: the window keeps its content and frame.
        XCTAssertTrue(window.contentView === variantB)
        XCTAssertTrue(presentation.isSidebarCollapsed)
    }

    @MainActor
    func testReaderSidebarToggleKeepsVariantBAndDelegatesToExistingSidebarWorkflow() throws {
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

        let variantB = try XCTUnwrap(window.contentView)
        presentation.toggleSidebar()

        XCTAssertTrue(window.contentView === variantB)
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
    func testLibraryAndStandaloneWindowsFollowTheSystemAppearance() throws {
        let libraryWindow = AppDelegate().makeLibraryWindow()
        defer { libraryWindow.setFrameAutosaveName("") }
        let standalone = StandaloneDocumentWindow(delegate: AppDelegate())

        // Ticket 41 replaces Ticket 16's always-dark Library window: the design skill follows macOS.
        XCTAssertNil(libraryWindow.appearance)
        XCTAssertNil(standalone.window.appearance)
    }

    @MainActor
    func testClosingStandaloneWindowLeavesItAliveForItsOwner() throws {
        let delegate = AppDelegate()
        // The app's event loop drains a pool after each event, so each step here drains its own.
        let standalone = autoreleasepool { StandaloneDocumentWindow(delegate: delegate) }
        weak var closedWindow = standalone.window
        autoreleasepool { standalone.window.makeKeyAndOrderFront(nil) }

        autoreleasepool { standalone.window.performClose(nil) }
        RunLoop.main.run(until: Date().addingTimeInterval(1))

        // AppDelegate owns each Standalone window until windowWillClose drops it. A window that
        // also releases itself on close is released twice, which crashed the close animation.
        guard closedWindow != nil else {
            // Keeps the runner alive: releasing the owner would release the freed window again.
            _ = Unmanaged.passRetained(standalone)
            return XCTFail("Closing the Standalone window freed it while its owner still held it")
        }
        XCTAssertFalse(standalone.window.isVisible)
    }

    @MainActor
    func testDiscardInCloseAlertClosesDirtyStandaloneWindow() async throws {
        let folderURL = try makeTemporaryDirectory(named: "paperbranch-standalone-discard")
        defer { try? FileManager.default.removeItem(at: folderURL) }
        let documentURL = folderURL.appendingPathComponent("Outside.md").standardizedFileURL
        try "# Outside\n".write(to: documentURL, atomically: true, encoding: .utf8)
        let delegate = AppDelegate()
        try await delegate.openStandaloneDocument(at: documentURL)
        let standalone = try XCTUnwrap(delegate.standaloneWindows[documentURL])
        try await insertExclamationMark(in: standalone.coordinator)
        for _ in 0..<40 where !standalone.session.isDirty { try await Task.sleep(nanoseconds: 50_000_000) }
        XCTAssertTrue(standalone.session.isDirty)

        standalone.window.performClose(nil)
        for _ in 0..<40 where standalone.window.attachedSheet == nil { try await Task.sleep(nanoseconds: 50_000_000) }
        let sheet = try XCTUnwrap(standalone.window.attachedSheet, "Closing a dirty window did not show the close alert")
        let discard = try XCTUnwrap(sheet.contentView.flatMap { buttons(in: $0) }?.first { $0.title == "Discard" })
        discard.performClick(nil)
        for _ in 0..<40 where standalone.window.isVisible { try await Task.sleep(nanoseconds: 50_000_000) }

        XCTAssertFalse(standalone.window.isVisible, "Discard left the Standalone window open")
        XCTAssertNil(delegate.standaloneWindows[documentURL], "windowWillClose did not run for the discarded window")
        XCTAssertEqual(try String(contentsOf: documentURL, encoding: .utf8), "# Outside\n")
    }

    @MainActor
    func testCommandSSavesTheKeyWindowsDocumentBeforeTheDocumentViewSeesTheKey() async throws {
        let folderURL = try makeTemporaryDirectory(named: "paperbranch-command-s")
        defer { try? FileManager.default.removeItem(at: folderURL) }
        let documentURL = folderURL.appendingPathComponent("Outside.md").standardizedFileURL
        try "# Outside\n".write(to: documentURL, atomically: true, encoding: .utf8)
        let delegate = AppDelegate()
        try await delegate.openStandaloneDocument(at: documentURL)
        let standalone = try XCTUnwrap(delegate.standaloneWindows[documentURL])
        defer { standalone.window.close() }
        try await insertExclamationMark(in: standalone.coordinator)
        for _ in 0..<40 where !standalone.session.isDirty { try await Task.sleep(nanoseconds: 50_000_000) }
        XCTAssertTrue(standalone.session.isDirty)
        func key(_ flags: NSEvent.ModifierFlags) -> NSEvent {
            NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: standalone.window.windowNumber, context: nil, characters: "s", charactersIgnoringModifiers: "s", isARepeat: false, keyCode: 1)!
        }

        // Other shortcuts and other windows pass through untouched.
        XCTAssertNotNil(delegate.handleKeyDown(key([.command, .shift]), keyWindow: standalone.window))
        XCTAssertNotNil(delegate.handleKeyDown(key([]), keyWindow: standalone.window))
        XCTAssertNotNil(delegate.handleKeyDown(key(.command), keyWindow: NSWindow()))
        XCTAssertTrue(standalone.session.isDirty)

        // WKWebView claims every key equivalent while it has focus, and in the Variant B presentation
        // its handback never reached the File menu, so Command-S is taken before the Document view.
        XCTAssertNil(delegate.handleKeyDown(key(.command), keyWindow: standalone.window))
        for _ in 0..<40 where standalone.session.isDirty { try await Task.sleep(nanoseconds: 50_000_000) }
        XCTAssertFalse(standalone.session.isDirty)
        XCTAssertNotEqual(try String(contentsOf: documentURL, encoding: .utf8), "# Outside\n")
    }

    @MainActor
    func testLinkPromptShowsASheetAndReturnsTheTypedURL() async throws {
        let coordinator = BridgeCoordinator()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
        // The test owns the window, so closing it must not release it a second time.
        window.isReleasedWhenClosed = false
        window.contentView = coordinator.webView
        defer { window.close() }
        coordinator.webView.loadHTMLString("<p>Prompt</p>", baseURL: nil)
        for _ in 0..<40 where coordinator.webView.isLoading { try await Task.sleep(nanoseconds: 50_000_000) }

        // The formatting popover's link button asks with window.prompt, which WKWebView answers only through its UI delegate.
        let answer = Task { try await coordinator.webView.callAsyncJavaScript("return prompt('Link URL')", contentWorld: .page) as? String }
        for _ in 0..<40 where window.attachedSheet == nil { try await Task.sleep(nanoseconds: 50_000_000) }
        let sheet = try XCTUnwrap(window.attachedSheet, "window.prompt showed no sheet")
        let field = try XCTUnwrap(sheet.contentView.flatMap { textFields(in: $0) }?.first { $0.isEditable })
        field.stringValue = "https://example.com"
        let add = try XCTUnwrap(sheet.contentView.flatMap { buttons(in: $0) }?.first { $0.title == "Add Link" })
        add.performClick(nil)

        let typed = try await answer.value
        XCTAssertEqual(typed, "https://example.com")
    }

    private func textFields(in view: NSView) -> [NSTextField] {
        ((view as? NSTextField).map { [$0] } ?? []) + view.subviews.flatMap { textFields(in: $0) }
    }

    @MainActor
    func testSwitchingAwayFromUnsavedEditsAsksToSaveCancelOrDiscard() async throws {
        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-switch-unsaved")
        defer { try? FileManager.default.removeItem(at: libraryURL) }
        let a = libraryURL.appendingPathComponent("A.md").standardizedFileURL
        let b = libraryURL.appendingPathComponent("B.md").standardizedFileURL
        try "# A\n".write(to: a, atomically: true, encoding: .utf8)
        try "# B\n".write(to: b, atomically: true, encoding: .utf8)
        let workflow = LibraryWorkflow(bookmarks: LibraryAccess(store: TestLibraryBookmarkStore(), codec: TestLibraryBookmarkCodec()))
        try workflow.chooseLibrary(at: libraryURL)
        let delegate = AppDelegate(libraryWorkflow: workflow)
        delegate.setUpLibraryWindow()
        let window = try XCTUnwrap(delegate.window)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        delegate.showLibrary()
        let session = try XCTUnwrap(delegate.documentSession)

        func waitFor(_ condition: () -> Bool) async throws {
            for _ in 0..<80 where !condition() { try await Task.sleep(nanoseconds: 50_000_000) }
        }
        func open(_ url: URL) async throws {
            delegate.routeFinderOpen([url])
            try await waitFor { session.fileURL == url }
            XCTAssertEqual(session.fileURL, url)
        }
        func makeDirty() async throws {
            try await insertExclamationMark(in: session.coordinator)
            try await waitFor { session.isDirty }
            XCTAssertTrue(session.isDirty)
        }
        /// Selects `url` the way a sidebar click does, then answers the sheet that appears.
        func switchTo(_ url: URL, answering title: String) async throws -> NSWindow {
            delegate.sidebarController.select(url: url)
            delegate.routeFinderOpen([url])
            return try await answerSheet(title)
        }
        func answerSheet(_ title: String) async throws -> NSWindow {
            try await waitFor { window.attachedSheet != nil }
            let sheet = try XCTUnwrap(window.attachedSheet, "No alert appeared before \(title)")
            let button = try XCTUnwrap(sheet.contentView.flatMap { buttons(in: $0) }?.first { $0.title == title })
            button.performClick(nil)
            try await waitFor { window.attachedSheet !== sheet }
            return sheet
        }
        func assertStaysOn(_ url: URL, file: StaticString = #filePath, line: UInt = #line) async throws {
            try await Task.sleep(nanoseconds: 300_000_000)
            XCTAssertEqual(session.fileURL, url, file: file, line: line)
            XCTAssertTrue(session.isDirty, file: file, line: line)
            XCTAssertEqual(workflow.selectedDocumentURL, url, file: file, line: line)
            XCTAssertEqual(delegate.sidebarController.selectedDocumentURL, url, "The sidebar selection did not snap back", file: file, line: line)
        }

        try await open(a)
        try await makeDirty()

        // Cancel keeps the edited document, and the sidebar selection snaps back to it.
        let alert = try await switchTo(b, answering: "Cancel")
        XCTAssertEqual(Set(alert.contentView.flatMap { buttons(in: $0) }?.map(\.title).filter { !$0.isEmpty } ?? []), ["Save", "Cancel", "Discard"])
        // Design skill, "Unsaved edits on switch or close": Save is the default and Discard is destructive.
        let promptButtons = alert.contentView.flatMap { buttons(in: $0) } ?? []
        XCTAssertEqual(promptButtons.first { $0.keyEquivalent == "\r" }?.title, "Save")
        XCTAssertEqual(promptButtons.first { $0.title == "Discard" }?.hasDestructiveAction, true)
        try await assertStaysOn(a)

        // Discard switches without writing.
        _ = try await switchTo(b, answering: "Discard")
        try await waitFor { session.fileURL == b }
        XCTAssertEqual(session.fileURL, b)
        XCTAssertEqual(try String(contentsOf: a, encoding: .utf8), "# A\n")

        // Save writes, then switches.
        try await open(a)
        try await makeDirty()
        _ = try await switchTo(b, answering: "Save")
        try await waitFor { session.fileURL == b }
        XCTAssertEqual(session.fileURL, b)
        XCTAssertTrue(try String(contentsOf: a, encoding: .utf8).contains("!"))

        // After a kept conflict, Save asks before overwriting (Ticket 37), and its Cancel cancels the switch.
        try await open(a)
        try await makeDirty()
        try "# A changed elsewhere\n".write(to: a, atomically: true, encoding: .utf8)
        // Ticket 44: the conflict alert's wording and buttons follow the design skill. Return keeps the edits.
        try await waitFor { window.attachedSheet != nil }
        let conflictSheet = try XCTUnwrap(window.attachedSheet)
        let conflictTexts = (conflictSheet.contentView.map { textFields(in: $0) } ?? []).map(\.stringValue)
        XCTAssertTrue(conflictTexts.contains("Changes conflict in A.md"))
        XCTAssertTrue(conflictTexts.contains("This document changed on disk while you have unsaved edits. Keep your edits, or reload the version on disk and lose them."))
        let conflictButtons = try XCTUnwrap(conflictSheet.contentView.flatMap { buttons(in: $0) }).filter { !$0.title.isEmpty }
        XCTAssertEqual(Set(conflictButtons.map(\.title)), ["Keep My Edits", "Reload from Disk"])
        XCTAssertEqual(conflictButtons.first { $0.keyEquivalent == "\r" }?.title, "Keep My Edits")
        XCTAssertEqual(conflictButtons.first { $0.title == "Reload from Disk" }?.hasDestructiveAction, true)
        _ = try await answerSheet("Keep My Edits")
        // Escape also cancels the overwrite and writes nothing.
        _ = try await switchTo(b, answering: "Save")
        try await waitFor { window.attachedSheet != nil }
        let escapeSheet = try XCTUnwrap(window.attachedSheet)
        let escape = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: escapeSheet.windowNumber, context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53))
        // The test runner has no event loop to deliver queued events to the monitor, so it calls the monitor's logic.
        XCTAssertTrue(AppDelegate.cancelOnEscape(escape, in: escapeSheet))
        try await waitFor { window.attachedSheet !== escapeSheet }
        XCTAssertFalse(window.attachedSheet === escapeSheet, "Escape did not dismiss the overwrite warning")
        try await assertStaysOn(a)
        XCTAssertEqual(try String(contentsOf: a, encoding: .utf8), "# A changed elsewhere\n")

        // Return answers the default button, Cancel, and writes nothing.
        _ = try await switchTo(b, answering: "Save")
        try await waitFor { window.attachedSheet != nil }
        let returnSheet = try XCTUnwrap(window.attachedSheet)
        let returnKey = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: returnSheet.windowNumber, context: nil, characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
        XCTAssertTrue(returnSheet.performKeyEquivalent(with: returnKey), "No button took Return")
        try await waitFor { window.attachedSheet !== returnSheet }
        try await assertStaysOn(a)
        XCTAssertEqual(try String(contentsOf: a, encoding: .utf8), "# A changed elsewhere\n")
        _ = try await switchTo(b, answering: "Save")
        let overwriteAlert = try await answerSheet("Cancel")
        // Return answers Cancel, so it writes nothing, and Overwrite is marked destructive (design skill, "Overwrite warning").
        let overwriteButtons = try XCTUnwrap(overwriteAlert.contentView.flatMap { buttons(in: $0) }).filter { !$0.title.isEmpty }
        XCTAssertEqual(overwriteButtons.first { $0.keyEquivalent == "\r" }?.title, "Cancel")
        XCTAssertEqual(overwriteButtons.map(\.title), ["Cancel", "Overwrite"])
        XCTAssertEqual(overwriteButtons.first { $0.title == "Overwrite" }?.hasDestructiveAction, true)
        try await assertStaysOn(a)
        XCTAssertEqual(try String(contentsOf: a, encoding: .utf8), "# A changed elsewhere\n")
        _ = try await switchTo(b, answering: "Save")
        _ = try await answerSheet("Overwrite")
        try await waitFor { session.fileURL == b }
        XCTAssertEqual(session.fileURL, b)
        XCTAssertFalse(try String(contentsOf: a, encoding: .utf8).contains("changed elsewhere"))
    }

    @MainActor
    func testStandaloneWindowShowsTheGuidelineChromeWithoutLibraryParts() async throws {
        let folderURL = try makeTemporaryDirectory(named: "paperbranch-standalone-chrome")
        defer { try? FileManager.default.removeItem(at: folderURL) }
        let documentURL = folderURL.appendingPathComponent("Outside.md").standardizedFileURL
        try "# Outside\n\n## Part\n".write(to: documentURL, atomically: true, encoding: .utf8)
        let delegate = AppDelegate()
        try await delegate.openStandaloneDocument(at: documentURL)
        let standalone = try XCTUnwrap(delegate.standaloneWindows[documentURL])
        defer { standalone.window.close() }

        // Ticket 45: the top bar holds the window buttons and the document name. Ticket 49 moved the progress line
        // into the Document view, so the chrome draws none of its own.
        XCTAssertTrue(standalone.window.styleMask.contains(.fullSizeContentView))
        let current = renderedElements(of: standalone.window)
        XCTAssertEqual(accessibilityElement("paperbranch.reader.topbar", in: current)?.value(forKey: "accessibilityLabel") as? String, "Reader top bar for Outside.md")
        XCTAssertNil(accessibilityElement("paperbranch.reader.progress", in: current))
        XCTAssertNotNil(accessibilityElement("paperbranch.reader.document-canvas", in: current))
        // No Library parts.
        for libraryPart in ["paperbranch.reader.toggle-sidebar", "paperbranch.reader.open", "paperbranch.library.sidebar", "paperbranch.library.open-now"] {
            XCTAssertNil(accessibilityElement(libraryPart, in: current), "\(libraryPart) in a Standalone window")
        }

        try await insertExclamationMark(in: standalone.coordinator)
        for _ in 0..<40 where !standalone.session.isDirty { try await Task.sleep(nanoseconds: 50_000_000) }
        XCTAssertTrue(standalone.session.isDirty)
        let edited = renderedElements(of: standalone.window)
        XCTAssertEqual(accessibilityElement("paperbranch.reader.topbar", in: edited)?.value(forKey: "accessibilityLabel") as? String, "Reader top bar for Outside.md, Edited")
    }

    @MainActor
    private func renderedElements(of window: NSWindow) -> [NSObject] {
        guard let root = window.contentView else { return [] }
        root.layoutSubtreeIfNeeded()
        return renderedAccessibilityElements(in: root)
    }

    @MainActor
    func testStandaloneWindowOpensAtDefaultContentSizeOnScreen() async throws {
        let folderURL = try makeTemporaryDirectory(named: "paperbranch-standalone-size")
        defer { try? FileManager.default.removeItem(at: folderURL) }
        let documentURL = folderURL.appendingPathComponent("Outside.md").standardizedFileURL
        try "# Outside\n".write(to: documentURL, atomically: true, encoding: .utf8)
        let delegate = AppDelegate()
        try await delegate.openStandaloneDocument(at: documentURL)
        let window = try XCTUnwrap(delegate.standaloneWindows[documentURL]?.window)
        defer { window.close() }

        XCTAssertEqual(window.contentView?.frame.size, NSSize(width: 800, height: 640))
        XCTAssertTrue(NSScreen.screens.contains { $0.visibleFrame.contains(window.frame) }, "Standalone window frame \(window.frame) is not fully on screen")
    }

    private func buttons(in view: NSView) -> [NSButton] {
        ((view as? NSButton).map { [$0] } ?? []) + view.subviews.flatMap { buttons(in: $0) }
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
    func testLibraryWindowRestoresTheFrameItHadInEitherPresentation() throws {
        UserDefaults.standard.removeObject(forKey: libraryWindowFrameKey)
        defer { UserDefaults.standard.removeObject(forKey: libraryWindowFrameKey) }
        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-window-frame-presentation")
        defer { try? FileManager.default.removeItem(at: libraryURL) }
        let documentURL = libraryURL.appendingPathComponent("Reading.md")
        try "# Reading\n".write(to: documentURL, atomically: true, encoding: .utf8)
        let state = PaperbranchWindowPresentationState(
            library: try LibraryBrowser.choose(libraryURL),
            sidebarState: LibrarySidebarState(),
            selectedDocumentURL: documentURL,
            document: .init(url: documentURL, kind: .library, availability: .available, isDirty: false, conflict: nil)
        )
        let chosenFrame = NSRect(x: 140, y: 110, width: 1180, height: 760)

        // AppKit's frame autosave drops a visible toolbar's height when saving and adds it back when restoring.
        // Variant B hides the toolbar, so a frame saved there grew by the toolbar's height at every launch.
        for showsVariantB in [true, false] {
            let firstLaunch = AppDelegate().makeLibraryWindow()
            let presentation = PaperbranchWindowPresentation(window: firstLaunch, webView: WKWebView())
            if showsVariantB { XCTAssertTrue(presentation.render(state)) }
            firstLaunch.setFrame(chosenFrame, display: false)
            firstLaunch.setFrameAutosaveName("")
            // Toolbars sharing an identifier share visibility in one process. A relaunch starts with it visible.
            firstLaunch.toolbar?.isVisible = true

            let nextLaunch = AppDelegate().makeLibraryWindow()
            defer { nextLaunch.setFrameAutosaveName("") }
            XCTAssertEqual(nextLaunch.frame, chosenFrame, showsVariantB ? "Saved in Variant B" : "Saved in AppKit")
        }
    }

    @MainActor
    func testLongOutlineKeepsTheAppKitLibraryWindowFrameAndTreeVisible() throws {
        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-long-outline")
        defer { try? FileManager.default.removeItem(at: libraryURL) }
        try "# Reading\n".write(to: libraryURL.appendingPathComponent("Reading.md"), atomically: true, encoding: .utf8)
        let sidebar = LibrarySidebarViewController()
        let split = NSSplitViewController()
        split.addSplitViewItem(NSSplitViewItem(sidebarWithViewController: sidebar))
        let detail = NSViewController()
        detail.view = NSView()
        split.addSplitViewItem(NSSplitViewItem(viewController: detail))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1300, height: 800), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.contentViewController = split
        window.setFrame(NSRect(x: 0, y: 0, width: 1300, height: 800), display: false)
        let chosenFrame = window.frame
        sidebar.show(try LibraryBrowser.choose(libraryURL))

        let outline = (0..<60).map { DocumentOutlineEntry(id: "heading-\($0)", text: "Section \($0)", level: $0 % 2 + 1) }
        sidebar.showDocumentNavigation(outline: outline, progress: 0)
        window.contentView?.layoutSubtreeIfNeeded()

        XCTAssertEqual(window.frame, chosenFrame)
        let tree = try XCTUnwrap(descendants(of: sidebar.view).first { $0 is NSOutlineView }?.enclosingScrollView)
        XCTAssertGreaterThanOrEqual(tree.frame.height, 200, "The outline squeezed the Library tree to \(tree.frame.height) points")
        let firstHeading = try XCTUnwrap(descendants(of: sidebar.view).compactMap { $0 as? NSButton }.first { $0.identifier?.rawValue == "heading-0" })
        let sidebarFrame = sidebar.view.convert(sidebar.view.bounds, to: nil)
        XCTAssertLessThan(firstHeading.convert(firstHeading.bounds, to: nil).minX - sidebarFrame.minX, 40, "Outline entries are not left-aligned")
    }

    @MainActor
    func testLibrarySidebarOutlineIsNotRebuiltWhenOnlyTheCurrentHeadingChanges() throws {
        // Ticket 50: scrolling past a heading reports a new current heading, and rebuilding every outline button for it
        // cost 33 ms with 35 headings. The AppKit sidebar does not mark the current heading, so it keeps its buttons.
        let sidebar = LibrarySidebarViewController()
        _ = sidebar.view
        func outline(current: Int) -> [DocumentOutlineEntry] {
            (0..<35).map { DocumentOutlineEntry(id: "heading-\($0)", text: "Section \($0)", level: 2, isCurrent: $0 == current) }
        }
        func buttons() -> [NSButton] { descendants(of: sidebar.view).compactMap { $0 as? NSButton }.filter { $0.identifier?.rawValue.hasPrefix("heading-") == true } }
        sidebar.showDocumentNavigation(outline: outline(current: 0), progress: 0)
        let first = buttons()
        XCTAssertEqual(first.count, 35)

        sidebar.showDocumentNavigation(outline: outline(current: 1), progress: 0.4)
        XCTAssertTrue(zip(first, buttons()).allSatisfy { $0 === $1 }, "A current-heading change rebuilt the outline buttons")
        XCTAssertTrue(descendants(of: sidebar.view).contains { ($0 as? NSTextField)?.stringValue == "Reading progress: 40%" })

        var renamed = outline(current: 1)
        renamed[3] = DocumentOutlineEntry(id: "heading-3", text: "Renamed", level: 2)
        sidebar.showDocumentNavigation(outline: renamed, progress: 0.4)
        XCTAssertEqual(buttons().first { $0.identifier?.rawValue == "heading-3" }?.title, "  Renamed")
    }

    private func descendants(of view: NSView) -> [NSView] {
        view.subviews + view.subviews.flatMap { descendants(of: $0) }
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
        // Ticket 49: the Document view draws the progress line, so the chrome has none to re-render on scroll.
        XCTAssertNil(accessibilityElement("paperbranch.reader.progress", in: elements))
        presentation.selectOutline(id: "heading-1")
        XCTAssertEqual(selectedOutlineID, "heading-1")
    }

    @MainActor
    func testOutlineMovesToARightPanelInWideWindowsAndMarksTheCurrentHeading() throws {
        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-outline-panel")
        defer { try? FileManager.default.removeItem(at: libraryURL) }
        let documentURL = libraryURL.appendingPathComponent("Selected.md")
        try "# Selected\n\n## Details\n".write(to: documentURL, atomically: true, encoding: .utf8)
        let library = try LibraryBrowser.choose(libraryURL)

        // Ticket 42: a right panel at 1240 px and wider, under the Library tree below that.
        for (width, wide) in [(CGFloat(1300), true), (1100, false)] {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 800), styleMask: [.titled], backing: .buffered, defer: false)
            let presentation = PaperbranchWindowPresentation(window: window, webView: WKWebView())
            XCTAssertTrue(presentation.render(.init(
                library: library,
                sidebarState: LibrarySidebarState(),
                selectedDocumentURL: documentURL,
                document: .init(url: documentURL, kind: .library, availability: .available, isDirty: false, conflict: nil),
                outline: [.init(id: "heading-0", text: "Selected", level: 1), .init(id: "heading-1", text: "Details", level: 2, isCurrent: true)]
            )))
            let root = try XCTUnwrap(window.contentView)
            root.layoutSubtreeIfNeeded()
            let elements = renderedAccessibilityElements(in: root)
            let sidebar = try XCTUnwrap(accessibilityElement("paperbranch.library.sidebar", in: elements))
            let inSidebar = accessibilityElement("paperbranch.library.outline.heading-1", in: accessibilityDescendants(of: sidebar))
            let panel = accessibilityElement("paperbranch.reader.outline-panel", in: elements)
            if wide {
                let panel = try XCTUnwrap(panel, "no outline panel at \(width)")
                XCTAssertNil(inSidebar)
                let current = try XCTUnwrap(accessibilityElement("paperbranch.library.outline.heading-1", in: accessibilityDescendants(of: panel)))
                XCTAssertEqual(current.value(forKey: "accessibilityValue") as? String, "Current heading")
                let other = try XCTUnwrap(accessibilityElement("paperbranch.library.outline.heading-0", in: accessibilityDescendants(of: panel)))
                XCTAssertNotEqual(other.value(forKey: "accessibilityValue") as? String, "Current heading")
                // The panel sits on the window's right edge, 220 px wide.
                let rootFrame = accessibilityFrame(of: root)
                XCTAssertEqual(accessibilityFrame(of: panel).maxX, rootFrame.maxX, accuracy: 1)
                XCTAssertEqual(accessibilityFrame(of: panel).width, PBSize.outlineWidth, accuracy: 1)
            } else {
                XCTAssertNil(panel, "outline panel shown at \(width)")
                XCTAssertNotNil(inSidebar)
            }
        }
    }

    @MainActor
    func testLibrarySidebarShowsOpenNowAboveCollapsibleFolders() throws {
        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-window-presentation-open-now")
        defer { try? FileManager.default.removeItem(at: libraryURL) }
        let documentURL = libraryURL.appendingPathComponent("Selected.md")
        try "# Selected\n".write(to: documentURL, atomically: true, encoding: .utf8)
        let folderURL = libraryURL.appendingPathComponent("Folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try "# Nested\n".write(to: folderURL.appendingPathComponent("Nested.md"), atomically: true, encoding: .utf8)
        let library = try LibraryBrowser.choose(libraryURL)
        let folder = try XCTUnwrap(library.root.children.first(where: { $0.kind == .folder }))

        var folderChanges: [(URL, Bool)] = []
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1300, height: 800), styleMask: [.titled], backing: .buffered, defer: false)
        let presentation = PaperbranchWindowPresentation(window: window, webView: WKWebView(), onSetFolderExpanded: { folderChanges.append(($0.url, $1)) })
        let document = PaperbranchDocumentPresentationState(url: documentURL, kind: .library, availability: .available, isDirty: false, conflict: nil)

        XCTAssertTrue(presentation.render(.init(library: library, sidebarState: LibrarySidebarState(), selectedDocumentURL: documentURL, document: document, wordCount: 1240)))
        var root = try XCTUnwrap(window.contentView)
        root.layoutSubtreeIfNeeded()
        var elements = renderedAccessibilityElements(in: root)
        var sidebar = try XCTUnwrap(accessibilityElement("paperbranch.library.sidebar", in: elements))
        var labels = accessibilityDescendants(of: sidebar).compactMap { ($0.value(forKey: "accessibilityLabel") ?? $0.value(forKey: "accessibilityValue")) as? String }
        // The tree is the Library's only navigation, so Variant B's flat items are gone.
        for removed in ["All documents", "Favorites", "Recently opened"] {
            XCTAssertFalse(labels.contains { $0.contains(removed) })
        }
        let openNow = try XCTUnwrap(accessibilityElement("paperbranch.library.open-now", in: elements))
        XCTAssertEqual(openNow.value(forKey: "accessibilityLabel") as? String, "Open now: Selected.md, 1,240 words")
        var folderRow = try XCTUnwrap(accessibilityElement("paperbranch.library.folder", in: elements))
        XCTAssertEqual(folderRow.value(forKey: "accessibilityLabel") as? String, "Folder: Folder, expanded")
        // Accessibility frames use screen coordinates, so a higher row has a larger y.
        XCTAssertGreaterThan(accessibilityFrame(of: openNow).minY, accessibilityFrame(of: folderRow).maxY)
        XCTAssertTrue(labels.contains("Markdown document: Nested.md"))
        _ = folderRow.perform(NSSelectorFromString("accessibilityPerformPress"))
        XCTAssertEqual(folderChanges.map(\.0), [folder.url])
        XCTAssertEqual(folderChanges.map(\.1), [false])

        // A collapsed folder stays in the Variant B sidebar, hiding its documents until it is expanded again.
        var collapsed = LibrarySidebarState()
        collapsed.setExpanded(folder, expanded: false)
        XCTAssertTrue(presentation.render(.init(library: library, sidebarState: collapsed, selectedDocumentURL: documentURL, document: document, wordCount: 1)))
        root = try XCTUnwrap(window.contentView)
        root.layoutSubtreeIfNeeded()
        elements = renderedAccessibilityElements(in: root)
        sidebar = try XCTUnwrap(accessibilityElement("paperbranch.library.sidebar", in: elements))
        labels = accessibilityDescendants(of: sidebar).compactMap { $0.value(forKey: "accessibilityLabel") as? String }
        XCTAssertFalse(labels.contains("Markdown document: Nested.md"))
        XCTAssertEqual(accessibilityElement("paperbranch.library.open-now", in: elements)?.value(forKey: "accessibilityLabel") as? String, "Open now: Selected.md, 1 word")
        folderRow = try XCTUnwrap(accessibilityElement("paperbranch.library.folder", in: elements))
        XCTAssertEqual(folderRow.value(forKey: "accessibilityLabel") as? String, "Folder: Folder, collapsed")
        _ = folderRow.perform(NSSelectorFromString("accessibilityPerformPress"))
        XCTAssertEqual(folderChanges.map(\.1), [false, true])

        // Unsaved edits add a dot and "Edited" to the card (Ticket 41, design skill "Open now card").
        let edited = PaperbranchDocumentPresentationState(url: documentURL, kind: .library, availability: .available, isDirty: true, conflict: nil)
        XCTAssertTrue(presentation.render(.init(library: library, sidebarState: LibrarySidebarState(), selectedDocumentURL: documentURL, document: edited, wordCount: 1240)))
        root = try XCTUnwrap(window.contentView)
        root.layoutSubtreeIfNeeded()
        XCTAssertEqual(accessibilityElement("paperbranch.library.open-now", in: renderedAccessibilityElements(in: root))?.value(forKey: "accessibilityLabel") as? String, "Open now: Selected.md, 1,240 words, Edited")

        // With no selection there is nothing open, so the card is hidden.
        XCTAssertTrue(presentation.render(.init(library: library, sidebarState: LibrarySidebarState(), selectedDocumentURL: nil, document: document, wordCount: 1240)))
        root = try XCTUnwrap(window.contentView)
        root.layoutSubtreeIfNeeded()
        XCTAssertNil(accessibilityElement("paperbranch.library.open-now", in: renderedAccessibilityElements(in: root)))
    }

    @MainActor
    func testLibraryDocumentRowsAreClickableAcrossTheRowLikeFolderRows() throws {
        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-row-hit-area")
        defer { try? FileManager.default.removeItem(at: libraryURL) }
        let documentURL = libraryURL.appendingPathComponent("A.md")
        try "# A\n".write(to: documentURL, atomically: true, encoding: .utf8)
        let folderURL = libraryURL.appendingPathComponent("Folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let nestedURL = folderURL.appendingPathComponent("Nested.md")
        try "# Nested\n".write(to: nestedURL, atomically: true, encoding: .utf8)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1300, height: 800), styleMask: [.titled], backing: .buffered, defer: false)
        let presentation = PaperbranchWindowPresentation(window: window, webView: WKWebView())
        XCTAssertTrue(presentation.render(.init(
            library: try LibraryBrowser.choose(libraryURL),
            sidebarState: LibrarySidebarState(),
            selectedDocumentURL: nestedURL,
            document: .init(url: nestedURL, kind: .library, availability: .available, isDirty: false, conflict: nil)
        )))
        let root = try XCTUnwrap(window.contentView)
        root.layoutSubtreeIfNeeded()
        let elements = renderedAccessibilityElements(in: root)

        // Folder and A.md both sit at the Library's top level, and A.md is not selected, so it draws no background. A plain button only takes clicks on drawn text unless it has a content shape.
        let folder = accessibilityFrame(of: try XCTUnwrap(accessibilityElement("paperbranch.library.folder", in: elements)))
        let document = accessibilityFrame(of: try XCTUnwrap(accessibilityElement("paperbranch.library.document", in: elements)))
        XCTAssertEqual(document.width, folder.width, accuracy: 1)
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
    func testExpandedLibraryWithoutSelectionShowsVariantBSidebarAndEmptyReader() throws {
        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-window-presentation-empty-reader")
        defer { try? FileManager.default.removeItem(at: libraryURL) }
        let documentURL = libraryURL.appendingPathComponent("Reading.md")
        try "# Reading\n".write(to: documentURL, atomically: true, encoding: .utf8)
        let folderURL = libraryURL.appendingPathComponent("Folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try "# Nested\n".write(to: folderURL.appendingPathComponent("Nested.md"), atomically: true, encoding: .utf8)
        let library = try LibraryBrowser.choose(libraryURL)
        let emptyFolderURL = try makeTemporaryDirectory(named: "paperbranch-window-presentation-empty-library")
        defer { try? FileManager.default.removeItem(at: emptyFolderURL) }
        let emptyLibrary = try LibraryBrowser.choose(emptyFolderURL)
        let previousDocumentURL = FileManager.default.temporaryDirectory.appendingPathComponent("Previous.md")

        var selectedDocumentURLs: [URL] = []
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1300, height: 800), styleMask: [.titled], backing: .buffered, defer: false)
        let appKitContent = NSView()
        window.contentView = appKitContent
        let webView = WKWebView()
        let presentation = PaperbranchWindowPresentation(window: window, webView: webView) { selectedDocumentURLs.append($0) }

        // Launch restore with no saved selection has no open document. Choose Library keeps the previous clean document open.
        for openDocumentURL in [nil, previousDocumentURL] {
            XCTAssertTrue(presentation.render(.init(
                library: library,
                sidebarState: LibrarySidebarState(),
                selectedDocumentURL: nil,
                document: .init(url: openDocumentURL, kind: .library, availability: .available, isDirty: false, conflict: nil),
                outline: [DocumentOutlineEntry(id: "heading-0", text: "Previous", level: 1)]
            )))
            let root = try XCTUnwrap(window.contentView)
            XCTAssertFalse(root === appKitContent)
            root.layoutSubtreeIfNeeded()
            let elements = renderedAccessibilityElements(in: root)
            let sidebar = try XCTUnwrap(accessibilityElement("paperbranch.library.sidebar", in: elements))
            let documentLabels = accessibilityDescendants(of: sidebar).compactMap { $0.value(forKey: "accessibilityLabel") as? String }
            XCTAssertTrue(documentLabels.contains("Markdown document: Reading.md"))
            XCTAssertTrue(documentLabels.contains("Markdown document: Nested.md"))
            XCTAssertNil(accessibilityElement("paperbranch.library.selected-document", in: elements))
            XCTAssertNil(accessibilityElement("paperbranch.library.outline.heading-0", in: elements))
            let topBar = try XCTUnwrap(accessibilityElement("paperbranch.reader.topbar", in: elements))
            XCTAssertNotNil(accessibilityElement("paperbranch.reader.toggle-sidebar", in: accessibilityDescendants(of: topBar)))
            let emptyReader = try XCTUnwrap(accessibilityElement("paperbranch.reader.empty", in: elements))
            XCTAssertTrue(accessibilityDescendants(of: emptyReader).contains { $0.value(forKey: "accessibilityValue") as? String == "Choose a document from the Library" })
            XCTAssertNil(accessibilityElement("paperbranch.reader.document-canvas", in: elements))
            XCTAssertNil(accessibilityElement("paperbranch.reader.footer", in: elements))
            XCTAssertFalse(windowContainsView(window, target: webView))
        }

        presentation.selectDocument(at: documentURL)
        XCTAssertEqual(selectedDocumentURLs, [documentURL.standardizedFileURL])

        // A collapsed sidebar keeps the empty reader in Variant B.
        var collapsedSidebar = LibrarySidebarState()
        collapsedSidebar.toggleCollapsed()
        XCTAssertTrue(presentation.render(.init(library: library, sidebarState: collapsedSidebar, selectedDocumentURL: nil, document: .init(url: nil, kind: .library, availability: .available, isDirty: false, conflict: nil))))
        XCTAssertNotNil(accessibilityElement("paperbranch.reader.empty", in: renderedAccessibilityElements(in: try XCTUnwrap(window.contentView))))

        // Ticket 43: an empty Library, a hidden unavailable document, and a missing Library have state views in Variant B.
        for state: PaperbranchWindowPresentationState in [
            .init(library: emptyLibrary, sidebarState: LibrarySidebarState(), selectedDocumentURL: nil, document: .init(url: nil, kind: .library, availability: .available, isDirty: false, conflict: nil)),
            .init(library: library, sidebarState: LibrarySidebarState(), selectedDocumentURL: nil, document: .init(url: previousDocumentURL, kind: .library, availability: .unavailable, isDirty: false, conflict: nil)),
            .init(library: nil, sidebarState: LibrarySidebarState(), selectedDocumentURL: nil, document: .init(url: nil, kind: .library, availability: .available, isDirty: false, conflict: nil)),
        ] {
            XCTAssertTrue(presentation.render(state))
            XCTAssertFalse(window.contentView === appKitContent)
        }

        let excludedStates: [PaperbranchWindowPresentationState] = [
            .init(library: library, sidebarState: LibrarySidebarState(), selectedDocumentURL: nil, document: .init(url: previousDocumentURL, kind: .library, availability: .available, isDirty: true, conflict: nil)),
            .init(library: library, sidebarState: LibrarySidebarState(), selectedDocumentURL: nil, document: .init(url: previousDocumentURL, kind: .library, availability: .available, isDirty: false, conflict: .externalChange(previousDocumentURL))),
            .init(library: library, sidebarState: LibrarySidebarState(), selectedDocumentURL: nil, document: .init(url: nil, kind: .standalone, availability: .available, isDirty: false, conflict: nil)),
            .init(library: library, sidebarState: LibrarySidebarState(), selectedDocumentURL: nil, document: nil),
        ]
        for state in excludedStates {
            XCTAssertTrue(presentation.render(.init(library: library, sidebarState: LibrarySidebarState(), selectedDocumentURL: nil, document: .init(url: nil, kind: .library, availability: .available, isDirty: false, conflict: nil))))
            XCTAssertFalse(presentation.render(state))
            XCTAssertTrue(window.contentView === appKitContent)
        }
    }

    @MainActor
    func testReaderTopBarOpenButtonInvokesInjectedOpenAction() throws {
        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-window-presentation-open")
        defer { try? FileManager.default.removeItem(at: libraryURL) }
        let documentURL = libraryURL.appendingPathComponent("Reading.md")
        try "# Reading\n".write(to: documentURL, atomically: true, encoding: .utf8)

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1300, height: 800), styleMask: [.titled], backing: .buffered, defer: false)
        var openCount = 0
        let presentation = PaperbranchWindowPresentation(window: window, webView: WKWebView(), onOpen: { openCount += 1 })
        let library = try LibraryBrowser.choose(libraryURL)
        let document = PaperbranchDocumentPresentationState(url: documentURL, kind: .library, availability: .available, isDirty: false, conflict: nil)
        let reading = PaperbranchWindowPresentationState(library: library, sidebarState: LibrarySidebarState(), selectedDocumentURL: documentURL, document: document)
        let emptyReader = PaperbranchWindowPresentationState(library: library, sidebarState: LibrarySidebarState(), selectedDocumentURL: nil, document: document)

        for (index, state) in [reading, emptyReader].enumerated() {
            XCTAssertTrue(presentation.render(state))
            let root = try XCTUnwrap(window.contentView)
            root.layoutSubtreeIfNeeded()
            let elements = renderedAccessibilityElements(in: root)
            let topBar = try XCTUnwrap(accessibilityElement("paperbranch.reader.topbar", in: elements))
            let topBarElements = accessibilityDescendants(of: topBar)

            // Variant B's Open button replaces the "Reading" label on the right of the top bar.
            XCTAssertFalse(topBarElements.contains { $0.value(forKey: "accessibilityValue") as? String == "Reading" })
            let openButton = try XCTUnwrap(accessibilityElement("paperbranch.reader.open", in: topBarElements))
            XCTAssertEqual(openButton.value(forKey: "accessibilityLabel") as? String, "Open")
            let toggle = try XCTUnwrap(accessibilityElement("paperbranch.reader.toggle-sidebar", in: topBarElements))
            XCTAssertGreaterThan(accessibilityFrame(of: openButton).minX, accessibilityFrame(of: toggle).maxX)
            if let name = topBarElements.first(where: { $0.value(forKey: "accessibilityValue") as? String == "Reading.md" }) {
                XCTAssertGreaterThan(accessibilityFrame(of: openButton).minX, accessibilityFrame(of: name).maxX)
            }

            // Pressing the rendered button runs the injected Open command and leaves the reader showing for its sheet.
            _ = openButton.perform(NSSelectorFromString("accessibilityPerformPress"))
            XCTAssertEqual(openCount, index + 1)
            XCTAssertTrue(window.contentView === root)
        }
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
        session.navigationStateDidChange = { receivedOutline, receivedProgress, _ in
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

    func testLibraryWorkflowReportsWhetherALibraryWasChosenAndWhichIsUnavailable() throws {
        let store = TestLibraryBookmarkStore()
        let firstLaunch = LibraryWorkflow(bookmarks: LibraryAccess(store: store, codec: TestLibraryBookmarkCodec()))
        XCTAssertEqual(try firstLaunch.restoreLibrary(), .unavailable)
        XCTAssertEqual(firstLaunch.availability, .notChosen)

        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-library-availability")
        defer { try? FileManager.default.removeItem(at: libraryURL) }
        try firstLaunch.chooseLibrary(at: libraryURL)
        XCTAssertEqual(firstLaunch.availability, .available)
        firstLaunch.libraryAccessBecameUnavailable()
        XCTAssertEqual(firstLaunch.availability, .unavailable(name: libraryURL.lastPathComponent))

        try FileManager.default.removeItem(at: libraryURL)
        let nextLaunch = LibraryWorkflow(bookmarks: LibraryAccess(store: store, codec: TestLibraryBookmarkCodec()))
        XCTAssertEqual(try nextLaunch.restoreLibrary(), .unavailable)
        XCTAssertEqual(nextLaunch.availability, .unavailable(name: libraryURL.lastPathComponent))
    }

    @MainActor
    func testLibraryWindowShowsTheDesignedStateViews() throws {
        let libraryURL = try makeTemporaryDirectory(named: "paperbranch-state-views")
        defer { try? FileManager.default.removeItem(at: libraryURL) }
        let documentURL = libraryURL.appendingPathComponent("Selected.md")
        try "# Selected\n".write(to: documentURL, atomically: true, encoding: .utf8)
        let library = try LibraryBrowser.choose(libraryURL)
        var actions: [String] = []
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1300, height: 800), styleMask: [.titled], backing: .buffered, defer: false)
        let presentation = PaperbranchWindowPresentation(
            window: window, webView: WKWebView(),
            onOpen: { actions.append("open") },
            onChooseLibrary: { actions.append("choose") },
            onReconnect: { actions.append("reconnect") }
        )
        let clean = PaperbranchDocumentPresentationState(url: nil, kind: .library, availability: .available, isDirty: false, conflict: nil)
        func render(_ state: PaperbranchWindowPresentationState) throws -> [NSObject] {
            XCTAssertTrue(presentation.render(state))
            let root = try XCTUnwrap(window.contentView)
            root.layoutSubtreeIfNeeded()
            return renderedAccessibilityElements(in: root)
        }
        func labels(_ elements: [NSObject]) -> [String] {
            elements.flatMap { [$0.value(forKey: "accessibilityLabel"), $0.value(forKey: "accessibilityValue")] }.compactMap { $0 as? String }
        }
        func press(_ title: String, in elements: [NSObject]) {
            let button = elements.first { ($0.value(forKey: "accessibilityLabel") as? String) == title }
            XCTAssertNotNil(button, "no \(title) button")
            _ = button?.perform(NSSelectorFromString("accessibilityPerformPress"))
        }

        // Choosing a Library: first launch, inside the real Library window.
        var elements = try render(.init(library: nil, libraryAvailability: .notChosen, sidebarState: LibrarySidebarState(), selectedDocumentURL: nil, document: clean))
        XCTAssertEqual(accessibilityElement("paperbranch.reader.state", in: elements)?.value(forKey: "accessibilityLabel") as? String, "Choose a Library")
        XCTAssertTrue(labels(elements).contains("Pick a folder of Markdown documents. Paperbranch shows its folders in the sidebar and opens it again next time."))
        XCTAssertNil(accessibilityElement("paperbranch.reader.open", in: elements))
        // The state view sits below the top bar instead of covering it.
        let stateFrame = accessibilityFrame(of: try XCTUnwrap(accessibilityElement("paperbranch.reader.state", in: elements)))
        let topBarFrame = accessibilityFrame(of: try XCTUnwrap(accessibilityElement("paperbranch.reader.topbar", in: elements)))
        XCTAssertLessThanOrEqual(stateFrame.maxY, topBarFrame.minY + 1)
        press("Open a Document…", in: elements)
        press("Choose Library…", in: elements)
        XCTAssertEqual(actions, ["open", "choose"])

        // Library unavailable.
        actions = []
        elements = try render(.init(library: nil, libraryAvailability: .unavailable(name: "Essays"), sidebarState: LibrarySidebarState(), selectedDocumentURL: nil, document: clean))
        XCTAssertEqual(accessibilityElement("paperbranch.reader.state", in: elements)?.value(forKey: "accessibilityLabel") as? String, "Library unavailable")
        XCTAssertTrue(labels(elements).contains("Paperbranch can't reach Essays. The folder may have moved, or its drive may be disconnected."))
        XCTAssertTrue(labels(elements).contains("Essays is unavailable."))
        press("Choose Another Library…", in: elements)
        press("Reconnect", in: elements)
        XCTAssertEqual(actions, ["choose", "reconnect"])

        // Document unavailable: the tree stays visible and usable.
        let gone = PaperbranchDocumentPresentationState(url: documentURL, kind: .library, availability: .unavailable, isDirty: false, conflict: nil)
        elements = try render(.init(library: library, sidebarState: LibrarySidebarState(), selectedDocumentURL: documentURL, document: gone))
        XCTAssertEqual(accessibilityElement("paperbranch.reader.state", in: elements)?.value(forKey: "accessibilityLabel") as? String, "Document unavailable")
        XCTAssertTrue(labels(elements).contains("Selected.md may have been moved or deleted. Choose another document from the Library."))
        XCTAssertNotNil(accessibilityElement("paperbranch.library.selected-document", in: elements))
        XCTAssertNil(accessibilityElement("paperbranch.document.view", in: elements))

        // A deleted document leaves the tree at the next refresh, which clears the selection. The open document
        // is still this Library's, so the window keeps saying it is unavailable instead of falling back to no selection.
        let deletedURL = libraryURL.appendingPathComponent("Deleted.md")
        let deleted = PaperbranchDocumentPresentationState(url: deletedURL, kind: .library, availability: .unavailable, isDirty: false, conflict: nil)
        elements = try render(.init(library: library, sidebarState: LibrarySidebarState(), selectedDocumentURL: nil, document: deleted))
        XCTAssertEqual(accessibilityElement("paperbranch.reader.state", in: elements)?.value(forKey: "accessibilityLabel") as? String, "Document unavailable")
        XCTAssertTrue(labels(elements).contains("Deleted.md may have been moved or deleted. Choose another document from the Library."))

        // Unsaved work behind a missing Library stays visible in AppKit.
        let dirty = PaperbranchDocumentPresentationState(url: documentURL, kind: .library, availability: .available, isDirty: true, conflict: nil)
        XCTAssertFalse(presentation.render(.init(library: nil, libraryAvailability: .unavailable(name: "Essays"), sidebarState: LibrarySidebarState(), selectedDocumentURL: documentURL, document: dirty)))
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
    func testDocumentMetaLineFollowsAnExternalReload() async throws {
        let directory = try makeTemporaryDirectory(named: "paperbranch-document-meta")
        defer { try? FileManager.default.removeItem(at: directory) }
        let documentURL = directory.appendingPathComponent("observed.md")
        try "# Original\n".write(to: documentURL, atomically: true, encoding: .utf8)

        let coordinator = makeCoordinator()
        try await waitForHarnessReady(coordinator)
        let session = DocumentSession(coordinator: coordinator)
        try await session.open(documentURL)
        let metaLine = "Array.from(document.querySelectorAll('#document-meta span'), (item) => item.textContent).join(' · ')"
        let opened = try await coordinator.webView.evaluateJavaScript(metaLine) as? String
        XCTAssertEqual(opened, "1 word · 1 min read")

        try "# Changed outside Paperbranch\n".write(to: documentURL, atomically: false, encoding: .utf8)

        let reloaded = try await pollMarkdown(in: coordinator, containing: "Changed outside Paperbranch")
        XCTAssertTrue(reloaded)
        let afterReload = try await coordinator.webView.evaluateJavaScript(metaLine) as? String
        XCTAssertEqual(afterReload, "3 words · 1 min read")
    }

    @MainActor
    func testNavigationWordCountMatchesTheMetaLineThroughEditSaveAndExternalReload() async throws {
        let directory = try makeTemporaryDirectory(named: "paperbranch-navigation-word-count")
        defer { try? FileManager.default.removeItem(at: directory) }
        let documentURL = directory.appendingPathComponent("counted.md")
        try "# Original\n".write(to: documentURL, atomically: true, encoding: .utf8)

        let coordinator = makeCoordinator()
        try await waitForHarnessReady(coordinator)
        let session = DocumentSession(coordinator: coordinator)
        var wordCount: Int?
        session.navigationStateDidChange = { _, _, words in wordCount = words }
        try await session.open(documentURL)
        let metaWordCount = "Number(document.querySelector('#document-meta span').textContent.split(' ')[0])"
        func assertWordCountMatchesMetaLine(_ expected: Int, file: StaticString = #filePath, line: UInt = #line) async throws {
            let meta = try await coordinator.webView.evaluateJavaScript(metaWordCount) as? Int
            XCTAssertEqual(meta, expected, file: file, line: line)
            XCTAssertEqual(wordCount, expected, file: file, line: line)
        }
        try await assertWordCountMatchesMetaLine(1)

        _ = try await coordinator.webView.callAsyncJavaScript(
            """
            const root = document.querySelector('#editor-root .ProseMirror');
            const heading = root.querySelector('h1');
            root.focus();
            const range = document.createRange();
            range.selectNodeContents(heading);
            range.collapse(false);
            window.getSelection().removeAllRanges();
            window.getSelection().addRange(range);
            document.execCommand('insertText', false, ' and more');
            return true;
            """,
            contentWorld: .page
        )
        let edited = try await pollIsDirty(coordinator, expecting: true)
        XCTAssertTrue(edited)
        try await assertWordCountMatchesMetaLine(3)
        try await session.save()
        try await assertWordCountMatchesMetaLine(3)

        // An atomic replacement, because the save moved the file to a new inode that an in-place write would not signal.
        try "# Changed outside of Paperbranch today\n".write(to: documentURL, atomically: true, encoding: .utf8)
        let reloaded = try await pollMarkdown(in: coordinator, containing: "Changed outside")
        XCTAssertTrue(reloaded)
        try await assertWordCountMatchesMetaLine(5)
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
    func testSavingDirtyDocumentReportsNoConflictButLaterExternalChangeDoes() async throws {
        let directory = try makeTemporaryDirectory(named: "paperbranch-save-no-conflict")
        defer { try? FileManager.default.removeItem(at: directory) }
        let documentURL = directory.appendingPathComponent("saved.md")
        try "# Original\n".write(to: documentURL, atomically: true, encoding: .utf8)

        let coordinator = makeCoordinator()
        try await waitForHarnessReady(coordinator)
        let session = DocumentSession(coordinator: coordinator)
        var reportedConflicts: [DocumentConflict?] = []
        session.conflictDidChange = { reportedConflicts.append($0) }
        try await session.open(documentURL)
        try await insertExclamationMark(in: coordinator)
        let becameDirty = try await pollIsDirty(coordinator, expecting: true)
        XCTAssertTrue(becameDirty)

        // The file monitor sees Paperbranch's own write. Any conflict reported here shows the alert.
        try await session.save()
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(reportedConflicts, [], "Saving reported a conflict for Paperbranch's own write")
        XCTAssertFalse(session.isDirty)

        try await insertExclamationMark(in: coordinator)
        let becameDirtyAgain = try await pollIsDirty(coordinator, expecting: true)
        XCTAssertTrue(becameDirtyAgain)
        // An atomic replacement. The save moved the file to a new inode, and an in-place write is not seen yet.
        try "# Changed outside Paperbranch\n".write(to: documentURL, atomically: true, encoding: .utf8)
        let becameConflicted = await pollConflict(of: session, expecting: .externalChange(documentURL))
        XCTAssertTrue(becameConflicted)
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
    func testSaveAfterKeepingASingleConflictAsksBeforeOverwriting() async throws {
        let directory = try makeTemporaryDirectory(named: "paperbranch-kept-conflict")
        defer { try? FileManager.default.removeItem(at: directory) }
        let documentURL = directory.appendingPathComponent("kept.md")
        try "# Original\n".write(to: documentURL, atomically: true, encoding: .utf8)

        let coordinator = makeCoordinator()
        try await waitForHarnessReady(coordinator)
        let session = DocumentSession(coordinator: coordinator)
        try await session.open(documentURL)
        try await insertExclamationMark(in: coordinator)
        let becameDirty = try await pollIsDirty(coordinator, expecting: true)
        XCTAssertTrue(becameDirty)
        let keptContent = try await coordinator.requestSave()
        let diskContent = "# Changed elsewhere\n"
        try diskContent.write(to: documentURL, atomically: true, encoding: .utf8)
        let becameConflicted = await pollConflict(of: session, expecting: .externalChange(documentURL))
        XCTAssertTrue(becameConflicted)
        session.keepEditing()

        // User story 28 (Edison, 2026-10-22): keeping edits never authorizes a silent overwrite, even with no second change.
        await XCTAssertThrowsErrorAsync { try await session.save() }
        XCTAssertEqual(try String(contentsOf: documentURL, encoding: .utf8), diskContent)
        XCTAssertTrue(session.isDirty)

        try await session.save(overwritingExternalChanges: true)
        XCTAssertEqual(try String(contentsOf: documentURL, encoding: .utf8), keptContent)
        XCTAssertFalse(session.isDirty)
        XCTAssertNil(session.conflict)
        // The overwrite settles the conflict, so the next save writes without asking.
        try await session.save()
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
    // Some web content nodes inside a loaded Document view do not answer this key, and the exception it raised
    // aborted async tests inside XCTest's error handling ("freed pointer was not the last allocation").
    guard element.responds(to: NSSelectorFromString("accessibilityChildren")) else { return [] }
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
private let libraryWindowFrameKey = AppDelegate.libraryWindowFrameKey

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

    func libraryName(fromBookmark data: Data) -> String? {
        String(data: data, encoding: .utf8).map { URL(fileURLWithPath: $0).lastPathComponent }
    }
}

private struct UnavailableLibraryBookmarkCodec: LibraryBookmarkCodec {
    func makeBookmark(for url: URL) throws -> Data { Data() }
    func resolveBookmark(_ data: Data) throws -> URL { throw LibraryAccessError.unavailable }
}
