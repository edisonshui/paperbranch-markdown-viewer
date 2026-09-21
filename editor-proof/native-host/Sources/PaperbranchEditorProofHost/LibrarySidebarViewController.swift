import AppKit
import PaperbranchBridgeCore

final class LibrarySidebarViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    var chooseLibrary: (() -> Void)?
    var selectDocument: ((URL) -> Void)?
    private let outlineView = NSOutlineView()
    private var library: LibraryBrowser?

    override func loadView() {
        let root = NSView()
        let title = NSTextField(labelWithString: "Paperbranch")
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        let chooseButton = NSButton(title: "Choose Library…", target: self, action: #selector(chooseLibraryPressed))
        let header = NSStackView(views: [title, NSView(), chooseButton])
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

        let stack = NSStackView(views: [header, scroll])
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

    func show(_ library: LibraryBrowser) {
        self.library = library
        outlineView.reloadData()
        outlineView.expandItem(nil, expandChildren: true)
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
}
