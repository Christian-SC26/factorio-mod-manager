import SwiftUI
import AppKit

public struct InstalledModsView: View {
    @ObservedObject var appState: AppState
    @State private var filterMode: Int = 0 // 0: All, 1: Enabled, 2: Disabled
    @State private var searchText: String = ""
    @State private var sortColumn: String = "displayTitle"
    @State private var sortAscending: Bool = true
    @State private var showSaveProfileSheet: Bool = false
    @State private var newProfileName: String = ""
    @FocusState private var isSearchFocused: Bool

    // Deletion confirmation state
    @State private var modsPendingDeletion: [LocalMod] = []
    @State private var brokenDependenciesForPendingDeletion: [BrokenDependencyInfo] = []
    @State private var showSimpleDeleteConfirmation: Bool = false
    @State private var showDependencyDeleteConfirmation: Bool = false

    private var enabledCount: Int {
        appState.installedMods.filter { appState.isModEnabled($0.name) }.count
    }

    private var disabledCount: Int {
        appState.installedMods.filter { !appState.isModEnabled($0.name) }.count
    }

    private var currentActiveModNames: Set<String> {
        Set(appState.installedMods.filter { appState.isModEnabled($0.name) && $0.name != "base" }.map(\.name))
    }

    private func isProfileActive(_ profile: Profile) -> Bool {
        let activeMods = profile.extractActiveMods()
        return !activeMods.isEmpty && activeMods == currentActiveModNames
    }

    private var activeProfile: Profile? {
        appState.profiles.first { isProfileActive($0) }
    }

    private var filteredOfficialMods: [LocalMod] {
        var list = appState.officialMods
        if filterMode == 1 {
            list = list.filter { appState.isModEnabled($0.name) }
        } else if filterMode == 2 {
            list = list.filter { !appState.isModEnabled($0.name) }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            list = list.filter {
                $0.name.lowercased().contains(query)
                || $0.displayTitle.lowercased().contains(query)
                || $0.summary.lowercased().contains(query)
            }
        }
        return list
    }

    private var filteredCommunityMods: [LocalMod] {
        var list = appState.communityMods

        // Filter by status
        if filterMode == 1 {
            list = list.filter { appState.isModEnabled($0.name) }
        } else if filterMode == 2 {
            list = list.filter { !appState.isModEnabled($0.name) }
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

        // Sort
        list.sort { a, b in
            let result: Bool
            switch sortColumn {
            case "enabled":
                result = a.enabledSortKey < b.enabledSortKey
            case "author":
                result = a.author.localizedCaseInsensitiveCompare(b.author) == .orderedAscending
            case "dateSortKey":
                result = a.dateSortKey < b.dateSortKey
            case "factorioVersion":
                result = a.factorioVersion < b.factorioVersion
            case "version.raw":
                result = a.version < b.version
            case "fileSize":
                result = a.fileSize < b.fileSize
            default:
                result = a.displayTitle.localizedCaseInsensitiveCompare(b.displayTitle) == .orderedAscending
            }
            return sortAscending ? result : !result
        }

        return list
    }

    private func initiateDeletion(for targets: [LocalMod]) {
        let deletable = targets.filter { $0.name != "base" && !["space-age", "quality", "elevated-rails"].contains($0.name.lowercased()) }
        guard !deletable.isEmpty else { return }
        modsPendingDeletion = deletable
        let targetNames = Set(deletable.map(\.name))
        let broken = appState.checkBrokenDependencies(forDeletedModNames: targetNames)
        brokenDependenciesForPendingDeletion = broken

        if broken.isEmpty {
            showSimpleDeleteConfirmation = true
        } else {
            showDependencyDeleteConfirmation = true
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

                    // Quick Switch Menus: Profiles & Modpacks
                    HStack(spacing: 8) {
                        // Profiles Dropdown Menu
                        Menu {
                            Section("Saved Profiles (\(appState.profiles.count))") {
                                if appState.profiles.isEmpty {
                                    Text(loc("no_profiles_saved"))
                                } else {
                                    ForEach(appState.profiles) { profile in
                                        Button(action: {
                                            Task { await appState.activateProfile(profile) }
                                        }) {
                                            if isProfileActive(profile) {
                                                Label("\(profile.name) (Active)", systemImage: "checkmark")
                                            } else {
                                                Text(profile.name)
                                            }
                                        }
                                    }
                                }
                            }
                            Divider()
                            Button(action: {
                                newProfileName = ""
                                showSaveProfileSheet = true
                            }) {
                                Label("Save Current as Profile...", systemImage: "plus")
                            }
                            Button(action: {
                                appState.selectedTab = .profiles
                            }) {
                                Label("Manage Profiles...", systemImage: "folder")
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: activeProfile != nil ? "folder.fill" : "folder")
                                    .foregroundColor(activeProfile != nil ? .green : .secondary)
                                Text(activeProfile?.name ?? "Profiles")
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                            }
                        }

                        // Modpacks Dropdown Menu
                        Menu {
                            if !appState.savedModpacks.isEmpty {
                                Section("Saved Modpacks") {
                                    ForEach(appState.savedModpacks, id: \.url) { item in
                                        Button(action: {
                                            Task { await appState.applyModpack(from: item.url) }
                                        }) {
                                            Label(item.name, systemImage: "shippingbox")
                                        }
                                    }
                                }
                                Divider()
                            }
                            Section("Modpack Actions") {
                                Button(action: {
                                    appState.importModpackFromFile()
                                }) {
                                    Label("Import Modpack...", systemImage: "square.and.arrow.down")
                                }
                                Button(action: {
                                    appState.exportCurrentModpackToFile()
                                }) {
                                    Label("Export Current Modpack...", systemImage: "square.and.arrow.up")
                                }
                                Button(action: {
                                    appState.selectedTab = .exportImport
                                }) {
                                    Label("Manage Modpacks...", systemImage: "shippingbox")
                                }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "shippingbox")
                                    .foregroundColor(.secondary)
                                Text("Modpacks")
                                    .font(.system(size: 12, weight: .medium))
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        Button(action: {
                            Task { await appState.checkForUpdates() }
                        }) {
                            HStack(spacing: 6) {
                                if appState.isCheckingUpdates {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Checking \(appState.updatesCheckedCount)/\(appState.updatesTotalCount)...")
                                        .font(.system(size: 12))
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text(loc("check_updates"))
                                }
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
                        Text("↑/↓ / j/k: nav")
                        Text("•")
                        Text("⇧: range")
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

            // Pure Native AppKit Table View (120 FPS, Pixel-locked rows, True Finder navigation)
            if filteredOfficialMods.isEmpty && filteredCommunityMods.isEmpty {
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
                NativeModTableViewRepresentable(
                    officialMods: filteredOfficialMods,
                    communityMods: filteredCommunityMods,
                    modPortalOwners: appState.modPortalOwners,
                    enabledStates: appState.modStates,
                    updatesAvailableMap: appState.updatesAvailableMap,
                    onToggleMod: { mod, newState in
                        appState.setModEnabled(mod.name, enabled: newState)
                    },
                    onToggleSelection: { mods in
                        appState.toggleMods(mods)
                    },
                    onRequestDelete: { mods in
                        initiateDeletion(for: mods)
                    },
                    onOpenDetails: { mod in
                        appState.openModDetails(for: mod)
                    },
                    onOpenPortal: { mod in
                        if let url = URL(string: "https://mods.factorio.com/mod/\(mod.name)") {
                            NSWorkspace.shared.open(url)
                        }
                    },
                    onOpenAuthor: { mod in
                        let portalOwner = appState.modPortalOwners[mod.name]
                        if let url = mod.portalAuthorURL(portalOwner: portalOwner) {
                            NSWorkspace.shared.open(url)
                        }
                    },
                    onRevealInFinder: { mods in
                        let urls = mods.map(\.fileURL)
                        NSWorkspace.shared.activateFileViewerSelecting(urls)
                    },
                    onChangeSort: { columnIdentifier, ascending in
                        self.sortColumn = columnIdentifier
                        self.sortAscending = ascending
                    }
                )
            }
        }
        .onAppear {
            appState.loadProfiles()
            appState.loadSavedModpacks()
        }
        .sheet(isPresented: $showSaveProfileSheet) {
            VStack(spacing: 16) {
                HStack {
                    Text("Save Current Profile")
                        .font(.headline)
                    Spacer()
                    Button("Cancel") { showSaveProfileSheet = false }
                }

                TextField(loc("profile_name_placeholder"), text: $newProfileName)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Spacer()
                    Button("Save Profile") {
                        let trimmed = newProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            appState.saveCurrentProfile(name: trimmed)
                            showSaveProfileSheet = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(20)
            .frame(width: 360)
        }
        // Simple Deletion Confirmation (No broken dependencies)
        .confirmationDialog(
            loc("confirm_delete_title"),
            isPresented: $showSimpleDeleteConfirmation
        ) {
            Button(loc("delete_selected"), role: .destructive) {
                appState.deleteMods(modsPendingDeletion)
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
                    }

                    Button("Delete & Disable Dependent Mods") {
                        showDependencyDeleteConfirmation = false
                        let dependentList = Array(Set(brokenDependenciesForPendingDeletion.map(\.dependentMod)))
                        appState.deleteModsAndDisableDependents(mods: modsPendingDeletion, dependentMods: dependentList)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(16)
                .background(Color(NSColor.windowBackgroundColor))
            }
            .frame(minWidth: 540, minHeight: 400)
        }
    }
}
