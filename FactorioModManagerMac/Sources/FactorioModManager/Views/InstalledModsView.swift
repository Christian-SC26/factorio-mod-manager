import SwiftUI
import AppKit

public struct InstalledModsView: View {
    @ObservedObject var appState: AppState
    @State private var filterMode: Int = 0 // 0: All, 1: Enabled, 2: Disabled
    @State private var searchText: String = ""
    @State private var sortOption: Int = 0 // 0: Name, 1: Version, 2: Size, 3: Status
    @State private var selectedModIDs: Set<String> = []
    @State private var modToDelete: LocalMod? = nil
    @State private var showDeleteConfirmation: Bool = false
    @State private var showBatchDeleteConfirmation: Bool = false
    @State private var displayedMods: [LocalMod] = []

    private func updateDisplayedMods() {
        var list = appState.installedMods

        // Filter by state
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
                || $0.title.lowercased().contains(query)
                || $0.author.lowercased().contains(query)
                || $0.summary.lowercased().contains(query)
            }
        }

        // Sort
        switch sortOption {
        case 1: // Version
            list.sort { $0.version > $1.version }
        case 2: // Size
            list.sort { $0.fileSize > $1.fileSize }
        case 3: // Status
            list.sort { ($0.enabled ? 1 : 0) > ($1.enabled ? 1 : 0) }
        default: // Name
            list.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        self.displayedMods = list
    }

    private var enabledCount: Int {
        appState.installedMods.filter { $0.enabled }.count
    }

    private var disabledCount: Int {
        appState.installedMods.filter { !$0.enabled }.count
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
                            if !selectedModIDs.isEmpty {
                                Button(role: .destructive, action: { showBatchDeleteConfirmation = true }) {
                                    Text("\(loc("delete_selected")) (\(selectedModIDs.count))")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }

                // Filter, Search and Sort Bar
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
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    Picker(loc("sort_by"), selection: $sortOption) {
                        Text(loc("sort_name")).tag(0)
                        Text(loc("sort_version")).tag(1)
                        Text(loc("sort_size")).tag(2)
                        Text(loc("sort_status")).tag(3)
                    }
                    .frame(width: 140)
                }
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Optimized ScrollView + LazyVStack for 120 FPS buttery smooth scrolling
            if displayedMods.isEmpty {
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
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(displayedMods.enumerated()), id: \.element.id) { index, mod in
                            InstalledModRow(
                                mod: mod,
                                isEven: index % 2 == 0,
                                onToggle: {
                                    appState.toggleModEnabled(mod)
                                },
                                onInfo: {
                                    appState.openModDetails(for: mod)
                                },
                                onReveal: {
                                    NSWorkspace.shared.activateFileViewerSelecting([mod.fileURL])
                                },
                                onDelete: {
                                    modToDelete = mod
                                    showDeleteConfirmation = true
                                }
                            )
                            .contextMenu {
                                Button(mod.enabled ? loc("filter_disabled") : loc("filter_enabled")) {
                                    appState.toggleModEnabled(mod)
                                }
                                Button(loc("sidebar_settings")) {
                                    appState.openModDetails(for: mod)
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

                            Divider()
                                .opacity(0.4)
                        }
                    }
                }
            }
        }
        .onAppear {
            updateDisplayedMods()
        }
        .onChange(of: appState.installedMods) { _ in
            updateDisplayedMods()
        }
        .onChange(of: filterMode) { _ in
            updateDisplayedMods()
        }
        .onChange(of: searchText) { _ in
            updateDisplayedMods()
        }
        .onChange(of: sortOption) { _ in
            updateDisplayedMods()
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
            Text(String(format: loc("confirm_delete_message"), mod.name))
        }
        .confirmationDialog(
            loc("confirm_delete_title"),
            isPresented: $showBatchDeleteConfirmation
        ) {
            Button(loc("delete_selected"), role: .destructive) {
                let targets = appState.installedMods.filter { selectedModIDs.contains($0.id) }
                appState.deleteMods(targets)
                selectedModIDs.removeAll()
            }
            Button(loc("cancel"), role: .cancel) {}
        } message: {
            Text(String(format: loc("confirm_delete_multiple"), selectedModIDs.count))
        }
    }
}

public struct InstalledModRow: View, Equatable {
    public let mod: LocalMod
    public let isEven: Bool
    public let onToggle: () -> Void
    public let onInfo: () -> Void
    public let onReveal: () -> Void
    public let onDelete: () -> Void

    public static func == (lhs: InstalledModRow, rhs: InstalledModRow) -> Bool {
        lhs.mod.id == rhs.mod.id && lhs.mod.enabled == rhs.mod.enabled && lhs.isEven == rhs.isEven
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Enable toggle switch
            Toggle("", isOn: Binding(
                get: { mod.enabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.small)

            // Mod icon (Monochrome)
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 30, height: 30)

                Image(systemName: mod.isDirectory ? "folder" : "cube.box")
                    .font(.system(size: 15))
                    .foregroundColor(mod.enabled ? .primary : .secondary)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(mod.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(mod.enabled ? .primary : .secondary)

                    if mod.title != mod.name {
                        Text("(\(mod.name))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                if !mod.summary.isEmpty {
                    Text(mod.summary)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Badges & Actions (Monochrome)
            HStack(spacing: 8) {
                VersionBadge(mod.version.raw)

                if mod.fileSize > 0 {
                    Text(formatBytes(mod.fileSize))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }

                HStack(spacing: 6) {
                    Button(action: onInfo) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(loc("sidebar_settings"))

                    Button(action: onReveal) {
                        Image(systemName: "arrow.up.forward.square")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(loc("reveal_in_finder"))

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(loc("delete_selected"))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isEven ? Color(NSColor.controlBackgroundColor).opacity(0.3) : Color.clear)
    }
}
