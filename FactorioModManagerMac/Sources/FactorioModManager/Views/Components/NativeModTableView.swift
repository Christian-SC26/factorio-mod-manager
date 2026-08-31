import AppKit
import SwiftUI

public protocol NativeModTableViewDelegate: AnyObject {
    func modTableView(_ view: NativeModTableViewNSView, didToggleMod mod: LocalMod, newState: Bool)
    func modTableView(_ view: NativeModTableViewNSView, didToggleSelection mods: [LocalMod])
    func modTableView(_ view: NativeModTableViewNSView, didRequestDelete mods: [LocalMod])
    func modTableView(_ view: NativeModTableViewNSView, didOpenDetails mod: LocalMod)
    func modTableView(_ view: NativeModTableViewNSView, didOpenPortal mod: LocalMod)
    func modTableView(_ view: NativeModTableViewNSView, didOpenAuthor mod: LocalMod)
    func modTableView(_ view: NativeModTableViewNSView, didRevealInFinder mods: [LocalMod])
    func modTableView(_ view: NativeModTableViewNSView, didChangeSort columnIdentifier: String, ascending: Bool)
}

public final class CustomTableView: NSTableView {
    public weak var actionDelegate: NativeModTableViewDelegate?
    public var currentMods: [LocalMod] = []

    public override func keyDown(with event: NSEvent) {
        let isCmd = event.modifierFlags.contains(.command)
        let isShift = event.modifierFlags.contains(.shift)
        let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""
        let keyCode = event.keyCode

        // Space: Toggle selected mods
        if keyCode == 49 || chars == " " {
            let selected = selectedMods()
            if !selected.isEmpty {
                actionDelegate?.modTableView(enclosingView, didToggleSelection: selected)
                return
            }
        }

        // Delete / Backspace
        if keyCode == 51 || keyCode == 117 {
            let selected = selectedMods()
            if !selected.isEmpty {
                actionDelegate?.modTableView(enclosingView, didRequestDelete: selected)
                return
            }
        }

        // Command shortcuts
        if isCmd {
            let selected = selectedMods()
            let first = selected.first
            switch chars {
            case "l":
                if let mod = first {
                    actionDelegate?.modTableView(enclosingView, didOpenPortal: mod)
                    return
                }
            case "o":
                if !selected.isEmpty {
                    actionDelegate?.modTableView(enclosingView, didRevealInFinder: selected)
                    return
                }
            case "a":
                if let mod = first {
                    actionDelegate?.modTableView(enclosingView, didOpenAuthor: mod)
                    return
                }
            case "i":
                if let mod = first {
                    actionDelegate?.modTableView(enclosingView, didOpenDetails: mod)
                    return
                }
            default:
                break
            }
        }

        // J (Down) / K (Up) navigation
        if !isCmd {
            if chars == "j" {
                moveRowSelection(delta: 1, extend: isShift)
                return
            }
            if chars == "k" {
                moveRowSelection(delta: -1, extend: isShift)
                return
            }
        }

        super.keyDown(with: event)
    }

    private var enclosingView: NativeModTableViewNSView {
        (superview?.superview as? NativeModTableViewNSView) ?? NativeModTableViewNSView()
    }

    public func selectedMods() -> [LocalMod] {
        let indices = selectedRowIndexes.filter { $0 >= 0 && $0 < currentMods.count }
        if !indices.isEmpty {
            return indices.map { currentMods[$0] }
        }
        if selectedRow >= 0 && selectedRow < currentMods.count {
            return [currentMods[selectedRow]]
        }
        return []
    }

    private func moveRowSelection(delta: Int, extend: Bool) {
        guard !currentMods.isEmpty else { return }
        let current = selectedRow >= 0 ? selectedRow : 0
        let target = min(max(0, current + delta), currentMods.count - 1)

        if extend {
            var set = selectedRowIndexes
            set.insert(target)
            selectRowIndexes(set, byExtendingSelection: false)
        } else {
            selectRowIndexes(IndexSet(integer: target), byExtendingSelection: false)
        }
        scrollRowToVisible(target)
    }
}

public final class NativeModTableViewNSView: NSView, NSTableViewDataSource, NSTableViewDelegate {
    public let scrollView = NSScrollView()
    public let tableView = CustomTableView()
    public weak var delegate: NativeModTableViewDelegate? {
        didSet {
            tableView.actionDelegate = delegate
        }
    }

    public var mods: [LocalMod] = [] {
        didSet {
            tableView.currentMods = mods
            tableView.reloadData()
        }
    }
    public var modPortalOwners: [String: String] = [:]
    public var enabledStates: [String: Bool] = [:]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        tableView.delegate = self
        tableView.dataSource = self
        tableView.actionDelegate = delegate
        tableView.rowHeight = 28
        tableView.usesAutomaticRowHeights = false
        tableView.intercellSpacing = NSSize(width: 12, height: 0)
        tableView.selectionHighlightStyle = .regular
        tableView.focusRingType = .none
        tableView.allowsMultipleSelection = true
        tableView.style = .inset
        tableView.backgroundColor = .clear

        // Columns setup
        let colActive = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("active"))
        colActive.title = "Active"
        colActive.width = 46
        colActive.minWidth = 46
        colActive.maxWidth = 46
        colActive.sortDescriptorPrototype = NSSortDescriptor(key: "enabled", ascending: false)
        tableView.addTableColumn(colActive)

        let colName = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        colName.title = "Mod Name"
        colName.width = 240
        colName.minWidth = 180
        colName.sortDescriptorPrototype = NSSortDescriptor(key: "displayTitle", ascending: true)
        tableView.addTableColumn(colName)

        let colAuthor = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("author"))
        colAuthor.title = "Author"
        colAuthor.width = 120
        colAuthor.minWidth = 80
        colAuthor.maxWidth = 180
        colAuthor.sortDescriptorPrototype = NSSortDescriptor(key: "author", ascending: true)
        tableView.addTableColumn(colAuthor)

        let colDate = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("date"))
        colDate.title = "Date Added"
        colDate.width = 100
        colDate.minWidth = 80
        colDate.maxWidth = 140
        colDate.sortDescriptorPrototype = NSSortDescriptor(key: "dateSortKey", ascending: false)
        tableView.addTableColumn(colDate)

        let colVersion = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("version"))
        colVersion.title = "Version"
        colVersion.width = 75
        colVersion.minWidth = 60
        colVersion.maxWidth = 95
        colVersion.sortDescriptorPrototype = NSSortDescriptor(key: "version.raw", ascending: false)
        tableView.addTableColumn(colVersion)

        let colSize = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("size"))
        colSize.title = "Size"
        colSize.width = 75
        colSize.minWidth = 60
        colSize.maxWidth = 95
        colSize.sortDescriptorPrototype = NSSortDescriptor(key: "fileSize", ascending: false)
        tableView.addTableColumn(colSize)

        let colActions = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("actions"))
        colActions.title = "Actions"
        colActions.width = 115
        colActions.minWidth = 105
        colActions.maxWidth = 130
        tableView.addTableColumn(colActions)

        scrollView.documentView = tableView
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    // MARK: - NSTableViewDataSource & Delegate
    public func numberOfRows(in tableView: NSTableView) -> Int {
        mods.count
    }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0 && row < mods.count, let col = tableColumn else { return nil }
        let mod = mods[row]
        let isEnabled = enabledStates[mod.name] ?? mod.enabled
        let identifier = col.identifier

        var cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = identifier
        }
        guard let cellView = cell else { return nil }

        // Remove old custom subviews if any
        for sub in cellView.subviews {
            sub.removeFromSuperview()
        }

        switch identifier.rawValue {
        case "active":
            let sw = NSSwitch()
            sw.controlSize = .mini
            sw.state = isEnabled ? .on : .off
            sw.target = self
            sw.action = #selector(switchToggled(_:))
            sw.tag = row
            sw.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(sw)
            NSLayoutConstraint.activate([
                sw.centerXAnchor.constraint(equalTo: cellView.centerXAnchor),
                sw.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])

        case "name":
            let tf = NSTextField(labelWithString: mod.displayTitle)
            tf.font = .systemFont(ofSize: 13, weight: .medium)
            tf.textColor = isEnabled ? .labelColor : .secondaryLabelColor
            tf.lineBreakMode = .byTruncatingTail
            tf.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(tf)
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cellView.leadingAnchor),
                tf.trailingAnchor.constraint(equalTo: cellView.trailingAnchor),
                tf.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])

        case "author":
            let authorName = modPortalOwners[mod.name] ?? mod.cleanAuthorName
            let hasPortal = mod.portalAuthorURL(portalOwner: modPortalOwners[mod.name]) != nil

            let btn = NSButton(title: authorName, target: self, action: #selector(authorClicked(_:)))
            btn.tag = row
            btn.isBordered = false
            btn.font = .systemFont(ofSize: 12)
            btn.contentTintColor = hasPortal ? .controlAccentColor : .secondaryLabelColor
            btn.alignment = .left
            btn.lineBreakMode = .byTruncatingTail
            btn.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(btn)
            NSLayoutConstraint.activate([
                btn.leadingAnchor.constraint(equalTo: cellView.leadingAnchor),
                btn.trailingAnchor.constraint(equalTo: cellView.trailingAnchor),
                btn.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])

        case "date":
            let tf = NSTextField(labelWithString: mod.formattedDate)
            tf.font = .systemFont(ofSize: 12)
            tf.textColor = .secondaryLabelColor
            tf.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(tf)
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cellView.leadingAnchor),
                tf.trailingAnchor.constraint(equalTo: cellView.trailingAnchor),
                tf.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])

        case "version":
            let tf = NSTextField(labelWithString: mod.version.raw)
            tf.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            tf.textColor = .secondaryLabelColor
            tf.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(tf)
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cellView.leadingAnchor),
                tf.trailingAnchor.constraint(equalTo: cellView.trailingAnchor),
                tf.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])

        case "size":
            let tf = NSTextField(labelWithString: mod.fileSize > 0 ? formatBytes(mod.fileSize) : "—")
            tf.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            tf.textColor = .secondaryLabelColor
            tf.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(tf)
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cellView.leadingAnchor),
                tf.trailingAnchor.constraint(equalTo: cellView.trailingAnchor),
                tf.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])

        case "actions":
            let stack = NSStackView()
            stack.orientation = .horizontal
            stack.spacing = 8
            stack.alignment = .centerY
            stack.translatesAutoresizingMaskIntoConstraints = false

            // Safari
            let bSafari = NSButton(image: NSImage(systemSymbolName: "safari", accessibilityDescription: "Portal") ?? NSImage(), target: self, action: #selector(portalClicked(_:)))
            bSafari.tag = row
            bSafari.isBordered = false
            bSafari.contentTintColor = .controlAccentColor
            bSafari.toolTip = "Open on Factorio Portal (⌘L)"
            stack.addArrangedSubview(bSafari)

            // Info
            let bInfo = NSButton(image: NSImage(systemSymbolName: "info.circle", accessibilityDescription: "Details") ?? NSImage(), target: self, action: #selector(detailsClicked(_:)))
            bInfo.tag = row
            bInfo.isBordered = false
            bInfo.contentTintColor = .secondaryLabelColor
            bInfo.toolTip = "Mod Details (⌘I)"
            stack.addArrangedSubview(bInfo)

            // Folder
            let bFolder = NSButton(image: NSImage(systemSymbolName: "folder", accessibilityDescription: "Finder") ?? NSImage(), target: self, action: #selector(revealClicked(_:)))
            bFolder.tag = row
            bFolder.isBordered = false
            bFolder.contentTintColor = .secondaryLabelColor
            bFolder.toolTip = "Reveal in Finder (⌘O)"
            stack.addArrangedSubview(bFolder)

            // Trash
            let bTrash = NSButton(image: NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete") ?? NSImage(), target: self, action: #selector(deleteClicked(_:)))
            bTrash.tag = row
            bTrash.isBordered = false
            bTrash.contentTintColor = .systemRed.withAlphaComponent(0.8)
            bTrash.toolTip = "Delete Mod (⌫)"
            stack.addArrangedSubview(bTrash)

            cellView.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: cellView.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: cellView.trailingAnchor),
                stack.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])

        default:
            break
        }

        return cellView
    }

    public func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let first = tableView.sortDescriptors.first, let key = first.key else { return }
        delegate?.modTableView(self, didChangeSort: key, ascending: first.ascending)
    }

    // MARK: - Actions
    @objc private func switchToggled(_ sender: NSSwitch) {
        let row = sender.tag
        guard row >= 0 && row < mods.count else { return }
        let mod = mods[row]
        let newState = sender.state == .on
        delegate?.modTableView(self, didToggleMod: mod, newState: newState)
    }

    @objc private func authorClicked(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0 && row < mods.count else { return }
        delegate?.modTableView(self, didOpenAuthor: mods[row])
    }

    @objc private func portalClicked(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0 && row < mods.count else { return }
        delegate?.modTableView(self, didOpenPortal: mods[row])
    }

    @objc private func detailsClicked(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0 && row < mods.count else { return }
        delegate?.modTableView(self, didOpenDetails: mods[row])
    }

    @objc private func revealClicked(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0 && row < mods.count else { return }
        delegate?.modTableView(self, didRevealInFinder: [mods[row]])
    }

    @objc private func deleteClicked(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0 && row < mods.count else { return }
        delegate?.modTableView(self, didRequestDelete: [mods[row]])
    }
}

public struct NativeModTableViewRepresentable: NSViewRepresentable {
    public let mods: [LocalMod]
    public let modPortalOwners: [String: String]
    public let enabledStates: [String: Bool]
    public let onToggleMod: (LocalMod, Bool) -> Void
    public let onToggleSelection: ([LocalMod]) -> Void
    public let onRequestDelete: ([LocalMod]) -> Void
    public let onOpenDetails: (LocalMod) -> Void
    public let onOpenPortal: (LocalMod) -> Void
    public let onOpenAuthor: (LocalMod) -> Void
    public let onRevealInFinder: ([LocalMod]) -> Void
    public let onChangeSort: (String, Bool) -> Void

    public final class Coordinator: NSObject, NativeModTableViewDelegate {
        var parent: NativeModTableViewRepresentable

        init(_ parent: NativeModTableViewRepresentable) {
            self.parent = parent
        }

        public func modTableView(_ view: NativeModTableViewNSView, didToggleMod mod: LocalMod, newState: Bool) {
            parent.onToggleMod(mod, newState)
        }

        public func modTableView(_ view: NativeModTableViewNSView, didToggleSelection mods: [LocalMod]) {
            parent.onToggleSelection(mods)
        }

        public func modTableView(_ view: NativeModTableViewNSView, didRequestDelete mods: [LocalMod]) {
            parent.onRequestDelete(mods)
        }

        public func modTableView(_ view: NativeModTableViewNSView, didOpenDetails mod: LocalMod) {
            parent.onOpenDetails(mod)
        }

        public func modTableView(_ view: NativeModTableViewNSView, didOpenPortal mod: LocalMod) {
            parent.onOpenPortal(mod)
        }

        public func modTableView(_ view: NativeModTableViewNSView, didOpenAuthor mod: LocalMod) {
            parent.onOpenAuthor(mod)
        }

        public func modTableView(_ view: NativeModTableViewNSView, didRevealInFinder mods: [LocalMod]) {
            parent.onRevealInFinder(mods)
        }

        public func modTableView(_ view: NativeModTableViewNSView, didChangeSort columnIdentifier: String, ascending: Bool) {
            parent.onChangeSort(columnIdentifier, ascending)
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> NativeModTableViewNSView {
        let view = NativeModTableViewNSView()
        view.delegate = context.coordinator
        view.mods = mods
        view.modPortalOwners = modPortalOwners
        view.enabledStates = enabledStates
        return view
    }

    public func updateNSView(_ nsView: NativeModTableViewNSView, context: Context) {
        context.coordinator.parent = self
        nsView.delegate = context.coordinator
        nsView.modPortalOwners = modPortalOwners
        nsView.enabledStates = enabledStates
        if nsView.mods != mods {
            nsView.mods = mods
        } else {
            nsView.tableView.reloadData()
        }
    }
}
