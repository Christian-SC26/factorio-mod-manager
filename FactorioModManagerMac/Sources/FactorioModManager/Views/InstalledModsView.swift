import SwiftUI
import AppKit

public struct AuthorCellView: View {
    public let mod: LocalMod
    public let portalOwner: String?

    public var body: some View {
        let authorDisplay = portalOwner ?? mod.cleanAuthorName
        let portalURL = mod.portalAuthorURL(portalOwner: portalOwner)

        if let url = portalURL {
            Button(action: {
                NSWorkspace.shared.open(url)
            }) {
                Text(authorDisplay)
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .help("Open \(authorDisplay)'s portal page (⌘A)")
        } else {
            Text(authorDisplay)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

public struct InstalledModsView: View {
    @ObservedObject var appState: AppState
    @State private var filterMode: Int = 0 // 0: All, 1: Enabled, 2: Disabled
    @State private var searchText: String = ""
    @State private var selectedModIDs: Set<String> = []
    @State private var selectionAnchorIndex: Int = 0
    @State private var sortOrder = [KeyPathComparator(\LocalMod.displayTitle, order: .forward)]
    @State private var eventMonitor: Any? = nil
    @FocusState private var isSearchFocused: Bool

    // Deletion confirmation state
    @State private var modsPendingDeletion: [LocalMod] = []
    @State private var brokenDependenciesForPendingDeletion: [BrokenDependencyInfo] = []
    @State private var showSimpleDeleteConfirmation: Bool = false
    @State private var showDependencyDeleteConfirmation: Bool = false

    private var enabledCount: Int {
        appState.installedMods.filter { $0.enabled }.count
    }

    private var disabledCount: Int {
        appState.installedMods.filter { !$0.enabled }.count
    }

    private var filteredAndSortedMods: [LocalMod] {
        var list = appState.installedMods

        // Filter by status
        if filterMode == 1 {
            list = list.filter { $0.enabled }
        } else if filterMode == 2 {
            list = list.filter { !$0.enabled }
        }

        // Filter by search query
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            let owners = appState.modPortalOwners
            list = list.filter {
                $0.name.lowercased().contains(query)
                || $0.displayTitle.lowercased().contains(query)
                || $0.author.lowercased().contains(query)
                || $0.summary.lowercased().contains(query)
                || (owners[$0.name]?.lowercased().contains(query) ?? false)
            }
        }

        list.sort(using: sortOrder)
        return list
    }

    private func getSelectedMods() -> [LocalMod] {
        let mods = filteredAndSortedMods
        let list = mods.filter { selectedModIDs.contains($0.id) }
        if !list.isEmpty { return list }
        if let window = NSApp.keyWindow ?? NSApp.mainWindow,
           let tableView = findTableView(in: window.contentView),
           tableView.selectedRow >= 0, tableView.selectedRow < mods.count {
            return [mods[tableView.selectedRow]]
        }
        return []
    }

    private func moveSelection(by delta: Int, extendRange: Bool) {
        let mods = filteredAndSortedMods
        guard !mods.isEmpty else { return }

        DispatchQueue.main.async {
            if let window = NSApp.keyWindow ?? NSApp.mainWindow,
               let tableView = findTableView(in: window.contentView) {
                let current = tableView.selectedRow >= 0 ? tableView.selectedRow : selectionAnchorIndex
                let target = min(max(0, current + delta), mods.count - 1)

                if extendRange {
                    let start = min(selectionAnchorIndex, target)
                    let end = max(selectionAnchorIndex, target)
                    let indexSet = IndexSet(integersIn: start...end)
                    tableView.selectRowIndexes(indexSet, byExtendingSelection: false)
                    tableView.scrollRowToVisible(target)
                    selectedModIDs = Set(mods[start...end].map(\.id))
                } else {
                    selectionAnchorIndex = target
                    tableView.selectRowIndexes(IndexSet(integer: target), byExtendingSelection: false)
                    tableView.scrollRowToVisible(target)
                    selectedModIDs = [mods[target].id]
                }
            }
        }
    }

    private func findTableView(in view: NSView?) -> NSTableView? {
        guard let view = view else { return nil }
        if let tv = view as? NSTableView {
            tv.selectionHighlightStyle = .regular
            return tv
        }
        for sub in view.subviews {
            if let found = findTableView(in: sub) {
                return found
            }
        }
        return nil
    }

    private func toggleSelectedMods() {
        let targets = getSelectedMods()
        guard !targets.isEmpty else { return }
        appState.toggleMods(targets)
    }

    private func initiateDeletion(for targets: [LocalMod]) {
        guard !targets.isEmpty else { return }
        modsPendingDeletion = targets
        let targetNames = Set(targets.map(\.name))
        let broken = appState.checkBrokenDependencies(forDeletedModNames: targetNames)
        brokenDependenciesForPendingDeletion = broken

        if broken.isEmpty {
            showSimpleDeleteConfirmation = true
        } else {
            showDependencyDeleteConfirmation = true
        }
    }

    private func sortByColumn(_ index: Int) {
        switch index {
        case 1:
            let isForward = sortOrder.first?.keyPath == \LocalMod.enabledSortKey && sortOrder.first?.order == .forward
            sortOrder = [KeyPathComparator(\LocalMod.enabledSortKey, order: isForward ? .reverse : .forward)]
        case 2:
            let isForward = sortOrder.first?.keyPath == \LocalMod.displayTitle && sortOrder.first?.order == .forward
            sortOrder = [KeyPathComparator(\LocalMod.displayTitle, order: isForward ? .reverse : .forward)]
        case 3:
            let isForward = sortOrder.first?.keyPath == \LocalMod.author && sortOrder.first?.order == .forward
            sortOrder = [KeyPathComparator(\LocalMod.author, order: isForward ? .reverse : .forward)]
        case 4:
            let isForward = sortOrder.first?.keyPath == \LocalMod.dateSortKey && sortOrder.first?.order == .forward
            sortOrder = [KeyPathComparator(\LocalMod.dateSortKey, order: isForward ? .reverse : .forward)]
        case 5:
            let isForward = sortOrder.first?.keyPath == \LocalMod.version.raw && sortOrder.first?.order == .forward
            sortOrder = [KeyPathComparator(\LocalMod.version.raw, order: isForward ? .reverse : .forward)]
        case 6:
            let isForward = sortOrder.first?.keyPath == \LocalMod.fileSize && sortOrder.first?.order == .forward
            sortOrder = [KeyPathComparator(\LocalMod.fileSize, order: isForward ? .reverse : .forward)]
        default:
            break
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header & Controls
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc("installed_title"))
                            .font(.title2.bold())
                        Text(String(format: loc("total_mods_summary"), appState.installedMods.count, enabledCount, disabledCount))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Button(action: {
                            Task { await appState.checkForUpdates() }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text(loc("check_updates"))
                            }
                        }
                        .disabled(appState.isCheckingUpdates)

                        Button(action: {
                            NSWorkspace.shared.open(appState.modsDirectory)
                        }) {
                            Label(loc("open_mods_folder"), systemImage: "folder")
                        }

                        Menu {
                            Button(loc("enable_all"), action: { appState.enableAllMods() })
                            Button(loc("disable_all"), action: { appState.disableAllMods() })
                            Divider()
                            let targets = getSelectedMods()
                            if !targets.isEmpty {
                                Button(role: .destructive, action: {
                                    initiateDeletion(for: targets)
                                }) {
                                    Text("\(loc("delete_selected")) (\(targets.count))")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }

                // Filter & Search Bar with keyboard shortcut hints
                HStack(spacing: 10) {
                    Picker("", selection: $filterMode) {
                        Text("\(loc("filter_all")) (\(appState.installedMods.count))").tag(0)
                        Text("\(loc("filter_enabled")) (\(enabledCount))").tag(1)
                        Text("\(loc("filter_disabled")) (\(disabledCount))").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)

                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField(loc("search_mods_placeholder"), text: $searchText)
                            .textFieldStyle(.plain)
                            .focused($isSearchFocused)

                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text("⌘F")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary.opacity(0.6))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    // Keyboard shortcuts tip
                    HStack(spacing: 4) {
                        Text("j/k: nav")
                        Text("•")
                        Text("⇧j/k: range")
                        Text("•")
                        Text("space: toggle")
                        Text("•")
                        Text("del: delete")
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.8))
                }
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Finder-Style Native Table with Multi-Selection, Plain Version, and Fast Virtualization
            if filteredAndSortedMods.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "archivebox")
                        .font(.system(size: 42))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text(loc("no_mods_installed"))
                        .font(.headline)
                    Text(loc("no_mods_installed_desc"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(filteredAndSortedMods, selection: $selectedModIDs, sortOrder: $sortOrder) {
                    // Column 1: On / Off Switch (System color preserved)
                    TableColumn("Active", value: \.enabledSortKey) { mod in
                        Toggle("", isOn: Binding(
                            get: { mod.enabled },
                            set: { _ in appState.toggleModEnabled(mod) }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                        .tint(.accentColor)
                    }
                    .width(min: 44, ideal: 50, max: 58)

                    // Column 2: Clean Human Title (No box icon)
                    TableColumn("Mod Name", value: \.displayTitle) { mod in
                        Text(mod.displayTitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(mod.enabled ? .primary : .secondary)
                            .lineLimit(1)
                    }
                    .width(min: 180, ideal: 260)

                    // Column 3: Author (Clickable Link to portal user profile)
                    TableColumn("Author", value: \.author) { mod in
                        AuthorCellView(mod: mod, portalOwner: appState.modPortalOwners[mod.name])
                    }
                    .width(min: 90, ideal: 130, max: 190)

                    // Column 4: Date Added
                    TableColumn("Date Added", value: \.dateSortKey) { mod in
                        Text(mod.formattedDate)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .width(min: 85, ideal: 110, max: 140)

                    // Column 5: Version (Pure numbers, no badge, no 'v')
                    TableColumn("Version", value: \.version.raw) { mod in
                        Text(mod.version.raw)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .width(min: 70, ideal: 80, max: 100)

                    // Column 6: Size
                    TableColumn("Size", value: \.fileSize) { mod in
                        Text(mod.fileSize > 0 ? formatBytes(mod.fileSize) : "—")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .width(min: 70, ideal: 80, max: 100)

                    // Column 7: Actions (Portal link, Details, Reveal, Delete)
                    TableColumn("Actions") { mod in
                        HStack(spacing: 8) {
                            // Link to mod portal page (⌘L)
                            Button(action: {
                                if let url = URL(string: "https://mods.factorio.com/mod/\(mod.name)") {
                                    NSWorkspace.shared.open(url)
                                }
                            }) {
                                Image(systemName: "safari")
                                    .font(.system(size: 12))
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                            .help("Open on Factorio Portal (⌘L)")

                            // Mod details sheet (⌘I)
                            Button(action: {
                                appState.openModDetails(for: mod)
                            }) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Mod Details (⌘I)")

                            // Reveal in Finder (⌘O)
                            Button(action: {
                                NSWorkspace.shared.activateFileViewerSelecting([mod.fileURL])
                            }) {
                                Image(systemName: "folder")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Reveal in Finder (⌘O)")

                            // Delete mod archive (⌫)
                            Button(action: {
                                initiateDeletion(for: [mod])
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                    .foregroundColor(.red.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                            .help("Delete Mod (⌫)")
                        }
                    }
                    .width(min: 105, ideal: 120, max: 140)
                }
                .tableStyle(.inset(alternatesRowBackgrounds: true))
                .contextMenu {
                    let targets = getSelectedMods()
                    if !targets.isEmpty {
                        let anyEnabled = targets.contains { $0.enabled }
                        Button(anyEnabled ? loc("filter_disabled") : loc("filter_enabled")) {
                            appState.toggleMods(targets)
                        }

                        if targets.count == 1, let mod = targets.first {
                            Button("Mod Details (⌘I)") {
                                appState.openModDetails(for: mod)
                            }
                            if let url = URL(string: "https://mods.factorio.com/mod/\(mod.name)") {
                                Button("Open on Portal (⌘L)") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            let portalOwner = appState.modPortalOwners[mod.name]
                            if let authorUrl = mod.portalAuthorURL(portalOwner: portalOwner) {
                                Button("Open Author Profile (⌘A)") {
                                    NSWorkspace.shared.open(authorUrl)
                                }
                            }
                            Button("Reveal in Finder (⌘O)") {
                                NSWorkspace.shared.activateFileViewerSelecting([mod.fileURL])
                            }
                        }

                        Divider()
                        Button(role: .destructive) {
                            initiateDeletion(for: targets)
                        } label: {
                            Text("\(loc("delete_selected")) (\(targets.count))")
                        }
                    }
                }
            }
        }
        .onAppear {
            if selectedModIDs.isEmpty, let firstID = filteredAndSortedMods.first?.id {
                selectedModIDs = [firstID]
            }
            if eventMonitor == nil {
                setupKeyboardMonitor()
            }
        }
        .onDisappear {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
        }
        // Simple Deletion Confirmation (No broken dependencies)
        .confirmationDialog(
            loc("confirm_delete_title"),
            isPresented: $showSimpleDeleteConfirmation
        ) {
            Button(loc("delete_selected"), role: .destructive) {
                appState.deleteMods(modsPendingDeletion)
                selectedModIDs.removeAll()
            }
            Button(loc("cancel"), role: .cancel) {}
        } message: {
            if modsPendingDeletion.count == 1, let single = modsPendingDeletion.first {
                Text(String(format: loc("confirm_delete_message"), single.displayTitle))
            } else {
                Text(String(format: loc("confirm_delete_multiple"), modsPendingDeletion.count))
            }
        }
        // Smart Dependency Deletion Warning Modal
        .sheet(isPresented: $showDependencyDeleteConfirmation) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.red)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Dependency Conflict Detected")
                            .font(.title3.bold())
                        Text("Deleting \(modsPendingDeletion.count) mod(s) will break \(brokenDependenciesForPendingDeletion.count) dependent mod(s).")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: { showDependencyDeleteConfirmation = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(18)
                .background(Color(NSColor.windowBackgroundColor))

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Mods to be deleted:")
                                .font(.headline)
                            ForEach(modsPendingDeletion) { mod in
                                Text("• \(mod.displayTitle) (\(mod.name))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Active mods that depend on them and will fail to load:")
                                .font(.headline)
                                .foregroundColor(.red)

                            ForEach(brokenDependenciesForPendingDeletion) { info in
                                HStack {
                                    Text("• \(info.dependentMod.displayTitle)")
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text("requires \(info.brokenDependencyName)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        Text("Recommended Action: Delete the mod(s) and automatically disable dependent mods so Factorio can launch safely without crashing.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(18)
                }

                Divider()

                HStack(spacing: 12) {
                    Button(loc("cancel")) {
                        showDependencyDeleteConfirmation = false
                    }

                    Spacer()

                    Button("Delete Anyway", role: .destructive) {
                        showDependencyDeleteConfirmation = false
                        appState.deleteMods(modsPendingDeletion)
                        selectedModIDs.removeAll()
                    }

                    Button("Delete & Disable Dependent Mods") {
                        showDependencyDeleteConfirmation = false
                        let dependentList = Array(Set(brokenDependenciesForPendingDeletion.map(\.dependentMod)))
                        appState.deleteModsAndDisableDependents(mods: modsPendingDeletion, dependentMods: dependentList)
                        selectedModIDs.removeAll()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(16)
                .background(Color(NSColor.windowBackgroundColor))
            }
            .frame(minWidth: 540, minHeight: 400)
        }
    }

    private func setupKeyboardMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let isCmd = event.modifierFlags.contains(.command)
            let isShift = event.modifierFlags.contains(.shift)
            let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""

            // Handle Cmd + F to focus search
            if isCmd && chars == "f" {
                DispatchQueue.main.async {
                    self.isSearchFocused = true
                }
                return nil
            }

            // Handle Cmd + 1..6 for Column Sorting
            if isCmd {
                if let num = Int(chars), num >= 1 && num <= 6 {
                    DispatchQueue.main.async {
                        self.sortByColumn(num)
                    }
                    return nil
                }
            }

            // If user is currently typing in search field, let normal typing proceed
            if self.isSearchFocused {
                if event.keyCode == 53 { // Escape
                    DispatchQueue.main.async {
                        self.isSearchFocused = false
                    }
                    return nil
                }
                return event
            }

            // Delete / Backspace key (keyCode 51 = Delete/Backspace, keyCode 117 = Forward Delete)
            if event.keyCode == 51 || event.keyCode == 117 {
                let targets = self.getSelectedMods()
                if !targets.isEmpty {
                    DispatchQueue.main.async {
                        self.initiateDeletion(for: targets)
                    }
                    return nil
                }
            }

            // Actions for the currently selected mod with Command key
            if isCmd {
                let targets = self.getSelectedMods()
                let currentMod = targets.first
                switch chars {
                case "l": // Open mod page on portal (⌘L)
                    if let mod = currentMod, let url = URL(string: "https://mods.factorio.com/mod/\(mod.name)") {
                        NSWorkspace.shared.open(url)
                        return nil
                    }
                case "o": // Reveal in Finder (⌘O)
                    if !targets.isEmpty {
                        let urls = targets.map(\.fileURL)
                        NSWorkspace.shared.activateFileViewerSelecting(urls)
                        return nil
                    }
                case "a": // Open author page on portal (⌘A)
                    if let mod = currentMod {
                        let portalOwner = self.appState.modPortalOwners[mod.name]
                        if let url = mod.portalAuthorURL(portalOwner: portalOwner) {
                            NSWorkspace.shared.open(url)
                            return nil
                        }
                    }
                case "i": // Open mod info details sheet (⌘I)
                    if let mod = currentMod {
                        DispatchQueue.main.async {
                            self.appState.openModDetails(for: mod)
                        }
                        return nil
                    }
                default:
                    break
                }
            }

            // Global navigation keys: J (Down), K (Up), Space (Toggle)
            if !isCmd {
                switch chars {
                case "j":
                    self.moveSelection(by: 1, extendRange: isShift)
                    return nil
                case "k":
                    self.moveSelection(by: -1, extendRange: isShift)
                    return nil
                case " ":
                    self.toggleSelectedMods()
                    return nil
                default:
                    break
                }
            }

            return event
        }
    }
}
