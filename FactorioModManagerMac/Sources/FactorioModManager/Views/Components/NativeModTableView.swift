import AppKit
import SwiftUI

// MARK: - Table Row Models
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

// MARK: - Delegate Protocol
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

// MARK: - Static Image Cache for Instant Zero-Alloc Rendering
private enum ModTableImages {
    static let safari: NSImage = {
        let img = NSImage(systemSymbolName: "safari", accessibilityDescription: "Portal") ?? NSImage()
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        let configured = img.withSymbolConfiguration(config) ?? img
        configured.isTemplate = true
        return configured
    }()
    static let info: NSImage = {
        let img = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "Details") ?? NSImage()
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        let configured = img.withSymbolConfiguration(config) ?? img
        configured.isTemplate = true
        return configured
    }()
    static let folder: NSImage = {
        let img = NSImage(systemSymbolName: "folder", accessibilityDescription: "Finder") ?? NSImage()
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        let configured = img.withSymbolConfiguration(config) ?? img
        configured.isTemplate = true
        return configured
    }()
    static let trash: NSImage = {
        let img = NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete") ?? NSImage()
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        let configured = img.withSymbolConfiguration(config) ?? img
        configured.isTemplate = true
        return configured
    }()
}

// MARK: - High-Performance Dedicated Cell Views

final class ModGroupHeaderCellView: NSTableCellView {
    let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        label.font = .systemFont(ofSize: 11, weight: .bold)
        label.textColor = .secondaryLabelColor
        label.isBordered = false
        label.drawsBackground = false
        label.isEditable = false
        label.backgroundColor = .clear
        addSubview(label)
        self.textField = label
    }

    override func layout() {
        super.layout()
        let h: CGFloat = 16
        label.frame = NSRect(x: 6, y: max(0, (bounds.height - h) / 2), width: max(0, bounds.width - 12), height: h)
    }

    func configure(title: String) {
        label.stringValue = title
    }
}

final class ModSwitchCellView: NSTableCellView {
    let toggle = NSSwitch()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        toggle.controlSize = .mini
        toggle.sizeToFit()
        addSubview(toggle)
    }

    override func layout() {
        super.layout()
        toggle.sizeToFit()
        let w = toggle.frame.width > 0 ? toggle.frame.width : 28
        let h = toggle.frame.height > 0 ? toggle.frame.height : 16
        toggle.frame = NSRect(
            x: max(0, (bounds.width - w) / 2),
            y: max(0, (bounds.height - h) / 2),
            width: w,
            height: h
        )
    }

    func configure(isEnabled: Bool, isBase: Bool, row: Int, target: AnyObject?, action: Selector) {
        toggle.state = isEnabled ? .on : .off
        toggle.isEnabled = !isBase
        toggle.tag = row
        toggle.target = target
        toggle.action = action
    }
}

final class ModTextCellView: NSTableCellView {
    let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        label.isBordered = false
        label.drawsBackground = false
        label.isEditable = false
        label.lineBreakMode = .byTruncatingTail
        label.backgroundColor = .clear
        addSubview(label)
        self.textField = label
    }

    override func layout() {
        super.layout()
        let h: CGFloat = 18
        label.frame = NSRect(x: 2, y: max(0, (bounds.height - h) / 2), width: max(0, bounds.width - 4), height: h)
    }

    func configure(text: String, font: NSFont, textColor: NSColor, alignment: NSTextAlignment = .left, toolTip: String? = nil) {
        label.stringValue = text
        label.font = font
        label.textColor = textColor
        label.alignment = alignment
        self.toolTip = toolTip
    }
}

final class ModAuthorCellView: NSTableCellView {
    let button = NSButton(title: "", target: nil, action: nil)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        button.isBordered = false
        button.font = .systemFont(ofSize: 12)
        button.alignment = .left
        button.lineBreakMode = .byTruncatingTail
        button.bezelStyle = .regularSquare
        button.imagePosition = .noImage
        button.focusRingType = .none
        addSubview(button)
    }

    override func layout() {
        super.layout()
        let h: CGFloat = 18
        button.frame = NSRect(x: 2, y: max(0, (bounds.height - h) / 2), width: max(0, bounds.width - 4), height: h)
    }

    func configure(author: String, hasPortal: Bool, row: Int, target: AnyObject?, action: Selector) {
        button.title = author
        button.contentTintColor = hasPortal ? .controlAccentColor : .secondaryLabelColor
        button.tag = row
        button.target = target
        button.action = action
    }
}

final class ModVersionCellView: NSTableCellView {
    let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        label.isBordered = false
        label.drawsBackground = false
        label.isEditable = false
        label.lineBreakMode = .byTruncatingTail
        label.backgroundColor = .clear
        addSubview(label)
        self.textField = label
    }

    override func layout() {
        super.layout()
        let h: CGFloat = 18
        label.frame = NSRect(x: 2, y: max(0, (bounds.height - h) / 2), width: max(0, bounds.width - 4), height: h)
    }

    func configure(currentVersion: String, update: ModUpdateItem?) {
        if let update = update {
            let attr = NSMutableAttributedString()
            let currentStr = NSAttributedString(
                string: currentVersion,
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
            label.attributedStringValue = attr
            self.toolTip = "Update available: \(currentVersion) → \(update.remoteVersion.raw)"
        } else {
            label.stringValue = currentVersion
            label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            label.textColor = .secondaryLabelColor
            self.toolTip = nil
        }
    }
}

final class ModActionsCellView: NSTableCellView {
    let bSafari = NSButton()
    let bInfo = NSButton()
    let bFolder = NSButton()
    let bTrash = NSButton()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        let buttons = [
            (bSafari, ModTableImages.safari, "Open on Factorio Portal (⌘L)"),
            (bInfo, ModTableImages.info, "Mod Details (⌘I)"),
            (bFolder, ModTableImages.folder, "Reveal in Finder (⌘O)"),
            (bTrash, ModTableImages.trash, "Delete Mod (⌫)")
        ]
        for (btn, img, tip) in buttons {
            btn.image = img
            btn.isBordered = false
            btn.toolTip = tip
            btn.bezelStyle = .regularSquare
            btn.imagePosition = .imageOnly
            btn.focusRingType = .none
            addSubview(btn)
        }
        bTrash.contentTintColor = .systemRed.withAlphaComponent(0.85)
    }

    override func layout() {
        super.layout()
        let btnWidth: CGFloat = 20
        let btnHeight: CGFloat = 20
        let spacing: CGFloat = 6
        let y = max(0, (bounds.height - btnHeight) / 2)

        var x: CGFloat = 4
        bSafari.frame = NSRect(x: x, y: y, width: btnWidth, height: btnHeight)
        x += btnWidth + spacing
        bInfo.frame = NSRect(x: x, y: y, width: btnWidth, height: btnHeight)
        x += btnWidth + spacing
        bFolder.frame = NSRect(x: x, y: y, width: btnWidth, height: btnHeight)
        x += btnWidth + spacing
        bTrash.frame = NSRect(x: x, y: y, width: btnWidth, height: btnHeight)
    }

    func configure(
        isOfficial: Bool,
        row: Int,
        target: AnyObject?,
        safariAction: Selector,
        infoAction: Selector,
        folderAction: Selector,
        trashAction: Selector
    ) {
        bSafari.tag = row
        bSafari.target = target
        bSafari.action = safariAction
        bSafari.isEnabled = !isOfficial
        bSafari.contentTintColor = isOfficial ? .secondaryLabelColor.withAlphaComponent(0.3) : .controlAccentColor

        bInfo.tag = row
        bInfo.target = target
        bInfo.action = infoAction
        bInfo.contentTintColor = .secondaryLabelColor

        bFolder.tag = row
        bFolder.target = target
        bFolder.action = folderAction
        bFolder.contentTintColor = .secondaryLabelColor
        bFolder.isHidden = isOfficial

        bTrash.tag = row
        bTrash.target = target
        bTrash.action = trashAction
        bTrash.isHidden = isOfficial
    }
}

// MARK: - Custom Native Table View
public final class CustomTableView: NSTableView {
    public weak var actionDelegate: NativeModTableViewDelegate?
    public weak var ownerView: NativeModTableViewNSView?
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
            let selected = selectedMods().filter { $0.name != FactorioConstants.baseModName && !isOfficialMod($0.name) }
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
                selectAll(nil)
                return
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

        // Vim j / k navigation
        if !isCmd && (chars == "j" || chars == "k") {
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

    public override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        if event.clickCount == 2 {
            let point = convert(event.locationInWindow, from: nil)
            let clickedRow = row(at: point)
            if clickedRow >= 0 && clickedRow < currentItems.count, case let .mod(mod) = currentItems[clickedRow] {
                actionDelegate?.modTableView(enclosingView, didOpenDetails: mod)
            }
        }
    }

    public override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        let clickedRow = row(at: point)
        guard clickedRow >= 0 && clickedRow < currentItems.count, case let .mod(mod) = currentItems[clickedRow] else {
            return nil
        }

        if !selectedRowIndexes.contains(clickedRow) {
            selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
        }

        let selected = selectedMods()
        let isOfficial = isOfficialMod(mod.name)
        let menu = NSMenu()

        // Details
        let itemDetails = NSMenuItem(title: "Mod Details...", action: #selector(contextOpenDetails(_:)), keyEquivalent: "i")
        itemDetails.target = self
        itemDetails.representedObject = mod
        menu.addItem(itemDetails)

        // Portal link
        if !isOfficial {
            let itemPortal = NSMenuItem(title: "Open on Portal", action: #selector(contextOpenPortal(_:)), keyEquivalent: "l")
            itemPortal.target = self
            itemPortal.representedObject = mod
            menu.addItem(itemPortal)
        }

        menu.addItem(NSMenuItem.separator())

        // Toggle state
        let itemToggle = NSMenuItem(
            title: selected.count > 1 ? "Toggle Selected Mods" : (mod.enabled ? "Disable Mod" : "Enable Mod"),
            action: #selector(contextToggleMods(_:)),
            keyEquivalent: " "
        )
        itemToggle.target = self
        itemToggle.representedObject = selected
        menu.addItem(itemToggle)

        // Reveal in Finder
        if !isOfficial {
            let itemFinder = NSMenuItem(title: "Reveal in Finder", action: #selector(contextRevealInFinder(_:)), keyEquivalent: "o")
            itemFinder.target = self
            itemFinder.representedObject = selected.filter { !self.isOfficialMod($0.name) }
            menu.addItem(itemFinder)

            menu.addItem(NSMenuItem.separator())

            // Delete
            let itemDelete = NSMenuItem(
                title: selected.count > 1 ? "Delete \(selected.count) Mods..." : "Delete Mod...",
                action: #selector(contextDeleteMods(_:)),
                keyEquivalent: "\u{08}"
            )
            itemDelete.target = self
            itemDelete.representedObject = selected.filter { $0.name != FactorioConstants.baseModName && !self.isOfficialMod($0.name) }
            menu.addItem(itemDelete)
        }

        return menu
    }

    @objc private func contextOpenDetails(_ sender: NSMenuItem) {
        if let mod = sender.representedObject as? LocalMod {
            actionDelegate?.modTableView(enclosingView, didOpenDetails: mod)
        }
    }

    @objc private func contextOpenPortal(_ sender: NSMenuItem) {
        if let mod = sender.representedObject as? LocalMod {
            actionDelegate?.modTableView(enclosingView, didOpenPortal: mod)
        }
    }

    @objc private func contextToggleMods(_ sender: NSMenuItem) {
        if let mods = sender.representedObject as? [LocalMod], !mods.isEmpty {
            actionDelegate?.modTableView(enclosingView, didToggleSelection: mods)
        }
    }

    @objc private func contextRevealInFinder(_ sender: NSMenuItem) {
        if let mods = sender.representedObject as? [LocalMod], !mods.isEmpty {
            actionDelegate?.modTableView(enclosingView, didRevealInFinder: mods)
        }
    }

    @objc private func contextDeleteMods(_ sender: NSMenuItem) {
        if let mods = sender.representedObject as? [LocalMod], !mods.isEmpty {
            actionDelegate?.modTableView(enclosingView, didRequestDelete: mods)
        }
    }

    private func isOfficialMod(_ name: String) -> Bool {
        FactorioConstants.isOfficialMod(name)
    }

    private var enclosingView: NativeModTableViewNSView {
        ownerView ?? (superview?.superview as? NativeModTableViewNSView) ?? NativeModTableViewNSView()
    }

    public func selectedMods() -> [LocalMod] {
        let indices = selectedRowIndexes.filter { $0 >= 0 && $0 < currentItems.count }
        return indices.compactMap { currentItems[$0].modValue }
    }

    private func moveRowSelection(delta: Int, extend: Bool) {
        guard !currentItems.isEmpty else { return }
        let current = selectedRow >= 0 ? selectedRow : 0
        var target = current + delta

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

// MARK: - Native Table View Container
public final class NativeModTableViewNSView: NSView, NSTableViewDataSource, NSTableViewDelegate {
    public let scrollView = NSScrollView()
    public let tableView = CustomTableView()
    public weak var delegate: NativeModTableViewDelegate? {
        didSet {
            tableView.actionDelegate = delegate
        }
    }

    public var officialMods: [LocalMod] = []
    public var communityMods: [LocalMod] = []
    public var modPortalOwners: [String: String] = [:]
    public var enabledStates: [String: Bool] = [:]
    public var updatesAvailableMap: [String: ModUpdateItem] = [:]

    private var tableItems: [ModTableRowItem] = []

    // Cache identifiers
    private let idGroupHeader = NSUserInterfaceItemIdentifier("groupHeader")
    private let idActive = NSUserInterfaceItemIdentifier("active")
    private let idName = NSUserInterfaceItemIdentifier("name")
    private let idAuthor = NSUserInterfaceItemIdentifier("author")
    private let idDate = NSUserInterfaceItemIdentifier("date")
    private let idGameVer = NSUserInterfaceItemIdentifier("game_ver")
    private let idVersion = NSUserInterfaceItemIdentifier("version")
    private let idSize = NSUserInterfaceItemIdentifier("size")
    private let idActions = NSUserInterfaceItemIdentifier("actions")

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
        tableView.ownerView = self
        tableView.rowHeight = 28
        tableView.usesAutomaticRowHeights = false
        tableView.intercellSpacing = NSSize(width: 12, height: 0)
        tableView.selectionHighlightStyle = .regular
        tableView.focusRingType = .none
        tableView.allowsMultipleSelection = true
        tableView.style = .inset
        tableView.backgroundColor = .clear

        // Columns setup
        let colActive = NSTableColumn(identifier: idActive)
        colActive.title = "Active"
        colActive.width = 46
        colActive.minWidth = 46
        colActive.maxWidth = 46
        colActive.sortDescriptorPrototype = NSSortDescriptor(key: "enabled", ascending: false)
        tableView.addTableColumn(colActive)

        let colName = NSTableColumn(identifier: idName)
        colName.title = "Mod Name"
        colName.width = 240
        colName.minWidth = 180
        colName.sortDescriptorPrototype = NSSortDescriptor(key: "displayTitle", ascending: true)
        tableView.addTableColumn(colName)

        let colAuthor = NSTableColumn(identifier: idAuthor)
        colAuthor.title = "Author"
        colAuthor.width = 120
        colAuthor.minWidth = 80
        colAuthor.maxWidth = 180
        colAuthor.sortDescriptorPrototype = NSSortDescriptor(key: "author", ascending: true)
        tableView.addTableColumn(colAuthor)

        let colDate = NSTableColumn(identifier: idDate)
        colDate.title = "Date Added"
        colDate.width = 95
        colDate.minWidth = 80
        colDate.maxWidth = 130
        colDate.sortDescriptorPrototype = NSSortDescriptor(key: "dateSortKey", ascending: false)
        tableView.addTableColumn(colDate)

        let colGameVer = NSTableColumn(identifier: idGameVer)
        colGameVer.title = "Game Ver"
        colGameVer.width = 68
        colGameVer.minWidth = 58
        colGameVer.maxWidth = 85
        colGameVer.sortDescriptorPrototype = NSSortDescriptor(key: "factorioVersion", ascending: false)
        tableView.addTableColumn(colGameVer)

        let colVersion = NSTableColumn(identifier: idVersion)
        colVersion.title = "Version"
        colVersion.width = 110
        colVersion.minWidth = 85
        colVersion.maxWidth = 145
        colVersion.sortDescriptorPrototype = NSSortDescriptor(key: "version.raw", ascending: false)
        tableView.addTableColumn(colVersion)

        let colSize = NSTableColumn(identifier: idSize)
        colSize.title = "Size"
        colSize.width = 70
        colSize.minWidth = 55
        colSize.maxWidth = 90
        colSize.sortDescriptorPrototype = NSSortDescriptor(key: "fileSize", ascending: false)
        tableView.addTableColumn(colSize)

        let colActions = NSTableColumn(identifier: idActions)
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
            let cell = (tableView.makeView(withIdentifier: idGroupHeader, owner: self) as? ModGroupHeaderCellView)
                ?? ModGroupHeaderCellView(frame: NSRect(x: 0, y: 0, width: tableView.bounds.width, height: 28))
            cell.identifier = idGroupHeader
            cell.configure(title: title)
            return cell
        }

        guard case let .mod(mod) = item, let col = tableColumn else { return nil }
        let isEnabled = enabledStates[mod.name] ?? mod.enabled
        let isOfficial = FactorioConstants.isOfficialMod(mod.name)

        switch col.identifier {
        case idActive:
            let cell = (tableView.makeView(withIdentifier: idActive, owner: self) as? ModSwitchCellView)
                ?? ModSwitchCellView(frame: NSRect(x: 0, y: 0, width: col.width, height: 28))
            cell.identifier = idActive
            cell.configure(
                isEnabled: isEnabled,
                isBase: mod.name == FactorioConstants.baseModName,
                row: row,
                target: self,
                action: #selector(switchToggled(_:))
            )
            return cell

        case idName:
            let cell = (tableView.makeView(withIdentifier: idName, owner: self) as? ModTextCellView)
                ?? ModTextCellView(frame: NSRect(x: 0, y: 0, width: col.width, height: 28))
            cell.identifier = idName
            cell.configure(
                text: mod.displayTitle,
                font: .systemFont(ofSize: 13, weight: isOfficial ? .semibold : .medium),
                textColor: isEnabled ? .labelColor : .secondaryLabelColor,
                toolTip: mod.summary.isEmpty ? nil : mod.summary
            )
            return cell

        case idAuthor:
            let cell = (tableView.makeView(withIdentifier: idAuthor, owner: self) as? ModAuthorCellView)
                ?? ModAuthorCellView(frame: NSRect(x: 0, y: 0, width: col.width, height: 28))
            cell.identifier = idAuthor
            let authorName = modPortalOwners[mod.name] ?? mod.cleanAuthorName
            let hasPortal = !isOfficial && (mod.portalAuthorURL(portalOwner: modPortalOwners[mod.name]) != nil)
            cell.configure(
                author: authorName,
                hasPortal: hasPortal,
                row: row,
                target: self,
                action: #selector(authorClicked(_:))
            )
            return cell

        case idDate:
            let cell = (tableView.makeView(withIdentifier: idDate, owner: self) as? ModTextCellView)
                ?? ModTextCellView(frame: NSRect(x: 0, y: 0, width: col.width, height: 28))
            cell.identifier = idDate
            let dateString = isOfficial ? "Built-in" : mod.formattedDate
            cell.configure(
                text: dateString,
                font: .systemFont(ofSize: 12),
                textColor: .secondaryLabelColor
            )
            return cell

        case idGameVer:
            let cell = (tableView.makeView(withIdentifier: idGameVer, owner: self) as? ModTextCellView)
                ?? ModTextCellView(frame: NSRect(x: 0, y: 0, width: col.width, height: 28))
            cell.identifier = idGameVer
            cell.configure(
                text: mod.factorioVersion,
                font: .monospacedSystemFont(ofSize: 12, weight: .regular),
                textColor: .secondaryLabelColor
            )
            return cell

        case idVersion:
            let cell = (tableView.makeView(withIdentifier: idVersion, owner: self) as? ModVersionCellView)
                ?? ModVersionCellView(frame: NSRect(x: 0, y: 0, width: col.width, height: 28))
            cell.identifier = idVersion
            cell.configure(
                currentVersion: mod.version.raw,
                update: updatesAvailableMap[mod.name]
            )
            return cell

        case idSize:
            let cell = (tableView.makeView(withIdentifier: idSize, owner: self) as? ModTextCellView)
                ?? ModTextCellView(frame: NSRect(x: 0, y: 0, width: col.width, height: 28))
            cell.identifier = idSize
            let sizeString = isOfficial ? "Built-in" : (mod.fileSize > 0 ? Formatters.formatBytes(mod.fileSize) : "—")
            cell.configure(
                text: sizeString,
                font: .monospacedSystemFont(ofSize: 11, weight: .regular),
                textColor: .secondaryLabelColor
            )
            return cell

        case idActions:
            let cell = (tableView.makeView(withIdentifier: idActions, owner: self) as? ModActionsCellView)
                ?? ModActionsCellView(frame: NSRect(x: 0, y: 0, width: col.width, height: 28))
            cell.identifier = idActions
            cell.configure(
                isOfficial: isOfficial,
                row: row,
                target: self,
                safariAction: #selector(portalClicked(_:)),
                infoAction: #selector(detailsClicked(_:)),
                folderAction: #selector(revealClicked(_:)),
                trashAction: #selector(deleteClicked(_:))
            )
            return cell

        default:
            return nil
        }
    }

    public func updateData(
        official: [LocalMod],
        community: [LocalMod],
        portalOwners: [String: String],
        states: [String: Bool],
        updates: [String: ModUpdateItem],
        force: Bool = false
    ) {
        let structureChanged = force || self.tableItems.isEmpty || self.officialMods != official || self.communityMods != community
        let ownersChanged = self.modPortalOwners != portalOwners
        let statesChanged = self.enabledStates != states
        let updatesChanged = self.updatesAvailableMap != updates

        guard structureChanged || ownersChanged || statesChanged || updatesChanged else {
            return
        }

        self.officialMods = official
        self.communityMods = community
        self.modPortalOwners = portalOwners
        self.enabledStates = states
        self.updatesAvailableMap = updates

        if structureChanged {
            rebuildItems()
        } else {
            tableView.reloadData()
        }
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

// MARK: - SwiftUI Representable
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
        view.updateData(
            official: officialMods,
            community: communityMods,
            portalOwners: modPortalOwners,
            states: enabledStates,
            updates: updatesAvailableMap,
            force: true
        )
        return view
    }

    public func updateNSView(_ nsView: NativeModTableViewNSView, context: Context) {
        context.coordinator.parent = self
        nsView.delegate = context.coordinator
        nsView.updateData(
            official: officialMods,
            community: communityMods,
            portalOwners: modPortalOwners,
            states: enabledStates,
            updates: updatesAvailableMap,
            force: false
        )
    }
}
