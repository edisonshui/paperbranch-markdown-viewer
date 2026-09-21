import WebKit

/// The narrow JS -> native message the bridge accepts. This is the whole
/// surface the editor can push to native: a boolean dirty flag, never
/// document content, a file path, or anything resembling file access. See
/// docs/specs/paperbranch-implementation.md ("Native and editor boundary").
public enum BridgeError: Error {
    case unexpectedResult
}

@MainActor
public protocol BridgeCoordinatorDelegate: AnyObject {
    func bridgeCoordinatorDidFinishLoadingHarness(_ coordinator: BridgeCoordinator)
    func bridgeCoordinator(_ coordinator: BridgeCoordinator, dirtyStateChanged dirty: Bool)
}

/// Owns the one `WKWebView` this proof host displays and the fixed message
/// surface between it and native code:
///
/// - JS -> native: a single message handler, `"paperbranch"`, which only
///   ever carries `{ type: "dirtyStateChanged", dirty: Bool }`.
/// - native -> JS: two calls into `window.paperbranchNativeBridge`,
///   `requestSave()` (returns serialized Markdown, writes nothing) and
///   `externalReplace(markdown)` (returns whether it was applied).
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

    public init(configuration: WKWebViewConfiguration? = nil) {
        let configuration = configuration ?? WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        configuration.userContentController.add(self, name: Self.messageHandlerName)
        webView.navigationDelegate = self
    }

    public func load(url: URL) {
        webView.load(URLRequest(url: url))
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
        default:
            break
        }
    }
}
