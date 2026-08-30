import SwiftUI
import AppKit

public struct InstalledModsView: View {
    @ObservedObject var appState: AppState
    @State private var filterMode: Int = 0 // 0: All, 1: Enabled, 2: Disabled
    @State private var searchText: String = ""
    @State private var selectedModID: String? = nil
    @State private var sortOrder = [KeyPathComparator(\LocalMod.displayTitle, order: .forward)]
    @State private var modToDelete: LocalMod? = nil
    @State private var showDeleteConfirmation: Bool = false
    @State private var showBatchDeleteConfirmation: Bool = false
    @FocusState private var isSearchFocused: Bool

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
            list = list.filter {
                $0.name.lowercased().contains(query)
                || $0.displayTitle.lowercased().contains(query)
                || $0.author.lowercased().contains(query)
                || $0.summary.lowercased().contains(query)
            }
        }

        list.sort(using: sortOrder)
        return list
    }

    private func moveSelection(by delta: Int) {
        let mods = filteredAndSortedMods
        guard !mods.isEmpty else { return }

        if let currentID = selectedModID, let currentIndex = mods.firstIndex(where: { $0.id == currentID }) {
            let nextIndex = min(max(0, currentIndex + delta), mods.count - 1)
            selectedModID = mods[nextIndex].id
        } else {
            selectedModID = mods.first?.id
        }
    }

    private func toggleSelectedMod() {
        guard let currentID = selectedModID,
              let mod = appState.installedMods.first(where: { $0.id == currentID }) else { return }
        appState.toggleModEnabled(mod)
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
                            if let selID = selectedModID, let mod = appState.installedMods.first(where: { $0.id == selID }) {
                                Button(role: .destructive, action: {
                                    modToDelete = mod
                                    showDeleteConfirmation = true
                                }) {
                                    Text("\(loc("delete_selected")) ('\(mod.displayTitle)')")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }

                // Filter & Search Bar with keyboard shortcut hint
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
                        Text("j/k: navigate")
                        Text("•")
                        Text("space: toggle")
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.8))
                }
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Finder-Style Native Table with Columns, Sorting, and 120 FPS Virtualization
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
                Table(filteredAndSortedMods, selection: $selectedModID, sortOrder: $sortOrder) {
                    // Column 1: On / Off Switch
                    TableColumn("Active", value: \.enabledSortKey) { mod in
                        Toggle("", isOn: Binding(
                            get: { mod.enabled },
                            set: { _ in appState.toggleModEnabled(mod) }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                    }
                    .width(min: 44, ideal: 50, max: 58)

                    // Column 2: Title / Name
                    TableColumn("Mod Name", value: \.displayTitle) { mod in
                        HStack(spacing: 8) {
                            Image(systemName: mod.isDirectory ? "folder.fill" : "cube.box.fill")
                                .font(.system(size: 14))
                                .foregroundColor(mod.enabled ? .accentColor : .secondary)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(mod.displayTitle)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(mod.enabled ? .primary : .secondary)

                                if mod.displayTitle != mod.name {
                                    Text(mod.name)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .width(min: 180, ideal: 260)

                    // Column 3: Author
                    TableColumn("Author", value: \.author) { mod in
                        Text(mod.author)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .width(min: 90, ideal: 120, max: 180)

                    // Column 4: Date Added
                    TableColumn("Date Added", value: \.dateSortKey) { mod in
                        Text(mod.formattedDate)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .width(min: 85, ideal: 110, max: 140)

                    // Column 5: Version
                    TableColumn("Version", value: \.version.raw) { mod in
                        VersionBadge(mod.version.raw)
                    }
                    .width(min: 75, ideal: 85, max: 110)

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
                            // Link to mod portal page
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
                            .help(loc("open_on_portal"))

                            // Mod details sheet
                            Button(action: {
                                appState.openModDetails(for: mod)
                            }) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help(loc("sidebar_settings"))

                            // Reveal in Finder
                            Button(action: {
                                NSWorkspace.shared.activateFileViewerSelecting([mod.fileURL])
                            }) {
                                Image(systemName: "folder")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help(loc("reveal_in_finder"))

                            // Delete mod archive
                            Button(action: {
                                modToDelete = mod
                                showDeleteConfirmation = true
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                    .foregroundColor(.red.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                            .help(loc("delete_selected"))
                        }
                    }
                    .width(min: 105, ideal: 120, max: 140)
                }
                .tableStyle(.inset(alternatesRowBackgrounds: true))
                .contextMenu {
                    if let selID = selectedModID, let mod = appState.installedMods.first(where: { $0.id == selID }) {
                        Button(mod.enabled ? loc("filter_disabled") : loc("filter_enabled")) {
                            appState.toggleModEnabled(mod)
                        }
                        Button(loc("sidebar_settings")) {
                            appState.openModDetails(for: mod)
                        }
                        if let url = URL(string: "https://mods.factorio.com/mod/\(mod.name)") {
                            Button(loc("open_on_portal")) {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        Button(loc("reveal_in_finder")) {
                            NSWorkspace.shared.activateFileViewerSelecting([mod.fileURL])
                        }
                        Divider()
                        Button(role: .destructive) {
                            modToDelete = mod
                            showDeleteConfirmation = true
                        } label: {
                            Text(loc("delete_selected"))
                        }
                    }
                }
            }
        }
        .onAppear {
            if selectedModID == nil {
                selectedModID = filteredAndSortedMods.first?.id
            }
            setupKeyboardMonitor()
        }
        .confirmationDialog(
            loc("confirm_delete_title"),
            isPresented: $showDeleteConfirmation,
            presenting: modToDelete
        ) { mod in
            Button(loc("delete_selected"), role: .destructive) {
                appState.deleteMod(mod)
            }
            Button(loc("cancel"), role: .cancel) {}
        } message: { mod in
            Text(String(format: loc("confirm_delete_message"), mod.displayTitle))
        }
    }

    private func setupKeyboardMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Handle Cmd + F to focus search
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "f" {
                DispatchQueue.main.async {
                    self.isSearchFocused = true
                }
                return nil
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

            // Global navigation keys: J (Down), K (Up), Space (Toggle)
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "j":
                self.moveSelection(by: 1)
                return nil
            case "k":
                self.moveSelection(by: -1)
                return nil
            case " ":
                self.toggleSelectedMod()
                return nil
            default:
                return event
            }
        }
    }
}
