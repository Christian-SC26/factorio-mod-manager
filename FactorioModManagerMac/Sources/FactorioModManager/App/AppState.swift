import Foundation
import SwiftUI

public enum SidebarTab: String, CaseIterable, Identifiable {
    case installed
    case install
    case updates
    case profiles
    case search
    case authors
    case optional
    case exportImport
    case settings

    public var id: String { rawValue }
}

public struct ModUpdateItem: Identifiable, Hashable, Sendable {
    public var id: String { name }
    public let name: String
    public let title: String
    public let localVersion: FactorioVersion
    public let remoteVersion: FactorioVersion
    public let modInfo: ModInfo

    public init(name: String, title: String, localVersion: FactorioVersion, remoteVersion: FactorioVersion, modInfo: ModInfo) {
        self.name = name
        self.title = title
        self.localVersion = localVersion
        self.remoteVersion = remoteVersion
        self.modInfo = modInfo
    }
}

public struct OptionalModItem: Identifiable, Hashable, Sendable {
    public var id: String { name }
    public let name: String
    public let suggestedBy: [String]

    public init(name: String, suggestedBy: [String]) {
        self.name = name
        self.suggestedBy = suggestedBy
    }
}

public struct BrokenDependencyInfo: Identifiable, Sendable {
    public var id: String { "\(dependentMod.id)_\(brokenDependencyName)" }
    public let dependentMod: LocalMod
    public let brokenDependencyName: String

    public init(dependentMod: LocalMod, brokenDependencyName: String) {
        self.dependentMod = dependentMod
        self.brokenDependencyName = brokenDependencyName
    }
}

public struct AppNotification: Identifiable {
    public let id = UUID()
    public let title: String
    public let message: String
    public let isError: Bool

    public init(title: String, message: String, isError: Bool = false) {
        self.title = title
        self.message = message
        self.isError = isError
    }
}

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    // MARK: - Navigation
    @Published public var selectedTab: SidebarTab = .installed
    @Published public var selectedModDetail: LocalMod? = nil
    @Published public var selectedModInfoDetail: ModInfo? = nil
    @Published public var isDetailSheetPresented: Bool = false

    // MARK: - Settings (Persisted in AppStorage/UserDefaults)
    @AppStorage("custom_mods_dir") private var customModsDirPath: String = ""
    @AppStorage("custom_factorio_ver") public var customFactorioVersion: String = ""
    @AppStorage("clean_old_versions") public var cleanOldVersions: Bool = true
    @AppStorage("auto_enable_mods") public var autoEnableMods: Bool = true

    // MARK: - Core Services & Managers
    @Published public var modsDirectory: URL = ModListManager.defaultFactorioModsDir()
    @Published public var detectedFactorioVersion: String = "2.1"
    public var effectiveFactorioVersion: String {
        customFactorioVersion.isEmpty ? detectedFactorioVersion : customFactorioVersion
    }

    public var modListMgr: ModListManager {
        ModListManager(modsDirectory: modsDirectory)
    }

    // MARK: - Installed Mods State
    @Published public var installedMods: [LocalMod] = []
    @Published public var installedModsMap: [String: [LocalMod]] = [:]
    @Published public var isLoadingMods: Bool = false
    @Published public var modPortalOwners: [String: String] = [:]

    // MARK: - Profiles State
    @Published public var profiles: [Profile] = []

    // MARK: - Updates State
    @Published public var updatesAvailable: [ModUpdateItem] = []
    @Published public var isCheckingUpdates: Bool = false

    // MARK: - Search Portal State
    @Published public var searchResults: [SearchModItem] = []
    @Published public var isSearching: Bool = false
    @Published public var lastSearchQuery: String = ""

    // MARK: - Author Browse State
    @Published public var authorResults: [AuthorModItem] = []
    @Published public var isFetchingAuthor: Bool = false
    @Published public var currentAuthorName: String = ""

    // MARK: - Optional Mods State
    @Published public var optionalMods: [OptionalModItem] = []
    @Published public var isScanningOptional: Bool = false

    // MARK: - Resolution & Downloads State
    @Published public var isResolving: Bool = false
    @Published public var currentResolutionResult: ResolutionResult? = nil
    @Published public var isResolutionModalPresented: Bool = false
    @Published public var downloadProgressList: [DownloadProgress] = []
    @Published public var isDownloading: Bool = false

    // MARK: - Notifications
    @Published public var currentNotification: AppNotification? = nil

    private init() {
        if !customModsDirPath.isEmpty {
            let url = URL(fileURLWithPath: (customModsDirPath as NSString).expandingTildeInPath)
            self.modsDirectory = url
        } else {
            self.modsDirectory = ModListManager.defaultFactorioModsDir()
        }
        refreshAll()
    }

    // MARK: - Directory Management
    public func setModsDirectory(_ url: URL) {
        self.modsDirectory = url
        self.customModsDirPath = url.path
        refreshAll()
    }

    public func resetModsDirectory() {
        self.customModsDirPath = ""
        self.modsDirectory = ModListManager.defaultFactorioModsDir()
        refreshAll()
    }

    // MARK: - Refresh
    public func refreshAll() {
        detectedFactorioVersion = modListMgr.detectInstalledFactorioVersion()
        loadInstalledMods()
        loadProfiles()
    }

    public func loadInstalledMods() {
        isLoadingMods = true
        let map = modListMgr.scanInstalledMods()
        self.installedModsMap = map

        var list: [LocalMod] = []
        for (_, versions) in map {
            if let latest = versions.first {
                list.append(latest)
            }
        }
        list.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        self.installedMods = list
        self.isLoadingMods = false

        fetchMissingPortalOwners()
    }

    public func fetchMissingPortalOwners() {
        let targets = installedMods.map { $0.name }.filter { modPortalOwners[$0] == nil && $0 != "base" }
        guard !targets.isEmpty else { return }

        Task.detached(priority: .background) {
            for name in targets {
                if let info = try? await ModPortalClient.shared.fetchModInfo(name), !info.owner.isEmpty {
                    await MainActor.run {
                        self.modPortalOwners[name] = info.owner
                    }
                }
            }
        }
    }

    public func loadProfiles() {
        self.profiles = modListMgr.listProfiles()
    }

    // MARK: - Mod Actions
    public func toggleModEnabled(_ mod: LocalMod) {
        let newState = modListMgr.toggleMod(mod.name)
        if let idx = installedMods.firstIndex(where: { $0.name == mod.name }) {
            installedMods[idx].enabled = newState
        }
    }

    public func toggleMods(_ mods: [LocalMod]) {
        guard !mods.isEmpty else { return }
        let anyEnabled = mods.contains { $0.enabled }
        let targetState = !anyEnabled
        let names = mods.map { $0.name }
        if targetState {
            modListMgr.enableMods(names)
        } else {
            modListMgr.disableMods(names)
        }
        for name in names {
            if let idx = installedMods.firstIndex(where: { $0.name == name }) {
                installedMods[idx].enabled = targetState
            }
        }
    }

    public func enableAllMods() {
        let names = installedMods.map { $0.name }
        modListMgr.enableMods(names)
        loadInstalledMods()
    }

    public func disableAllMods() {
        let names = installedMods.map { $0.name }
        modListMgr.disableMods(names)
        loadInstalledMods()
    }

    public func checkBrokenDependencies(forDeletedModNames targetNames: Set<String>) -> [BrokenDependencyInfo] {
        var broken: [BrokenDependencyInfo] = []
        let remaining = installedMods.filter { !targetNames.contains($0.name) && $0.enabled }

        for mod in remaining {
            let deps = mod.getDependencies()
            for dep in deps {
                if dep.depType == .required && targetNames.contains(dep.name) {
                    broken.append(BrokenDependencyInfo(dependentMod: mod, brokenDependencyName: dep.name))
                }
            }
        }
        return broken
    }

    public func deleteMod(_ mod: LocalMod) {
        _ = modListMgr.removeMod(mod.name, deleteFiles: true)
        loadInstalledMods()
        showNotification(title: loc("installed_title"), message: "Mod '\(mod.name)' removed.")
    }

    public func deleteMods(_ mods: [LocalMod]) {
        for m in mods {
            _ = modListMgr.removeMod(m.name, deleteFiles: true)
        }
        loadInstalledMods()
        showNotification(title: loc("installed_title"), message: "\(mods.count) mods removed.")
    }

    public func deleteModsAndDisableDependents(mods: [LocalMod], dependentMods: [LocalMod]) {
        let depNames = dependentMods.map { $0.name }
        if !depNames.isEmpty {
            modListMgr.disableMods(depNames)
        }
        for m in mods {
            _ = modListMgr.removeMod(m.name, deleteFiles: true)
        }
        loadInstalledMods()
        showNotification(
            title: loc("installed_title"),
            message: "Removed \(mods.count) mod(s) and disabled \(depNames.count) dependent mod(s)."
        )
    }

    // MARK: - Updates
    public func checkForUpdates() async {
        isCheckingUpdates = true
        var updates: [ModUpdateItem] = []
        let client = ModPortalClient.shared

        for mod in installedMods where !VIRTUAL_BUILTINS.contains(mod.name.lowercased()) {
            do {
                let info = try await client.fetchModInfo(mod.name)
                if let remoteLatest = info.getLatestRelease(targetFactorioBranch: effectiveFactorioVersion) {
                    if remoteLatest.version > mod.version {
                        updates.append(ModUpdateItem(
                            name: mod.name,
                            title: mod.title,
                            localVersion: mod.version,
                            remoteVersion: remoteLatest.version,
                            modInfo: info
                        ))
                    }
                }
            } catch {
                // Ignore individual mod lookup errors
            }
        }

        self.updatesAvailable = updates
        self.isCheckingUpdates = false
    }

    public func updateAllMods() async {
        let names = updatesAvailable.map { $0.name }
        await resolveAndInstall(targets: names)
    }

    public func updateSingleMod(_ update: ModUpdateItem) async {
        await resolveAndInstall(targets: [update.name])
    }

    // MARK: - Resolution & Installation
    public func resolveDependencies(
        targets: [String],
        includeRecommended: Bool = true,
        includeOptional: Bool = false,
        forceReinstall: Bool = false
    ) async {
        isResolving = true
        let resolver = DependencyResolver(
            client: .shared,
            modListMgr: modListMgr,
            targetFactorioBranch: effectiveFactorioVersion,
            includeRecommended: includeRecommended,
            includeOptional: includeOptional,
            forceReinstall: forceReinstall
        )

        let result = await resolver.resolve(targets: targets)
        self.currentResolutionResult = result
        self.isResolving = false
        self.isResolutionModalPresented = true
    }

    public func executeDownload(for modsToDownload: [ResolvedMod]) async {
        guard !modsToDownload.isEmpty else { return }
        isDownloading = true
        downloadProgressList = modsToDownload.map {
            DownloadProgress(modName: $0.name, version: $0.release.version.raw)
        }

        let downloader = ModDownloader(
            modListMgr: modListMgr,
            cleanOld: cleanOldVersions,
            autoEnable: autoEnableMods
        )

        _ = await downloader.downloadAll(mods: modsToDownload) { [weak self] p in
            Task { @MainActor in
                if let idx = self?.downloadProgressList.firstIndex(where: { $0.modName == p.modName }) {
                    self?.downloadProgressList[idx] = p
                }
            }
        }

        isDownloading = false
        loadInstalledMods()
        loadProfiles()
        await checkForUpdates()
    }

    public func resolveAndInstall(targets: [String]) async {
        await resolveDependencies(
            targets: targets,
            includeRecommended: true,
            includeOptional: false,
            forceReinstall: false
        )
    }

    // MARK: - Profiles Actions
    public func saveCurrentProfile(name: String) {
        do {
            _ = try modListMgr.saveProfile(name: name)
            loadProfiles()
            showNotification(title: loc("profiles_title"), message: loc("profile_saved", name))
        } catch {
            showNotification(title: loc("profiles_title"), message: error.localizedDescription, isError: true)
        }
    }

    public func activateProfile(_ profile: Profile) async {
        let (success, _, missing) = modListMgr.loadProfile(name: profile.name)
        if success {
            loadInstalledMods()
            if missing.isEmpty {
                showNotification(title: loc("profiles_title"), message: "Profile '\(profile.name)' activated successfully!")
            } else {
                showNotification(title: loc("profiles_title"), message: "\(missing.count) mods from profile missing on disk. Resolving...")
                await resolveAndInstall(targets: missing)
            }
        }
    }

    public func deleteProfile(_ profile: Profile) {
        if modListMgr.deleteProfile(name: profile.name) {
            loadProfiles()
            showNotification(title: loc("profiles_title"), message: "Profile '\(profile.name)' deleted.")
        }
    }

    // MARK: - Search Portal
    public func searchPortal(query: String, scope: Int) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSearching = true
        lastSearchQuery = trimmed
        searchResults = []

        if scope == 2 {
            // Local search
            let qLower = trimmed.lowercased()
            var localResults: [SearchModItem] = []
            for mod in installedMods where !VIRTUAL_BUILTINS.contains(mod.name.lowercased()) {
                if mod.name.lowercased().contains(qLower) || mod.title.lowercased().contains(qLower) || mod.summary.lowercased().contains(qLower) || mod.author.lowercased().contains(qLower) {
                    localResults.append(SearchModItem(
                        name: mod.name,
                        title: mod.title,
                        owner: mod.author,
                        summary: mod.summary,
                        factorioVersions: mod.factorioVersion,
                        downloadsCount: 0,
                        isDeprecated: false
                    ))
                }
            }
            searchResults = localResults
        } else {
            let onlyV2 = (scope == 1)
            do {
                let results = try await ModPortalClient.shared.searchPortalMods(query: trimmed, onlyV2: onlyV2, maxPages: 5)
                self.searchResults = results
            } catch {
                self.searchResults = []
            }
        }
        isSearching = false
    }

    // MARK: - Author Browse
    public func fetchAuthorMods(author: String) async {
        let trimmed = author.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isFetchingAuthor = true
        currentAuthorName = trimmed
        authorResults = []

        do {
            let (name, mods) = try await ModPortalClient.shared.fetchAuthorMods(authorOrUrl: trimmed)
            self.currentAuthorName = name
            self.authorResults = mods
        } catch {
            self.authorResults = []
        }
        isFetchingAuthor = false
    }

    // MARK: - Optional Mods Scan
    public func scanOptionalMods() {
        isScanningOptional = true
        var map: [String: [String]] = [:]

        for mod in installedMods where !VIRTUAL_BUILTINS.contains(mod.name.lowercased()) {
            let deps = mod.getDependencies()
            for dep in deps where dep.depType == .optional {
                if installedModsMap[dep.name] == nil && !dep.isVirtual {
                    if map[dep.name] == nil {
                        map[dep.name] = []
                    }
                    if !map[dep.name]!.contains(mod.name) {
                        map[dep.name]!.append(mod.name)
                    }
                }
            }
        }

        self.optionalMods = map.map { OptionalModItem(name: $0.key, suggestedBy: $0.value) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        isScanningOptional = false
    }

    // MARK: - Notifications
    public func showNotification(title: String, message: String, isError: Bool = false) {
        self.currentNotification = AppNotification(title: title, message: message, isError: isError)
    }

    public func openModDetails(for localMod: LocalMod) {
        self.selectedModDetail = localMod
        self.selectedModInfoDetail = nil
        self.isDetailSheetPresented = true
        Task {
            if let info = try? await ModPortalClient.shared.fetchModInfo(localMod.name) {
                await MainActor.run {
                    self.selectedModInfoDetail = info
                }
            }
        }
    }

    public func openModDetails(for modName: String) {
        self.selectedModDetail = installedMods.first { $0.name == modName }
        self.selectedModInfoDetail = nil
        self.isDetailSheetPresented = true
        Task {
            if let info = try? await ModPortalClient.shared.fetchModInfo(modName) {
                await MainActor.run {
                    self.selectedModInfoDetail = info
                }
            }
        }
    }
}
