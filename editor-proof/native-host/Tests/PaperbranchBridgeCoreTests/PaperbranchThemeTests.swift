import AppKit
import SwiftUI
import XCTest

@testable import PaperbranchBridgeCore

/// Ticket 39: the Swift mirror must match tokens.css, the single source, in both appearances.
final class PaperbranchThemeTests: XCTestCase {
    private var tokensURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".claude/skills/paperbranch-design/tokens.css")
    }

    /// "--paper" -> ("#FFFFFF", "#1C1C1E") for every light-dark() hex pair in tokens.css.
    private func cssColors() throws -> [String: (light: String, dark: String)] {
        let css = try String(contentsOf: tokensURL, encoding: .utf8)
        let pattern = try NSRegularExpression(pattern: #"(--[a-z-]+):\s*light-dark\((#[0-9A-Fa-f]{6}),\s*(#[0-9A-Fa-f]{6})\)"#)
        var colors: [String: (String, String)] = [:]
        for match in pattern.matches(in: css, range: NSRange(css.startIndex..., in: css)) {
            let part = { (i: Int) in String(css[Range(match.range(at: i), in: css)!]) }
            colors[part(1)] = (part(2), part(3))
        }
        return colors
    }

    private func hex(_ color: Color, in appearanceName: NSAppearance.Name) -> String {
        var result = ""
        NSAppearance(named: appearanceName)!.performAsCurrentDrawingAppearance {
            let resolved = NSColor(color).usingColorSpace(.sRGB)!
            result = String(format: "#%02X%02X%02X", Int((resolved.redComponent * 255).rounded()), Int((resolved.greenComponent * 255).rounded()), Int((resolved.blueComponent * 255).rounded()))
        }
        return result
    }

    @MainActor
    func testSwiftColorsMatchTokensCSSInBothAppearances() throws {
        let css = try cssColors()
        XCTAssertGreaterThan(css.count, 15, "tokens.css was not read from \(tokensURL.path)")
        XCTAssertFalse(PBColor.tokens.isEmpty)
        for (name, color) in PBColor.tokens {
            let expected = try XCTUnwrap(css[name], "\(name) is not in tokens.css")
            XCTAssertEqual(hex(color, in: .aqua), expected.light.uppercased(), "\(name) light")
            XCTAssertEqual(hex(color, in: .darkAqua), expected.dark.uppercased(), "\(name) dark")
        }
    }

    func testSwiftSizesMatchTokensCSS() throws {
        let css = try String(contentsOf: tokensURL, encoding: .utf8)
        for (name, value) in [("--measure", PBSize.measure), ("--sidebar-width", PBSize.sidebarWidth), ("--outline-width", PBSize.outlineWidth), ("--topbar-height", PBSize.topbarHeight), ("--row-height", PBSize.rowHeight), ("--outline-min-window", PBSize.outlineMinWindow), ("--radius-l", PBSize.radiusL), ("--text-ui", PBSize.textUI)] {
            XCTAssertTrue(css.contains("\(name): \(Int(value))px"), "\(name) is not \(Int(value))px in tokens.css")
        }
    }
}
