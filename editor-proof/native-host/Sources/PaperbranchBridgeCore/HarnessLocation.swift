import Foundation

/// Where the editor-proof harness (the Vite dev server serving
/// `editor-proof/index.html`) is being served. Defaults to the same
/// `localhost:5183` the Playwright suite already uses
/// (`editor-proof/playwright.config.ts`), so `run.sh` / `test.sh` can start
/// one dev server and have both the browser proof and this native host
/// point at it. Overridable via `PAPERBRANCH_PROOF_HARNESS_URL` for a
/// different port.
public enum HarnessLocation {
    public static var url: URL {
        if let override = ProcessInfo.processInfo.environment["PAPERBRANCH_PROOF_HARNESS_URL"],
            let url = URL(string: override)
        {
            return url
        }
        return URL(string: "http://localhost:5183/")!
    }
}
