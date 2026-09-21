import WebKit
import XCTest

@testable import PaperbranchBridgeCore

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
        XCTAssertEqual(surface, ["externalReplace", "loadDocument", "requestSave", "saveSucceeded"])

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
