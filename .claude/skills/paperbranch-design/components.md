# Paperbranch components

Each UI part as code in the app's real stack. The chrome is SwiftUI inside AppKit windows (ADR 0005), and the Document view is HTML and CSS in WebKit. Every Swift snippet typechecks together against macOS 13, and every CSS snippet renders against `tokens.css`. Copy a part whole, then change only its content.

## Theme

The Swift mirror of `tokens.css`. Keep the names and values identical to the CSS. A token changes in `tokens.css` and here, nowhere else.

```swift
import AppKit
import SwiftUI

extension NSColor {
    /// Builds a color from a "#RRGGBB" string copied from tokens.css.
    convenience init(pbHex hex: String) {
        let value = UInt32(hex.dropFirst(), radix: 16) ?? 0
        self.init(srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
                  green: CGFloat((value >> 8) & 0xFF) / 255,
                  blue: CGFloat(value & 0xFF) / 255,
                  alpha: 1)
    }
}

extension Color {
    /// A color that follows the window's appearance, like light-dark() in tokens.css.
    init(light: String, dark: String) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(pbHex: dark)
                : NSColor(pbHex: light)
        })
    }
}

enum PBColor {
    static let paper = Color(light: "#FFFFFF", dark: "#1C1C1E")
    static let sidebar = Color(light: "#F7F7F8", dark: "#161618")
    static let surface = Color(light: "#FFFFFF", dark: "#26262A")
    static let rowHover = Color(light: "#EFEFF1", dark: "#222225")
    static let rowSelected = Color(light: "#E7E7EA", dark: "#2C2C30")
    static let rule = Color(light: "#EBEBEE", dark: "#2E2E33")
    static let border = Color(light: "#DDDDE1", dark: "#3A3A40")
    static let ink = Color(light: "#1D1D1F", dark: "#E6E6E8")
    static let inkStrong = Color(light: "#111113", dark: "#FAFAFA")
    static let inkMuted = Color(light: "#5E5E64", dark: "#9C9CA3")
    static let inkIcon = Color(light: "#808087", dark: "#7C7C84")
    static let inkOnStrong = Color(light: "#FFFFFF", dark: "#161618")
    static let accent = Color(light: "#2563EB", dark: "#5B8DEF")
    static let danger = Color(light: "#C4291C", dark: "#FF7B6E")
    static let dangerInk = Color(light: "#FFFFFF", dark: "#161618")
}

enum PBSize {
    static let textLabel: CGFloat = 11
    static let textCaption: CGFloat = 12
    static let textUI: CGFloat = 13
    static let textUILarge: CGFloat = 15
    static let trackingLabel: CGFloat = 0.66   // 0.06em at 11 px
    static let space1: CGFloat = 4
    static let space2: CGFloat = 8
    static let space3: CGFloat = 12
    static let space4: CGFloat = 16
    static let space5: CGFloat = 24
    static let space6: CGFloat = 32
    static let space7: CGFloat = 48
    static let space8: CGFloat = 72
    static let measure: CGFloat = 680
    static let sidebarWidth: CGFloat = 260
    static let outlineWidth: CGFloat = 220
    static let topbarHeight: CGFloat = 52
    static let rowHeight: CGFloat = 28
    static let indent: CGFloat = 16
    static let outlineMinWindow: CGFloat = 1240
    static let radiusS: CGFloat = 4
    static let radiusM: CGFloat = 6
    static let radiusL: CGFloat = 10
}

enum PBMotion {
    static let fast = 0.12     // hover and selection fills
    static let medium = 0.2    // sidebar slide, folder chevron
}
```

## Wordmark

The wordmark is a fixed logo lockup at the top of the Library sidebar, so its sizes belong to the logo, not to the scale. The logo is the app icon itself, so the sidebar and the Dock always match.

```swift
struct PBWordmark: View {
    var body: some View {
        HStack(spacing: 9) {
            // The icon's tile fills 824/1024 of its image, so a 31-point image gives a 25-point tile.
            Image(nsImage: NSApplication.shared.applicationIconImage ?? NSImage())
                .resizable()
                .interpolation(.high)
                .frame(width: 31, height: 31)
                .frame(width: 25, height: 25)
                .accessibilityHidden(true)
            Text("Paperbranch")
                .font(.system(size: 16, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(PBColor.inkStrong)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Paperbranch")
    }
}
```

## Section label

"Open now", "Library", and "On this page". Pass the words in sentence case. The label uppercases them.

```swift
struct PBSectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: PBSize.textLabel, weight: .semibold))
            .tracking(PBSize.trackingLabel)
            .foregroundStyle(PBColor.inkMuted)
            .padding(.horizontal, PBSize.space2)
            .padding(.top, PBSize.space3)
            .padding(.bottom, PBSize.space1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}
```

## Library row

One row type for documents and folders. States: default, hover (`--row-hover`), selected (`--row-selected` fill, `--ink-strong` medium text, 2 px `--accent` bar), and keyboard focus (the system focus ring). Folders show a chevron that turns 90 degrees when expanded, and no folder icon. The whole row width takes the click.

```swift
struct PBLibraryRow: View {
    enum Kind: Equatable {
        case document
        case folder(expanded: Bool)
    }

    let name: String
    let kind: Kind
    let depth: Int
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                ZStack {
                    if case .folder(let expanded) = kind {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(PBColor.inkIcon)
                            .rotationEffect(.degrees(expanded ? 90 : 0))
                    }
                }
                .frame(width: 12)
                Text(name)
                    .font(.system(size: PBSize.textUI, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? PBColor.inkStrong : PBColor.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
            }
            .padding(.leading, PBSize.space3 + CGFloat(depth) * PBSize.indent)
            .padding(.trailing, PBSize.space2)
            .frame(height: PBSize.rowHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: PBSize.radiusM))
            .overlay(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(PBColor.accent)
                        .frame(width: 2)
                        .padding(.vertical, 6)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: PBMotion.fast), value: isHovered)
        .animation(reduceMotion ? nil : .easeOut(duration: PBMotion.medium), value: kind)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var fill: Color {
        isSelected ? PBColor.rowSelected : isHovered ? PBColor.rowHover : .clear
    }

    private var accessibilityText: String {
        switch kind {
        case .document: return name
        case .folder(let expanded): return "Folder: \(name), \(expanded ? "expanded" : "collapsed")"
        }
    }
}
```

## Open now card

Sits above the Library tree, under "Open now". It shows the selected Library document's name and word count, and "Edited" with a dot when the document has unsaved edits. It is a flat `--row-hover` fill with no border. Clicking it does nothing, and it is hidden when no Library document is selected.

```swift
struct PBOpenNowCard: View {
    let name: String
    let wordCount: Int?
    let isEdited: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                if isEdited {
                    Circle().fill(PBColor.inkMuted).frame(width: 6, height: 6)
                }
                Text(name)
                    .font(.system(size: PBSize.textUI, weight: .medium))
                    .foregroundStyle(PBColor.inkStrong)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Text(detail)
                .font(.system(size: PBSize.textCaption))
                .foregroundStyle(PBColor.inkMuted)
        }
        .padding(.horizontal, PBSize.space3)
        .padding(.vertical, PBSize.space2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PBColor.rowHover, in: RoundedRectangle(cornerRadius: PBSize.radiusM))
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        let count = wordCount.map { "\($0.formatted()) words" }
        return [count, isEdited ? "Edited" : nil].compactMap { $0 }.joined(separator: " · ")
    }
}
```

## Buttons

Two roles. Primary is an ink fill, one per window. Secondary is a `--surface` fill with a `--border` outline. Both are 30 px tall with a 6 px radius and 13 px medium text. States: hover, pressed, disabled (40% opacity), and the system focus ring. Destructive choices live in native alerts, which draw their own red (see `screens.md`).

```swift
struct PBButtonStyle: ButtonStyle {
    enum Role { case primary, secondary }
    var role: Role

    func makeBody(configuration: Configuration) -> some View {
        PBButtonBody(configuration: configuration, role: role)
    }
}

private struct PBButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let role: PBButtonStyle.Role

    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        configuration.label
            .font(.system(size: PBSize.textUI, weight: .medium))
            .foregroundStyle(role == .primary ? PBColor.inkOnStrong : PBColor.ink)
            .padding(.horizontal, PBSize.space4)
            .frame(height: 30)
            .background(background, in: RoundedRectangle(cornerRadius: PBSize.radiusM))
            .overlay {
                if role == .secondary {
                    RoundedRectangle(cornerRadius: PBSize.radiusM).strokeBorder(PBColor.border)
                }
            }
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: PBSize.radiusM))
            .onHover { isHovered = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: PBMotion.fast), value: isHovered)
    }

    private var background: Color {
        switch role {
        case .primary:
            return PBColor.inkStrong.opacity(configuration.isPressed ? 0.74 : isHovered ? 0.86 : 1)
        case .secondary:
            return configuration.isPressed ? PBColor.rowSelected : isHovered ? PBColor.rowHover : PBColor.surface
        }
    }
}
```

## Top bar

52 px tall, and it is also the window's drag area. The sidebar toggle sits on the left (beside the window buttons when the sidebar is collapsed), the document name and its status in the middle, and Open on the right. "· Edited" is `--ink-muted`. "· Changed on disk" is `--danger`.

```swift
enum PBDocumentStatus {
    case edited, changedOnDisk

    var text: String { self == .edited ? "Edited" : "Changed on disk" }
    var color: Color { self == .edited ? PBColor.inkMuted : PBColor.danger }
}

struct PBTopBar: View {
    let title: String?
    let status: PBDocumentStatus?
    let showsSidebarToggle: Bool
    let toggleSidebar: () -> Void
    let open: (() -> Void)?

    var body: some View {
        HStack(spacing: PBSize.space3) {
            if showsSidebarToggle {
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14))
                        .foregroundStyle(PBColor.inkIcon)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show or Hide Library")
            }
            Spacer(minLength: 0)
            if let title {
                (Text(title).foregroundColor(PBColor.ink)
                    + Text(status.map { "  ·  \($0.text)" } ?? "").foregroundColor(status?.color ?? PBColor.inkMuted))
                    .font(.system(size: PBSize.textUI, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
            if let open {
                Button("Open", action: open)
                    .buttonStyle(PBButtonStyle(role: .secondary))
            }
        }
        .padding(.horizontal, PBSize.space4)
        .frame(height: PBSize.topbarHeight)
        .overlay(alignment: .bottom) { Rectangle().fill(PBColor.rule).frame(height: 1) }
    }
}
```

## Reading progress line

A 2 px `--accent` line under the top bar that grows with the scroll. It lives in the Document view, not the native chrome, so moving it never re-renders the sidebar or top bar. The editor updates it once per animation frame from the same callback that reads the scroll position, with no animation of its own (Ticket 49, 22 Oct 2026).

```html
<div id="reading-progress" role="progressbar" aria-label="Reading progress" aria-valuemin="0" aria-valuemax="100" aria-valuenow="0"></div>
```

```css
#reading-progress {
  position: fixed; top: 0; left: 0; right: 0; z-index: 20; height: 2px;
  background: var(--accent); transform: scaleX(0); transform-origin: left; pointer-events: none;
}
```

Per frame, after every layout read: set `transform: scaleX(progress)`, and update `aria-valuenow` only when the whole percent changes.

## Outline panel

"On this page", 220 px on the right of the Document view, shown when the window is 1240 px wide or wider. Below that width, the same entries render under the Library tree. Items are 12 px `--ink-muted`, indented 12 px per heading level. The current heading is `--ink-strong` medium with a 2 px `--accent` bar.

```swift
struct PBOutlineEntry: Identifiable {
    let id: String
    let text: String
    let level: Int
}

struct PBOutlinePanel: View {
    let entries: [PBOutlineEntry]
    let currentID: String?
    let select: (String) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                PBSectionLabel(text: "On this page")
                ForEach(entries) { entry in
                    let isCurrent = entry.id == currentID
                    Button { select(entry.id) } label: {
                        Text(entry.text)
                            .font(.system(size: PBSize.textCaption, weight: isCurrent ? .medium : .regular))
                            .foregroundStyle(isCurrent ? PBColor.inkStrong : PBColor.inkMuted)
                            .lineLimit(1)
                            .padding(.leading, PBSize.space3 + CGFloat(max(0, entry.level - 1)) * PBSize.space3)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(alignment: .leading) {
                                if isCurrent {
                                    RoundedRectangle(cornerRadius: 1).fill(PBColor.accent).frame(width: 2).padding(.vertical, 6)
                                }
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isCurrent ? .isSelected : [])
                }
            }
            .padding(.top, PBSize.space7)
            .padding(.trailing, PBSize.space4)
        }
        .frame(width: PBSize.outlineWidth)
    }
}
```

## State view

Choosing a Library, Library unavailable, and Document unavailable. A 52 px `--surface` icon tile with a `--border` outline, a 15 px semibold title, one `--ink-muted` sentence, and up to two buttons with the main action on the right as the primary.

```swift
struct PBStateView: View {
    struct Action {
        let title: String
        let perform: () -> Void
    }

    let symbol: String
    let title: String
    let message: String
    var secondary: Action? = nil
    var primary: Action? = nil

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: symbol)
                .font(.system(size: 22))
                .foregroundStyle(PBColor.inkIcon)
                .frame(width: 52, height: 52)
                .background(PBColor.surface, in: RoundedRectangle(cornerRadius: PBSize.radiusL))
                .overlay { RoundedRectangle(cornerRadius: PBSize.radiusL).strokeBorder(PBColor.border) }
                .padding(.bottom, PBSize.space4)
            Text(title)
                .font(.system(size: PBSize.textUILarge, weight: .semibold))
                .foregroundStyle(PBColor.inkStrong)
                .padding(.bottom, PBSize.space2)
            Text(message)
                .font(.system(size: PBSize.textUI))
                .foregroundStyle(PBColor.inkMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
                .padding(.bottom, PBSize.space5)
            HStack(spacing: PBSize.space3) {
                if let secondary {
                    Button(secondary.title, action: secondary.perform).buttonStyle(PBButtonStyle(role: .secondary))
                }
                if let primary {
                    Button(primary.title, action: primary.perform)
                        .buttonStyle(PBButtonStyle(role: .primary))
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(.bottom, PBSize.space8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PBColor.paper)
    }
}
```

## Alerts

Questions are native `NSAlert` sheets. The first button is the default (Return). Set `hasDestructiveAction` on the button that throws work away, and macOS colors it.

```swift
@MainActor
func pbPresentConflictAlert(documentName: String, on window: NSWindow, keepEdits: @escaping () -> Void, reload: @escaping () -> Void) {
    let alert = NSAlert()
    alert.messageText = "Changes conflict in \(documentName)"
    alert.informativeText = "This document changed on disk while you have unsaved edits. Keep your edits, or reload the version on disk and lose them."
    alert.addButton(withTitle: "Keep My Edits")
    let reloadButton = alert.addButton(withTitle: "Reload from Disk")
    reloadButton.hasDestructiveAction = true
    alert.beginSheetModal(for: window) { response in
        response == .alertFirstButtonReturn ? keepEdits() : reload()
    }
}
```

## Document view

The stylesheet for `editor-proof/index.html`. Link `tokens.css` first, and remove the page's own `color-scheme: dark` so the Document view follows the macOS appearance.

```css
body { margin: 0; background: var(--paper); color: var(--ink); }
::selection { background: var(--selection); }

#document { max-width: calc(var(--measure) + 2 * var(--space-5)); margin: var(--space-7) auto 0; padding: 0 var(--space-5) var(--space-8); }
#document-meta {
  margin-bottom: var(--space-3);
  font: var(--weight-semibold) var(--text-label) / var(--leading-ui) var(--font-ui);
  letter-spacing: var(--tracking-label); text-transform: uppercase; color: var(--ink-muted);
}
#document-meta[hidden], #document-footer[hidden] { display: none; }

.ProseMirror { outline: none; font: var(--text-body) / var(--leading-body) var(--font-reading); color: var(--ink); overflow-wrap: anywhere; }
.ProseMirror > :first-child { margin-top: 0; }
.ProseMirror h1, .ProseMirror h2, .ProseMirror h3, .ProseMirror h4 {
  font-family: var(--font-ui); font-weight: var(--weight-bold);
  letter-spacing: var(--tracking-heading); line-height: var(--leading-heading); color: var(--ink-strong);
}
.ProseMirror h1 { margin: 0 0 var(--space-5); font-size: var(--text-h1); }
.ProseMirror h2 { margin: var(--space-7) 0 var(--space-3); font-size: var(--text-h2); }
.ProseMirror h3 { margin: var(--space-6) 0 var(--space-3); font-size: var(--text-h3); }
.ProseMirror h4 { margin: var(--space-5) 0 var(--space-2); font-size: var(--text-h4); }
.ProseMirror p { margin: 0 0 var(--space-4); }
.ProseMirror a { color: var(--accent-text); text-underline-offset: 3px; }
.ProseMirror blockquote { margin: var(--space-5) 0; padding-left: var(--space-4); border-left: 2px solid var(--border); font-style: italic; color: var(--ink-muted); }
.ProseMirror ul, .ProseMirror ol { margin: 0 0 var(--space-4); padding-left: 1.35em; }
.ProseMirror li { margin: var(--space-1) 0; }
.ProseMirror code { padding: 0.12em 0.36em; border-radius: var(--radius-s); background: var(--code-bg); color: var(--accent-text); font: 0.84em var(--font-mono); }
.ProseMirror pre { margin: var(--space-5) 0; padding: var(--space-4) var(--space-5); overflow: auto; border-radius: var(--radius-l); background: var(--code-bg); }
.ProseMirror pre code { padding: 0; background: transparent; color: var(--ink); font-size: var(--text-code); line-height: var(--leading-body); }
.ProseMirror hr { margin: var(--space-7) 0; border: 0; border-top: 1px solid var(--rule); }
.ProseMirror table { width: 100%; margin: var(--space-5) 0; border-collapse: collapse; font: var(--text-ui) var(--font-ui); }
.ProseMirror th, .ProseMirror td { padding: var(--space-2) var(--space-3); border-bottom: 1px solid var(--rule); text-align: left; }
.ProseMirror th { color: var(--ink-muted); font-size: var(--text-caption); letter-spacing: var(--tracking-label); text-transform: uppercase; }
.ProseMirror img { max-width: 100%; border-radius: var(--radius-l); }
.ProseMirror img.paperbranch-broken-image {
  min-width: 180px; min-height: 56px; padding: var(--space-4);
  border: 1px solid var(--danger); background: var(--code-bg); color: var(--danger); font: var(--text-ui) var(--font-ui);
}

#document-footer {
  display: flex; justify-content: space-between; margin-top: var(--space-8); padding-top: var(--space-5);
  border-top: 1px solid var(--rule); color: var(--ink-muted); font: var(--text-caption) var(--font-ui);
}
#editor-root[data-admission="blocked"] { color: var(--danger); font: var(--text-ui-large) / var(--leading-ui) var(--font-ui); }
```

## Formatting popover

Shows above a non-empty text selection: link, bold, italic, strikethrough, inline code. It fades in `--duration-fast`. An active button keeps a `--selection` fill and draws its glyph in `--accent-text`. This was a judgment call on 22 Oct 2026: a fill alone measured 1.08:1 in dark mode, and the blue glyph measures 4.9:1.

```css
#formatting-popover {
  position: absolute; display: flex; gap: 2px; padding: 3px;
  background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius-l);
  box-shadow: var(--shadow-popover);
  opacity: 0; visibility: hidden; transition: opacity var(--duration-fast) var(--ease), visibility 0s var(--duration-fast);
}
#formatting-popover[data-show="true"] { opacity: 1; visibility: visible; transition: opacity var(--duration-fast) var(--ease), visibility 0s; }
#formatting-popover button {
  width: 28px; height: 26px; display: inline-flex; align-items: center; justify-content: center; padding: 0;
  border: 0; border-radius: var(--radius-s); background: transparent; color: var(--ink); font: var(--text-ui) var(--font-ui);
}
#formatting-popover button[aria-pressed="true"] { background: var(--selection); color: var(--accent-text); }
#formatting-popover .bold { font-weight: var(--weight-bold); }
#formatting-popover .italic { font-family: var(--font-reading); font-style: italic; }
#formatting-popover .strike { text-decoration: line-through; }
```
