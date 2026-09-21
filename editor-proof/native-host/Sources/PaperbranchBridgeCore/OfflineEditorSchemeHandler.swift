import Foundation
import WebKit

/// Serves only the compiled editor bundled in Paperbranch. It has no path or
/// file-system API exposed to JavaScript, and never escapes `Web/`.
final class OfflineEditorSchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else { return finish(urlSchemeTask, status: 400) }
        let root = HarnessLocation.offlineResourceRoot.standardizedFileURL
        let relativePath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let candidate = root.appendingPathComponent(relativePath.isEmpty ? "index.html" : relativePath).standardizedFileURL
        guard candidate.path == root.path || candidate.path.hasPrefix(root.path + "/"),
              let data = try? Data(contentsOf: candidate)
        else { return finish(urlSchemeTask, status: 404) }

        let response = URLResponse(url: url, mimeType: mimeType(for: candidate), expectedContentLength: data.count, textEncodingName: nil)
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private func finish(_ task: WKURLSchemeTask, status: Int) {
        task.didFailWithError(NSError(domain: "Paperbranch.OfflineEditor", code: status))
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "html": "text/html"
        case "js": "text/javascript"
        case "css": "text/css"
        case "svg": "image/svg+xml"
        case "png": "image/png"
        case "jpg", "jpeg": "image/jpeg"
        default: "application/octet-stream"
        }
    }
}
