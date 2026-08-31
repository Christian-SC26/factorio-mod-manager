import AppKit
import SwiftUI

public enum ModTableRowItem: Equatable {
    case groupHeader(String)
    case mod(LocalMod)

    public var modValue: LocalMod? {
        if case let .mod(m) = self { return m }
        return nil
    }

    public var isGroupHeader: Bool {
        if case .groupHeader = self { return true }
        return false
    }
}

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
    public var currentItems: [ModTableRowItem] = []

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
            let selected = selectedMods().filter { $0.name != "base" && !isOfficialMod($0.name) }
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
                let nonOfficial = selected.filter { !isOfficialMod($0.name) }
                if !nonOfficial.isEmpty {
                    actionDelegate?.modTableView(enclosingView, didRevealInFinder: nonOfficial)
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
            case "f":
                NotificationCenter.default.post(name: .focusModSearch, object: nil)
                return
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

    private func isOfficialMod(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower == "base" || lower == "space-age" || lower == "quality" || lower == "elevated-rails" || lower == "recycler"
    }

    private var enclosingView: NativeModTableViewNSView {
        (superview?.superview as? NativeModTableViewNSView) ?? NativeModTableViewNSView()
    }

    public func selectedMods() -> [LocalMod] {
        let indices = selectedRowIndexes.filter { $0 >= 0 && $0 < currentItems.count }
        return indices.compactMap { currentItems[$0].modValue }
    }

    private func moveRowSelection(delta: Int, extend: Bool) {
        guard !currentItems.isEmpty else { return }
        let current = selectedRow >= 0 ? selectedRow : 0
        var target = current + delta

        // Skip headers if needed
        while target >= 0 && target < currentItems.count && currentItems[target].isGroupHeader {
            target += (delta >= 0 ? 1 : -1)
        }

        target = min(max(0, target), currentItems.count - 1)
        if currentItems[target].isGroupHeader { return }

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

    public var officialMods: [LocalMod] = [] {
        didSet { rebuildItems() }
    }
    public var communityMods: [LocalMod] = [] {
        didSet { rebuildItems() }
    }
    public var modPortalOwners: [String: String] = [:]
    public var enabledStates: [String: Bool] = [:]
    public var updatesAvailableMap: [String: ModUpdateItem] = [:] {
        didSet { tableView.reloadData() }
    }

    private var tableItems: [ModTableRowItem] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFocusTableNotification),
            name: .focusModTable,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFocusTableNotification),
            name: .focusModTable,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleFocusTableNotification() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.window?.makeFirstResponder(self.tableView)
            if self.tableView.selectedRow < 0 && !self.tableItems.isEmpty {
                let firstModIdx = self.tableItems.firstIndex(where: { if case .mod = $0 { return true } else { return false } }) ?? 0
                self.tableView.selectRowIndexes(IndexSet(integer: firstModIdx), byExtendingSelection: false)
            }
        }
    }

    private func rebuildItems() {
        var items: [ModTableRowItem] = []

        if !officialMods.isEmpty {
            items.append(.groupHeader("OFFICIAL FACTORIO CONTENT & EXPANSIONS"))
            for m in officialMods {
                items.append(.mod(m))
            }
        }

        if !communityMods.isEmpty {
            if !officialMods.isEmpty {
                items.append(.groupHeader("INSTALLED COMMUNITY MODS (\(communityMods.count))"))
            }
            for m in communityMods {
                items.append(.mod(m))
            }
        }

        self.tableItems = items
        self.tableView.currentItems = items
        self.tableView.reloadData()
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
        colDate.width = 95
        colDate.minWidth = 80
        colDate.maxWidth = 130
        colDate.sortDescriptorPrototype = NSSortDescriptor(key: "dateSortKey", ascending: false)
        tableView.addTableColumn(colDate)

        let colGameVer = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("game_ver"))
        colGameVer.title = "Game Ver"
        colGameVer.width = 68
        colGameVer.minWidth = 58
        colGameVer.maxWidth = 85
        colGameVer.sortDescriptorPrototype = NSSortDescriptor(key: "factorioVersion", ascending: false)
        tableView.addTableColumn(colGameVer)

        let colVersion = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("version"))
        colVersion.title = "Version"
        colVersion.width = 110
        colVersion.minWidth = 85
        colVersion.maxWidth = 145
        colVersion.sortDescriptorPrototype = NSSortDescriptor(key: "version.raw", ascending: false)
        tableView.addTableColumn(colVersion)

        let colSize = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("size"))
        colSize.title = "Size"
        colSize.width = 70
        colSize.minWidth = 55
        colSize.maxWidth = 90
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
        tableItems.count
    }

    public func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        guard row >= 0 && row < tableItems.count else { return false }
        return tableItems[row].isGroupHeader
    }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0 && row < tableItems.count else { return nil }
        let item = tableItems[row]

        // Handle Group Header Row
        if case let .groupHeader(title) = item {
            var cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("groupHeader"), owner: self) as? NSTableCellView
            if cell == nil {
                cell = NSTableCellView()
                cell?.identifier = NSUserInterfaceItemIdentifier("groupHeader")
                let tf = NSTextField(labelWithString: "")
                tf.font = .systemFont(ofSize: 11, weight: .bold)
                tf.textColor = .secondaryLabelColor
                tf.translatesAutoresizingMaskIntoConstraints = false
                cell?.addSubview(tf)
                NSLayoutConstraint.activate([
                    tf.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 6),
                    tf.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -6),
                    tf.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
                ])
            }
            let tf = cell?.subviews.first as? NSTextField
            tf?.stringValue = title
            return cell
        }

        guard case let .mod(mod) = item, let col = tableColumn else { return nil }
        let isEnabled = enabledStates[mod.name] ?? mod.enabled
        let isOfficial = isOfficialMod(mod.name)
        let identifier = col.identifier

        var cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = identifier
        }
        guard let cellView = cell else { return nil }

        // Remove old subviews
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
            sw.isEnabled = (mod.name != "base") // Base mod is always locked enabled
            sw.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(sw)
            NSLayoutConstraint.activate([
                sw.centerXAnchor.constraint(equalTo: cellView.centerXAnchor),
                sw.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])

        case "name":
            let tf = NSTextField(labelWithString: mod.displayTitle)
            tf.font = .systemFont(ofSize: 13, weight: isOfficial ? .semibold : .medium)
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
            let hasPortal = !isOfficial && (mod.portalAuthorURL(portalOwner: modPortalOwners[mod.name]) != nil)

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
            let dateString = isOfficial ? "Built-in" : mod.formattedDate
            let tf = NSTextField(labelWithString: dateString)
            tf.font = .systemFont(ofSize: 12)
            tf.textColor = .secondaryLabelColor
            tf.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(tf)
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cellView.leadingAnchor),
                tf.trailingAnchor.constraint(equalTo: cellView.trailingAnchor),
                tf.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])

        case "game_ver":
            let tf = NSTextField(labelWithString: mod.factorioVersion)
            tf.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            tf.textColor = .secondaryLabelColor
            tf.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(tf)
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cellView.leadingAnchor),
                tf.trailingAnchor.constraint(equalTo: cellView.trailingAnchor),
                tf.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])

        case "version":
            let tf = NSTextField()
            tf.isEditable = false
            tf.isBordered = false
            tf.drawsBackground = false
            tf.translatesAutoresizingMaskIntoConstraints = false

            if let update = updatesAvailableMap[mod.name] {
                let attr = NSMutableAttributedString()
                let currentStr = NSAttributedString(
                    string: mod.version.raw,
                    attributes: [
                        .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
                        .foregroundColor: NSColor.secondaryLabelColor
                    ]
                )
                let arrowStr = NSAttributedString(
                    string: " → ",
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 11, weight: .bold),
                        .foregroundColor: NSColor.systemGreen
                    ]
                )
                let nextStr = NSAttributedString(
                    string: update.remoteVersion.raw,
                    attributes: [
                        .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .bold),
                        .foregroundColor: NSColor.systemGreen
                    ]
                )
                attr.append(currentStr)
                attr.append(arrowStr)
                attr.append(nextStr)
                tf.attributedStringValue = attr
                tf.toolTip = "Update available: \(mod.version.raw) → \(update.remoteVersion.raw)"
            } else {
                tf.stringValue = mod.version.raw
                tf.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
                tf.textColor = .secondaryLabelColor
            }

            cellView.addSubview(tf)
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cellView.leadingAnchor),
                tf.trailingAnchor.constraint(equalTo: cellView.trailingAnchor),
                tf.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])

        case "size":
            let sizeString = isOfficial ? "Built-in" : (mod.fileSize > 0 ? formatBytes(mod.fileSize) : "—")
            let tf = NSTextField(labelWithString: sizeString)
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

            // Safari (Portal link)
            let bSafari = NSButton(image: NSImage(systemSymbolName: "safari", accessibilityDescription: "Portal") ?? NSImage(), target: self, action: #selector(portalClicked(_:)))
            bSafari.tag = row
            bSafari.isBordered = false
            bSafari.contentTintColor = isOfficial ? .secondaryLabelColor.withAlphaComponent(0.4) : .controlAccentColor
            bSafari.toolTip = isOfficial ? "Official content" : "Open on Factorio Portal (⌘L)"
            bSafari.isEnabled = !isOfficial
            stack.addArrangedSubview(bSafari)

            // Info Details
            let bInfo = NSButton(image: NSImage(systemSymbolName: "info.circle", accessibilityDescription: "Details") ?? NSImage(), target: self, action: #selector(detailsClicked(_:)))
            bInfo.tag = row
            bInfo.isBordered = false
            bInfo.contentTintColor = .secondaryLabelColor
            bInfo.toolTip = "Mod Details (⌘I)"
            stack.addArrangedSubview(bInfo)

            // Folder (Reveal in Finder)
            if !isOfficial {
                let bFolder = NSButton(image: NSImage(systemSymbolName: "folder", accessibilityDescription: "Finder") ?? NSImage(), target: self, action: #selector(revealClicked(_:)))
                bFolder.tag = row
                bFolder.isBordered = false
                bFolder.contentTintColor = .secondaryLabelColor
                bFolder.toolTip = "Reveal in Finder (⌘O)"
                stack.addArrangedSubview(bFolder)

                let bTrash = NSButton(image: NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete") ?? NSImage(), target: self, action: #selector(deleteClicked(_:)))
                bTrash.tag = row
                bTrash.isBordered = false
                bTrash.contentTintColor = .systemRed.withAlphaComponent(0.8)
                bTrash.toolTip = "Delete Mod (⌫)"
                stack.addArrangedSubview(bTrash)
            }

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

    private func isOfficialMod(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower == "base" || lower == "space-age" || lower == "quality" || lower == "elevated-rails" || lower == "recycler"
    }

    public func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let first = tableView.sortDescriptors.first, let key = first.key else { return }
        delegate?.modTableView(self, didChangeSort: key, ascending: first.ascending)
    }

    // MARK: - Actions
    @objc private func switchToggled(_ sender: NSSwitch) {
        let row = sender.tag
        guard row >= 0 && row < tableItems.count, case let .mod(mod) = tableItems[row] else { return }
        let newState = sender.state == .on
        delegate?.modTableView(self, didToggleMod: mod, newState: newState)
    }

    @objc private func authorClicked(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0 && row < tableItems.count, case let .mod(mod) = tableItems[row] else { return }
        delegate?.modTableView(self, didOpenAuthor: mod)
    }

    @objc private func portalClicked(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0 && row < tableItems.count, case let .mod(mod) = tableItems[row] else { return }
        delegate?.modTableView(self, didOpenPortal: mod)
    }

    @objc private func detailsClicked(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0 && row < tableItems.count, case let .mod(mod) = tableItems[row] else { return }
        delegate?.modTableView(self, didOpenDetails: mod)
    }

    @objc private func revealClicked(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0 && row < tableItems.count, case let .mod(mod) = tableItems[row] else { return }
        delegate?.modTableView(self, didRevealInFinder: [mod])
    }

    @objc private func deleteClicked(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0 && row < tableItems.count, case let .mod(mod) = tableItems[row] else { return }
        delegate?.modTableView(self, didRequestDelete: [mod])
    }
}

public struct NativeModTableViewRepresentable: NSViewRepresentable {
    public let officialMods: [LocalMod]
    public let communityMods: [LocalMod]
    public let modPortalOwners: [String: String]
    public let enabledStates: [String: Bool]
    public let updatesAvailableMap: [String: ModUpdateItem]
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
        view.officialMods = officialMods
        view.communityMods = communityMods
        view.modPortalOwners = modPortalOwners
        view.enabledStates = enabledStates
        view.updatesAvailableMap = updatesAvailableMap
        return view
    }

    public func updateNSView(_ nsView: NativeModTableViewNSView, context: Context) {
        context.coordinator.parent = self
        nsView.delegate = context.coordinator

        var needsReload = false

        if nsView.officialMods != officialMods || nsView.communityMods != communityMods {
            nsView.officialMods = officialMods
            nsView.communityMods = communityMods
            needsReload = false
        }

        if nsView.modPortalOwners != modPortalOwners {
            nsView.modPortalOwners = modPortalOwners
            needsReload = true
        }

        if nsView.enabledStates != enabledStates {
            nsView.enabledStates = enabledStates
            needsReload = true
        }

        if nsView.updatesAvailableMap != updatesAvailableMap {
            nsView.updatesAvailableMap = updatesAvailableMap
            needsReload = true
        }

        if needsReload {
            nsView.tableView.reloadData()
        }
    }
}
