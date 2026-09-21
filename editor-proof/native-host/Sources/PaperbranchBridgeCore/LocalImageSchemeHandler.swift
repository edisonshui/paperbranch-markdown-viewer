import Foundation
import UniformTypeIdentifiers
import WebKit

/// Serves image bytes only through `LocalImageResolver`. The URL token is an
/// opaque Markdown reference, not a path that WebKit may open directly.
final class LocalImageSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "paperbranch-image"

    private let lock = NSLock()
    private var resolver: LocalImageResolver?

    func authorizeImages(for documentURL: URL?) {
        lock.lock()
        defer { lock.unlock() }
        resolver = documentURL.flatMap { try? LocalImageResolver(documentURL: $0) }
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let reference = Self.reference(from: urlSchemeTask.request.url),
              let resolver = authorizedResolver(),
              let data = try? resolver.data(for: reference)
        else {
            urlSchemeTask.didFailWithError(LocalImageResolverError.unavailableImage)
            return
        }

        let extensionType = UTType(filenameExtension: URL(fileURLWithPath: reference).pathExtension)
        let response = URLResponse(
            url: urlSchemeTask.request.url!,
            mimeType: extensionType?.preferredMIMEType ?? "application/octet-stream",
            expectedContentLength: data.count,
            textEncodingName: nil
        )
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private func authorizedResolver() -> LocalImageResolver? {
        lock.lock()
        defer { lock.unlock() }
        return resolver
    }

    private static func reference(from url: URL?) -> String? {
        guard let token = url?.lastPathComponent,
              !token.isEmpty
        else { return nil }
        var base64 = token.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
