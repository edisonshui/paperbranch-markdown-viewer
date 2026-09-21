import AppKit
import PaperbranchBridgeCore

final class LibrarySidebarViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    var chooseLibrary: (() -> Void)?
    var selectDocument: ((URL) -> Void)?
    var folderExpansionChanged: ((LibraryNode, Bool) -> Void)?
    var selectOutline: ((String) -> Void)?
    private let outlineView = NSOutlineView()
    private let statusLabel = NSTextField(labelWithString: "Library access is unavailable. Reconnect or choose another Library.")
    private let chooseButton = NSButton(title: "Choose Library…", target: nil, action: nil)
    private var library: LibraryBrowser?
    private let navigationStack = NSStackView()
    private let progressLabel = NSTextField(labelWithString: "Reading progress: 0%")

    override func loadView() {
        let root = NSView()
        let title = NSTextField(labelWithString: "Paperbranch")
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        chooseButton.target = self
        chooseButton.action = #selector(chooseLibraryPressed)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.isHidden = true
        let header = NSStackView(views: [title, statusLabel, NSView(), chooseButton])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 10, right: 10)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("LibraryItem"))
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.headerView = nil
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.style = .sourceList
        outlineView.autosaveExpandedItems = false
        let scroll = NSScrollView()
        scroll.documentView = outlineView
        scroll.hasVerticalScroller = true

        navigationStack.orientation = .vertical
        navigationStack.spacing = 2
        let navigationHeader = NSTextField(labelWithString: "Document outline")
        navigationHeader.font = .systemFont(ofSize: 11, weight: .semibold)
        navigationStack.addArrangedSubview(navigationHeader)
        navigationStack.addArrangedSubview(progressLabel)
        let stack = NSStackView(views: [header, scroll, navigationStack])
        stack.orientation = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor), stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stack.topAnchor.constraint(equalTo: root.topAnchor), stack.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])
        scroll.widthAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true
        view = root
    }

    func showDocumentNavigation(outline: [DocumentOutlineEntry], progress: Double) {
        navigationStack.arrangedSubviews.dropFirst(2).forEach { navigationStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        if outline.isEmpty {
            navigationStack.addArrangedSubview(NSTextField(labelWithString: "No headings in this document."))
        } else {
            for entry in outline {
                let button = NSButton(title: String(repeating: "  ", count: max(0, entry.level - 1)) + entry.text, target: self, action: #selector(outlinePressed(_:)))
                button.identifier = NSUserInterfaceItemIdentifier(entry.id)
                button.alignment = .left
                button.bezelStyle = .inline
                navigationStack.addArrangedSubview(button)
            }
        }
        progressLabel.stringValue = "Reading progress: \(Int((max(0, min(1, progress)) * 100).rounded()))%"
    }

    @objc private func outlinePressed(_ sender: NSButton) { if let id = sender.identifier?.rawValue { selectOutline?(id) } }

    func show(_ library: LibraryBrowser, sidebarState: LibrarySidebarState = LibrarySidebarState(), selectedDocumentURL: URL? = nil) {
        self.library = library
        statusLabel.isHidden = true
        chooseButton.title = "Choose Library…"
        outlineView.reloadData()
        outlineView.expandItem(nil, expandChildren: false)
        for node in library.root.flattened() where node.kind == .folder && node.url != library.root.url {
            if sidebarState.isExpanded(node) { outlineView.expandItem(node) }
        }
        select(url: selectedDocumentURL)
    }

    func showUnavailableLibrary() {
        library = nil
        statusLabel.isHidden = false
        chooseButton.title = "Choose another Library…"
        outlineView.reloadData()
    }

    func select(url: URL?) {
        guard let url else { outlineView.deselectAll(nil); return }
        for row in 0..<outlineView.numberOfRows where (outlineView.item(atRow: row) as? LibraryNode)?.url == url {
            outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            return
        }
    }

    @objc private func chooseLibraryPressed() { chooseLibrary?() }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        guard let library else { return 0 }
        return (item as? LibraryNode)?.children.count ?? library.root.children.count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        guard let library else { fatalError("Library sidebar requested content before choosing a Library") }
        return ((item as? LibraryNode)?.children ?? library.root.children)[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? LibraryNode)?.kind == .folder
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? LibraryNode else { return nil }
        let identifier = NSUserInterfaceItemIdentifier("LibraryCell")
        let cell = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? NSTableCellView()
        cell.identifier = identifier
        let text = cell.textField ?? NSTextField(labelWithString: "")
        if cell.textField == nil {
            text.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(text)
            NSLayoutConstraint.activate([text.leadingAnchor.constraint(equalTo: cell.leadingAnchor), text.trailingAnchor.constraint(equalTo: cell.trailingAnchor), text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)])
            cell.textField = text
        }
        text.stringValue = node.name
        text.textColor = node.kind == .folder ? .secondaryLabelColor : .labelColor
        return cell
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let node = outlineView.item(atRow: outlineView.selectedRow) as? LibraryNode, node.kind == .document else { return }
        selectDocument?(node.url)
    }

    func outlineViewItemDidExpand(_ notification: Notification) {
        guard let node = notification.userInfo?["NSObject"] as? LibraryNode else { return }
        folderExpansionChanged?(node, true)
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {
        guard let node = notification.userInfo?["NSObject"] as? LibraryNode else { return }
        folderExpansionChanged?(node, false)
    }
}
