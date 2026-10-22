import AppKit
import SwiftUI

// The Swift mirror of the design skill's tokens.css (.claude/skills/paperbranch-design/components.md, "Theme").
// Names and values match the CSS. A token changes in tokens.css and here, nowhere else;
// PaperbranchThemeTests fails when the two disagree.

extension NSColor {
    /// Builds a color from a "#RRGGBB" string copied from tokens.css.
    public convenience init(pbHex hex: String) {
        let value = UInt32(hex.dropFirst(), radix: 16) ?? 0
        self.init(srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
                  green: CGFloat((value >> 8) & 0xFF) / 255,
                  blue: CGFloat(value & 0xFF) / 255,
                  alpha: 1)
    }
}

extension Color {
    /// A color that follows the window's appearance, like light-dark() in tokens.css.
    public init(light: String, dark: String) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(pbHex: dark)
                : NSColor(pbHex: light)
        })
    }
}

public enum PBColor {
    public static let paper = Color(light: "#FFFFFF", dark: "#1C1C1E")
    public static let sidebar = Color(light: "#F7F7F8", dark: "#161618")
    public static let surface = Color(light: "#FFFFFF", dark: "#26262A")
    public static let rowHover = Color(light: "#EFEFF1", dark: "#222225")
    public static let rowSelected = Color(light: "#E7E7EA", dark: "#2C2C30")
    public static let rule = Color(light: "#EBEBEE", dark: "#2E2E33")
    public static let border = Color(light: "#DDDDE1", dark: "#3A3A40")
    public static let ink = Color(light: "#1D1D1F", dark: "#E6E6E8")
    public static let inkStrong = Color(light: "#111113", dark: "#FAFAFA")
    public static let inkMuted = Color(light: "#5E5E64", dark: "#9C9CA3")
    public static let inkIcon = Color(light: "#808087", dark: "#7C7C84")
    public static let inkOnStrong = Color(light: "#FFFFFF", dark: "#161618")
    public static let accent = Color(light: "#2563EB", dark: "#5B8DEF")
    public static let markBg = Color(light: "#2563EB", dark: "#5B8DEF")
    public static let markInk = Color(light: "#FFFFFF", dark: "#0F1115")
    public static let danger = Color(light: "#C4291C", dark: "#FF7B6E")
    public static let dangerInk = Color(light: "#FFFFFF", dark: "#161618")

    /// Each color under its tokens.css name, for the parity test.
    static let tokens: [(String, Color)] = [
        ("--paper", paper), ("--sidebar", sidebar), ("--surface", surface), ("--row-hover", rowHover),
        ("--row-selected", rowSelected), ("--rule", rule), ("--border", border), ("--ink", ink),
        ("--ink-strong", inkStrong), ("--ink-muted", inkMuted), ("--ink-icon", inkIcon), ("--ink-on-strong", inkOnStrong),
        ("--accent", accent), ("--mark-bg", markBg), ("--mark-ink", markInk), ("--danger", danger), ("--danger-ink", dangerInk),
    ]
}

public enum PBSize {
    public static let textLabel: CGFloat = 11
    public static let textCaption: CGFloat = 12
    public static let textUI: CGFloat = 13
    public static let textUILarge: CGFloat = 15
    public static let trackingLabel: CGFloat = 0.66   // 0.06em at 11 px
    public static let space1: CGFloat = 4
    public static let space2: CGFloat = 8
    public static let space3: CGFloat = 12
    public static let space4: CGFloat = 16
    public static let space5: CGFloat = 24
    public static let space6: CGFloat = 32
    public static let space7: CGFloat = 48
    public static let space8: CGFloat = 72
    public static let measure: CGFloat = 680
    public static let sidebarWidth: CGFloat = 260
    public static let outlineWidth: CGFloat = 220
    public static let topbarHeight: CGFloat = 52
    public static let rowHeight: CGFloat = 28
    public static let indent: CGFloat = 16
    public static let outlineMinWindow: CGFloat = 1240
    public static let radiusS: CGFloat = 4
    public static let radiusM: CGFloat = 6
    public static let radiusL: CGFloat = 10
}

public enum PBMotion {
    public static let fast = 0.12     // hover and selection fills
    public static let medium = 0.2    // sidebar slide, folder chevron
}
