import WebKit

/// The narrow JS -> native message the bridge accepts. This is the whole
/// surface the editor can push to native: a boolean dirty flag, never
/// document content, a file path, or anything resembling file access. See
/// docs/specs/paperbranch-implementation.md ("Native and editor boundary").
public enum BridgeError: Error {
    case unexpectedResult
    case bridgeNotReady
}

public struct DocumentOutlineEntry: Equatable {
    public let id: String
    public let text: String
    public let level: Int
}

@MainActor
public protocol BridgeCoordinatorDelegate: AnyObject {
    func bridgeCoordinatorDidFinishLoadingHarness(_ coordinator: BridgeCoordinator)
    func bridgeCoordinator(_ coordinator: BridgeCoordinator, dirtyStateChanged dirty: Bool)
    func bridgeCoordinator(_ coordinator: BridgeCoordinator, navigationStateChanged outline: [DocumentOutlineEntry], progress: Double)
}

/// Owns the one `WKWebView` this proof host displays and the fixed message
/// surface between it and native code:
///
/// - JS -> native: a single message handler, `"paperbranch"`, which only
///   ever carries `{ type: "dirtyStateChanged", dirty: Bool }`.
/// - native -> JS: fixed calls into `window.paperbranchNativeBridge` to load
///   document content, request serialized Markdown, record a completed save,
///   and replace clean external content.
///
/// Nothing here exposes a file path or a read/write primitive to
/// JavaScript; the native layer decides what markdown to send and what (if
/// anything) to do with what comes back.
///
/// Known limitation, acceptable for this short-lived proof process:
/// `WKUserContentController.add(_:name:)` retains its handler strongly, so
/// a `BridgeCoordinator` and its `WKWebView` are never released once
/// registered. A long-lived host managing many open/closed documents would
/// need to call `removeScriptMessageHandler(forName:)` when a document
/// session ends; this proof does not build document session lifecycle, so
/// it does not need that cleanup either.
@MainActor
public final class BridgeCoordinator: NSObject {
    public static let messageHandlerName = "paperbranch"

    public weak var delegate: BridgeCoordinatorDelegate?
    public let webView: WKWebView
    public private(set) var isDirty = false
    private let localImageSchemeHandler: LocalImageSchemeHandler

    public init(configuration: WKWebViewConfiguration? = nil) {
        let configuration = configuration ?? WKWebViewConfiguration()
        localImageSchemeHandler = LocalImageSchemeHandler()
        configuration.setURLSchemeHandler(localImageSchemeHandler, forURLScheme: LocalImageSchemeHandler.scheme)
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        configuration.userContentController.add(self, name: Self.messageHandlerName)
        webView.navigationDelegate = self
    }

    public func load(url: URL) {
        webView.load(URLRequest(url: url))
    }

    /// Native code authorizes image data for the currently open document.
    /// JavaScript never receives this URL or a file-reading capability.
    public func authorizeImages(for documentURL: URL?) {
        localImageSchemeHandler.authorizeImages(for: documentURL)
    }

    /// Sends document content across the deliberately small native/editor
    /// boundary. JavaScript receives content, never a path or file handle.
    public func loadDocument(markdown: String) async throws {
        _ = try await webView.callAsyncJavaScript(
            "return await window.paperbranchNativeBridge.loadDocument(markdown);",
            arguments: ["markdown": markdown],
            contentWorld: .page
        )
    }

    /// Native -> JS: requests the currently serialized Markdown. Never
    /// writes a file itself -- the caller (the Command-S handler, or a
    /// test) decides what to do with the returned string.
    @discardableResult
    public func requestSave() async throws -> String {
        let result = try await webView.evaluateJavaScript(
            "window.paperbranchNativeBridge.requestSave()"
        )
        guard let markdown = result as? String else { throw BridgeError.unexpectedResult }
        return markdown
    }

    /// Native -> JS: simulates an external-content change. Returns whether
    /// the editor applied it (the document was clean) or preserved the
    /// in-memory edit (the document was dirty).
    ///
    /// `externalReplace` is async on the JS side (it runs the document
    /// through the same admission seam as a normal load), so it returns a
    /// Promise. Plain `evaluateJavaScript` does not await a returned
    /// Promise -- it fails with "unsupported type" trying to serialize it
    /// back to Swift -- so this uses `callAsyncJavaScript`, which runs the
    /// script body as an async function and awaits its result.
    @discardableResult
    public func externalReplace(markdown: String) async throws -> Bool {
        let result = try await webView.callAsyncJavaScript(
            "return await window.paperbranchNativeBridge.externalReplace(markdown);",
            arguments: ["markdown": markdown],
            contentWorld: .page
        )
        guard let dict = result as? [String: Any], let applied = dict["applied"] as? Bool else {
            throw BridgeError.unexpectedResult
        }
        return applied
    }

    /// A native write is the source of truth. Only after it has completed do
    /// we let the editor replace its dirty baseline.
    public func saveSucceeded(markdown: String) async throws {
        _ = try await webView.callAsyncJavaScript(
            "window.paperbranchNativeBridge.saveSucceeded(markdown); return true;",
            arguments: ["markdown": markdown],
            contentWorld: .page
        )
    }

    public func selectOutline(id: String) async throws -> Bool {
        let result = try await webView.callAsyncJavaScript(
            "return window.paperbranchNativeBridge.selectOutline(id);",
            arguments: ["id": id], contentWorld: .page
        )
        guard let selected = result as? Bool else { throw BridgeError.unexpectedResult }
        return selected
    }

    public func waitForNativeBridge() async throws {
        for _ in 0..<50 {
            let ready =
                (try? await webView.evaluateJavaScript(
                    "typeof window.paperbranchNativeBridge !== 'undefined'"
                )) as? Bool ?? false
            if ready { return }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        throw BridgeError.bridgeNotReady
    }
}

extension BridgeCoordinator: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        delegate?.bridgeCoordinatorDidFinishLoadingHarness(self)
    }
}

extension BridgeCoordinator: WKScriptMessageHandler {
    public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == Self.messageHandlerName,
            let body = message.body as? [String: Any],
            let type = body["type"] as? String
        else { return }

        switch type {
        case "dirtyStateChanged":
            let dirty = (body["dirty"] as? Bool) ?? false
            isDirty = dirty
            delegate?.bridgeCoordinator(self, dirtyStateChanged: dirty)
        case "navigationStateChanged":
            let outline = (body["outline"] as? [[String: Any]] ?? []).compactMap { entry -> DocumentOutlineEntry? in
                guard let id = entry["id"] as? String, let text = entry["text"] as? String, let level = entry["level"] as? Int else { return nil }
                return DocumentOutlineEntry(id: id, text: text, level: level)
            }
            let progress = (body["progress"] as? NSNumber)?.doubleValue ?? 0
            delegate?.bridgeCoordinator(self, navigationStateChanged: outline, progress: max(0, min(1, progress)))
        default:
            break
        }
    }
}
