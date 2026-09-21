import AppKit
import PaperbranchBridgeCore
import WebKit

/// Keeps unavailable documents from presenting their last rendered content as
/// though it were still the file at the session's original path.
@MainActor
final class DocumentPresentationViewController: NSViewController {
    private let webView: WKWebView
    private let unavailableView = NSVisualEffectView()

    init(webView: WKWebView) {
        self.webView = webView
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        let root = NSView()
        webView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(webView)

        unavailableView.material = .contentBackground
        unavailableView.blendingMode = .withinWindow
        unavailableView.state = .active
        unavailableView.translatesAutoresizingMaskIntoConstraints = false
        let label = NSTextField(wrappingLabelWithString: "This document is unavailable. It may have been moved or deleted.")
        label.alignment = .center
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        unavailableView.addSubview(label)
        root.addSubview(unavailableView)

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: root.leadingAnchor), webView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            webView.topAnchor.constraint(equalTo: root.topAnchor), webView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            unavailableView.leadingAnchor.constraint(equalTo: root.leadingAnchor), unavailableView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            unavailableView.topAnchor.constraint(equalTo: root.topAnchor), unavailableView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            label.centerXAnchor.constraint(equalTo: unavailableView.centerXAnchor), label.centerYAnchor.constraint(equalTo: unavailableView.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: unavailableView.leadingAnchor, constant: 32),
            label.trailingAnchor.constraint(lessThanOrEqualTo: unavailableView.trailingAnchor, constant: -32),
        ])
        unavailableView.isHidden = true
        view = root
    }

    func show(availability: DocumentAvailability) {
        unavailableView.isHidden = availability == .available
    }
}
