import AppKit
import SwiftUI

// The chrome's parts from the design skill's components.md, built on PaperbranchTheme.swift.
// Changes from the skill's snippets keep the app's existing accessibility labels and identifiers,
// which the tests and VoiceOver rely on: each part takes its label from the caller.

struct PBWordmark: View {
    var body: some View {
        HStack(spacing: 9) {
            // The logo is the app icon itself, as macOS draws it, so the two always match.
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Paperbranch")
    }
}

/// "Open now", "Library", and "On this page". Pass the words in sentence case.
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

/// One row type for documents and folders. The whole row width takes the click.
struct PBLibraryRow: View {
    enum Kind: Equatable {
        case document
        case folder(expanded: Bool)
    }

    let name: String
    let kind: Kind
    let depth: Int
    let isSelected: Bool
    let accessibilityText: String
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
}

/// The selected Library document's name, word count, and Edited mark, above the Library tree.
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
            if !detail.isEmpty {
                Text(detail)
                    .font(.system(size: PBSize.textCaption))
                    .foregroundStyle(PBColor.inkMuted)
            }
        }
        .padding(.horizontal, PBSize.space3)
        .padding(.vertical, PBSize.space2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PBColor.rowHover, in: RoundedRectangle(cornerRadius: PBSize.radiusM))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((["Open now: \(name)"] + [wordCountText, isEdited ? "Edited" : nil].compactMap { $0 }).joined(separator: ", "))
    }

    private var wordCountText: String? {
        wordCount.map { "\($0.formatted()) \($0 == 1 ? "word" : "words")" }
    }

    private var detail: String {
        [wordCountText, isEdited ? "Edited" : nil].compactMap { $0 }.joined(separator: " · ")
    }
}

/// Primary is an ink fill, one per window. Secondary is a --surface fill with a --border outline.
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

enum PBDocumentStatus: Equatable {
    case edited, changedOnDisk

    var text: String { self == .edited ? "Edited" : "Changed on disk" }
    var color: Color { self == .edited ? PBColor.inkMuted : PBColor.danger }
}

/// 52 px tall and the window's drag area. The sidebar toggle on the left, the document name and status in the
/// middle, Open on the right. `leadingInset` clears the window buttons when no sidebar sits under them.
struct PBTopBar: View {
    let title: String?
    let status: PBDocumentStatus?
    var leadingInset: CGFloat = 0
    var sidebarToggle: (label: String, action: () -> Void)? = nil
    var open: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: PBSize.space3) {
            if let sidebarToggle {
                Button(action: sidebarToggle.action) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14))
                        .foregroundStyle(PBColor.inkIcon)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(sidebarToggle.label)
                .accessibilityIdentifier("paperbranch.reader.toggle-sidebar")
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
                    .accessibilityLabel("Open")
                    .accessibilityIdentifier("paperbranch.reader.open")
            }
        }
        .padding(.leading, PBSize.space4 + leadingInset)
        .padding(.trailing, PBSize.space4)
        .frame(height: PBSize.topbarHeight)
        .frame(maxWidth: .infinity)
        .background(PBWindowDragArea())
        .overlay(alignment: .bottom) { Rectangle().fill(PBColor.rule).frame(height: 1) }
    }
}

/// The transparent title bar covers only the top of the top bar, so the rest of the bar moves the window too.
struct PBWindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> PBWindowDragView { PBWindowDragView() }
    func updateNSView(_ nsView: PBWindowDragView, context: Context) {}
}

final class PBWindowDragView: NSView {
    var doubleClickAction: () -> PBTitleBarDoubleClickAction = { PBTitleBarDoubleClickAction.current() }

    // The top bar covers the transparent title bar, so a double-click here does what the title bar would.
    override func mouseDown(with event: NSEvent) {
        guard event.clickCount == 2 else { return window?.performDrag(with: event) ?? () }
        switch doubleClickAction() {
        case .zoom: window?.zoom(nil)
        case .minimize: window?.miniaturize(nil)
        case .none: break
        }
    }
}

/// The System Settings choice under "Double-click a window's title bar". Zoom is the macOS default.
enum PBTitleBarDoubleClickAction: Equatable {
    case zoom, minimize, none

    static func current(_ defaults: UserDefaults = .standard) -> PBTitleBarDoubleClickAction {
        switch defaults.string(forKey: "AppleActionOnDoubleClick") {
        case "Minimize": return .minimize
        case "None": return .none
        default: return .zoom
        }
    }
}

/// "On this page": outline items at 12 px --ink-muted, indented 12 px per level. The current heading is
/// --ink-strong medium with a 2 px --accent bar. The same rows render as a right panel and under the Library tree.
struct PBOutlineRows: View {
    let entries: [DocumentOutlineEntry]
    let select: (String) -> Void

    var body: some View {
        PBSectionLabel(text: "On this page")
        ForEach(entries, id: \.id) { entry in
            Button { select(entry.id) } label: {
                Text(entry.text)
                    .font(.system(size: PBSize.textCaption, weight: entry.isCurrent ? .medium : .regular))
                    .foregroundStyle(entry.isCurrent ? PBColor.inkStrong : PBColor.inkMuted)
                    .lineLimit(1)
                    .padding(.leading, PBSize.space3 + CGFloat(max(0, entry.level - 1)) * PBSize.space3)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .leading) {
                        if entry.isCurrent {
                            RoundedRectangle(cornerRadius: 1).fill(PBColor.accent).frame(width: 2).padding(.vertical, 6)
                        }
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(entry.text)
            .accessibilityValue(entry.isCurrent ? "Current heading" : "")
            .accessibilityAddTraits(entry.isCurrent ? .isSelected : [])
            .accessibilityIdentifier("paperbranch.library.outline.\(entry.id)")
        }
    }
}

/// The outline as a 220 px panel on the right of the Document view, for windows 1240 px and wider.
struct PBOutlinePanel: View {
    let entries: [DocumentOutlineEntry]
    let select: (String) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                PBOutlineRows(entries: entries, select: select)
            }
            .padding(.top, PBSize.space7)
            .padding(.trailing, PBSize.space4)
        }
        .frame(width: PBSize.outlineWidth)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("On this page")
        .accessibilityIdentifier("paperbranch.reader.outline-panel")
    }
}

/// Choosing a Library, Library unavailable, and Document unavailable: an icon tile, a title, one sentence,
/// and up to two buttons with the main action on the right as the primary.
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
                .accessibilityHidden(true)
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
        // A Color background reaches into the safe area by default, which would paint over the top bar above it.
        .background(PBColor.paper, ignoresSafeAreaEdges: [])
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .accessibilityIdentifier("paperbranch.reader.state")
    }
}
