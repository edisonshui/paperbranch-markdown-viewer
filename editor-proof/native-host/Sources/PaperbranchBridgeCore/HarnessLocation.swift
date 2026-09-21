import Foundation

/// Where the formatted Document view is loaded from. Tests may explicitly
/// select a Vite URL. A packaged app uses its bundled, offline harness.
public enum HarnessLocation {
    public static let offlineScheme = "paperbranch-editor"

    public static var url: URL {
        if let override = ProcessInfo.processInfo.environment["PAPERBRANCH_PROOF_HARNESS_URL"],
            let url = URL(string: override)
        {
            return url
        }
        return URL(string: "\(offlineScheme)://document/index.html")!
    }

    public static var offlineResourceRoot: URL {
        if let appPath = ProcessInfo.processInfo.environment["PAPERBRANCH_PACKAGED_APP_PATH"] {
            return URL(fileURLWithPath: appPath).appendingPathComponent("Contents/Resources/Web", isDirectory: true)
        }
        guard let root = Bundle.main.resourceURL?.appendingPathComponent("Web", isDirectory: true) else {
            preconditionFailure("Paperbranch's bundled Document view is missing.")
        }
        return root
    }
}
