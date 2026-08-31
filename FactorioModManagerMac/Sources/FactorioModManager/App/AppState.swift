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

    private var fileWatcherSource: DispatchSourceFileSystemObject? = nil
    private var activeObserver: NSObjectProtocol? = nil

    private init() {
        if !customModsDirPath.isEmpty {
            let url = URL(fileURLWithPath: (customModsDirPath as NSString).expandingTildeInPath)
            self.modsDirectory = url
        } else {
            self.modsDirectory = ModListManager.defaultFactorioModsDir()
        }
        refreshAll()
        setupDiskSyncWatcher()
    }

    deinit {
        fileWatcherSource?.cancel()
        if let obs = activeObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    // MARK: - Directory Management
    public func setModsDirectory(_ url: URL) {
        self.modsDirectory = url
        self.customModsDirPath = url.path
        refreshAll()
        startDirectoryWatcher()
    }

    public func resetModsDirectory() {
        self.customModsDirPath = ""
        self.modsDirectory = ModListManager.defaultFactorioModsDir()
        refreshAll()
        startDirectoryWatcher()
    }

    private func setupDiskSyncWatcher() {
        if activeObserver == nil {
            activeObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.syncModStatesFromDisk()
                }
            }
        }
        startDirectoryWatcher()
    }

    private func startDirectoryWatcher() {
        fileWatcherSource?.cancel()
        fileWatcherSource = nil

        let dirPath = modsDirectory.path
        let fd = open(dirPath, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .attrib, .link],
            queue: DispatchQueue.global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.syncModStatesFromDisk()
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        self.fileWatcherSource = source
    }

    public func syncModStatesFromDisk() {
        let diskStates = modListMgr.readModListJson()
        var hasChanges = false

        if diskStates != self.modStates {
            self.modStates = diskStates
            hasChanges = true
        }

        for i in 0..<installedMods.count {
            let diskEnabled = diskStates[installedMods[i].name] ?? true
            if installedMods[i].enabled != diskEnabled {
                installedMods[i].enabled = diskEnabled
                hasChanges = true
            }
        }

        if hasChanges {
            objectWillChange.send()
        }
    }

    // MARK: - Refresh
    public func refreshAll() {
        detectedFactorioVersion = modListMgr.detectInstalledFactorioVersion()
        loadInstalledMods()
        loadProfiles()
    }

    // MARK: - Installed Mods State
    @Published public var installedMods: [LocalMod] = []
    @Published public var officialMods: [LocalMod] = []
    @Published public var communityMods: [LocalMod] = []
    @Published public var installedModsMap: [String: [LocalMod]] = [:]
    @Published public var modStates: [String: Bool] = [:]
    @Published public var isLoadingMods: Bool = false
    @Published public var modPortalOwners: [String: String] = [:]

    private static var ownersCacheURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
        let dir = appSupport.appendingPathComponent("FactorioModManager", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("portal_owners_cache.json")
    }

    public static func loadPersistedPortalOwners() -> [String: String] {
        if let data = try? Data(contentsOf: ownersCacheURL),
           let dict = try? JSONDecoder().decode([String: String].self, from: data) {
            return dict
        }
        return (UserDefaults.standard.dictionary(forKey: "persisted_mod_portal_owners") as? [String: String]) ?? [:]
    }

    public static func savePersistedPortalOwners(_ dict: [String: String]) {
        if let data = try? JSONEncoder().encode(dict) {
            try? data.write(to: ownersCacheURL, options: .atomic)
        }
        UserDefaults.standard.set(dict, forKey: "persisted_mod_portal_owners")
    }

    public func isModEnabled(_ name: String) -> Bool {
        modStates[name] ?? true
    }

    private func buildOfficialMods(states: [String: Bool]) -> [LocalMod] {
        let factorioVer = detectedFactorioVersion
        let isV2 = factorioVer.hasPrefix("2.")

        var list: [LocalMod] = []

        // Base mod
        let baseInfo = LocalModInfo(
            name: "base",
            version: factorioVer,
            title: "Base mod",
            author: "Wube Software",
            description: "Basic gameplay data and core engine assets for Factorio.",
            factorio_version: factorioVer
        )
        let baseMod = LocalMod(
            name: "base",
            version: FactorioVersion(factorioVer),
            fileURL: URL(fileURLWithPath: "/Applications/factorio.app"),
            isDirectory: false,
            enabled: true,
            fileSize: 0,
            modificationDate: nil,
            info: baseInfo
        )
        list.append(baseMod)

        if isV2 {
            let officialDefs: [(name: String, title: String, desc: String)] = [
                ("space-age", "Space Age", "Official expansion adding space platforms, interplanetary travel, and new worlds: Vulcanus, Gleba, Fulgora, and Aquilo."),
                ("quality", "Quality", "Official expansion adding quality levels to items, machines, and equipment."),
                ("elevated-rails", "Elevated Rails", "Official expansion adding elevated train ramps, rails, and rail supports.")
            ]

            for def in officialDefs {
                let isEnabled = states[def.name] ?? true
                let dlcInfo = LocalModInfo(
                    name: def.name,
                    version: factorioVer,
                    title: def.title,
                    author: "Wube Software",
                    description: def.desc,
                    factorio_version: factorioVer
                )
                let dlcMod = LocalMod(
                    name: def.name,
                    version: FactorioVersion(factorioVer),
                    fileURL: URL(fileURLWithPath: "/Applications/factorio.app"),
                    isDirectory: false,
                    enabled: isEnabled,
                    fileSize: 0,
                    modificationDate: nil,
                    info: dlcInfo
                )
                list.append(dlcMod)
            }
        }

        return list
    }

    public func loadInstalledMods() {
        isLoadingMods = true
        if modPortalOwners.isEmpty {
            self.modPortalOwners = Self.loadPersistedPortalOwners()
        }
        let states = modListMgr.readModListJson()
        self.modStates = states
        let map = modListMgr.scanInstalledMods()
        self.installedModsMap = map

        var commList: [LocalMod] = []
        for (name, versions) in map {
            if ["base", "space-age", "quality", "elevated-rails"].contains(name.lowercased()) {
                continue
            }
            if let latest = versions.first {
                var item = latest
                item.enabled = states[latest.name] ?? true
                commList.append(item)
            }
        }
        commList.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        let offList = buildOfficialMods(states: states)
        self.officialMods = offList
        self.communityMods = commList
        self.installedMods = offList + commList
        self.isLoadingMods = false

        fetchMissingPortalOwners()
    }

    public func fetchMissingPortalOwners() {
        let existing = self.modPortalOwners
        let targets = installedMods.map(\.name).filter { existing[$0] == nil && $0 != "base" }
        guard !targets.isEmpty else { return }

        Task.detached(priority: .background) { [weak self] in
            var newFetched: [String: String] = [:]
            await withTaskGroup(of: (String, String?).self) { group in
                var iterator = targets.makeIterator()
                let maxConcurrent = 4

                for _ in 0..<maxConcurrent {
                    if let name = iterator.next() {
                        group.addTask {
                            if let info = try? await ModPortalClient.shared.fetchModInfo(name), !info.owner.isEmpty {
                                return (name, info.owner)
                            }
                            return (name, nil)
                        }
                    }
                }

                while let (name, owner) = await group.next() {
                    if let nextName = iterator.next() {
                        group.addTask {
                            if let info = try? await ModPortalClient.shared.fetchModInfo(nextName), !info.owner.isEmpty {
                                return (nextName, info.owner)
                            }
                            return (nextName, nil)
                        }
                    }
                    if let owner = owner {
                        newFetched[name] = owner
                    }
                }
            }

            guard !newFetched.isEmpty, let self = self else { return }
            let batch = newFetched

            await MainActor.run {
                for (k, v) in batch {
                    self.modPortalOwners[k] = v
                }
                Self.savePersistedPortalOwners(self.modPortalOwners)
                self.objectWillChange.send()
            }
        }
    }

    public func loadProfiles() {
        self.profiles = modListMgr.listProfiles()
    }

    // MARK: - Mod Actions
    public func setModEnabled(_ name: String, enabled: Bool) {
        if name == "base" && !enabled { return }
        modStates[name] = enabled
        for i in 0..<installedMods.count {
            if installedMods[i].name == name {
                installedMods[i].enabled = enabled
            }
        }
        try? modListMgr.writeModListJson(modStates)
        objectWillChange.send()
    }

    public func setMultipleModsEnabled(_ names: [String], enabled: Bool) {
        for n in names where n != "base" || enabled {
            modStates[n] = enabled
        }
        let nameSet = Set(names)
        for i in 0..<installedMods.count {
            if nameSet.contains(installedMods[i].name) && (installedMods[i].name != "base" || enabled) {
                installedMods[i].enabled = enabled
            }
        }
        try? modListMgr.writeModListJson(modStates)
        objectWillChange.send()
    }

    public func toggleModEnabled(_ mod: LocalMod) {
        let current = modStates[mod.name] ?? mod.enabled
        setModEnabled(mod.name, enabled: !current)
    }

    public func toggleMods(_ mods: [LocalMod]) {
        guard !mods.isEmpty else { return }
        let anyEnabled = mods.contains { modStates[$0.name] ?? $0.enabled }
        let targetState = !anyEnabled
        setMultipleModsEnabled(mods.map(\.name), enabled: targetState)
    }

    public func enableAllMods() {
        let names = installedMods.map { $0.name }
        setMultipleModsEnabled(names, enabled: true)
    }

    public func disableAllMods() {
        let names = installedMods.map { $0.name }
        setMultipleModsEnabled(names, enabled: false)
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
    @Published public var updatesCheckedCount: Int = 0
    @Published public var updatesTotalCount: Int = 0
    @Published public var updatesAvailableMap: [String: ModUpdateItem] = [:]

    public func checkForUpdates() async {
        isCheckingUpdates = true
        let targets = communityMods
        self.updatesTotalCount = targets.count
        self.updatesCheckedCount = 0
        var updates: [ModUpdateItem] = []
        var updatesMap: [String: ModUpdateItem] = [:]
        let client = ModPortalClient.shared
        let targetBranch = effectiveFactorioVersion

        await withTaskGroup(of: ModUpdateItem?.self) { group in
            var iterator = targets.makeIterator()
            let maxConcurrent = 6

            for _ in 0..<maxConcurrent {
                if let mod = iterator.next() {
                    group.addTask {
                        do {
                            let info = try await client.fetchModInfo(mod.name)
                            if let remoteLatest = info.getLatestRelease(targetFactorioBranch: targetBranch) {
                                if remoteLatest.version > mod.version {
                                    return ModUpdateItem(
                                        name: mod.name,
                                        title: mod.title,
                                        localVersion: mod.version,
                                        remoteVersion: remoteLatest.version,
                                        modInfo: info
                                    )
                                }
                            }
                        } catch {}
                        return nil
                    }
                }
            }

            while let result = await group.next() {
                if let nextMod = iterator.next() {
                    group.addTask {
                        do {
                            let info = try await client.fetchModInfo(nextMod.name)
                            if let remoteLatest = info.getLatestRelease(targetFactorioBranch: targetBranch) {
                                if remoteLatest.version > nextMod.version {
                                    return ModUpdateItem(
                                        name: nextMod.name,
                                        title: nextMod.title,
                                        localVersion: nextMod.version,
                                        remoteVersion: remoteLatest.version,
                                        modInfo: info
                                    )
                                }
                            }
                        } catch {}
                        return nil
                    }
                }

                await MainActor.run {
                    self.updatesCheckedCount += 1
                    if let item = result {
                        updates.append(item)
                        updatesMap[item.name] = item
                        self.updatesAvailable = updates
                        self.updatesAvailableMap = updatesMap
                    }
                }
            }
        }

        await MainActor.run {
            self.updatesAvailable = updates
            self.updatesAvailableMap = updatesMap
            self.isCheckingUpdates = false
            if updates.isEmpty {
                self.showNotification(title: loc("updates_title"), message: "All mods are up to date.")
            } else {
                self.showNotification(title: loc("updates_title"), message: "\(updates.count) mod update(s) available!")
            }
        }
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
            _ = try modListMgr.saveProfile(name: name, states: self.modStates)
            loadProfiles()
            showNotification(title: loc("profiles_title"), message: loc("profile_saved", name))
            objectWillChange.send()
        } catch {
            showNotification(title: loc("profiles_title"), message: error.localizedDescription, isError: true)
        }
    }

    public func updateProfileWithCurrentMods(_ profile: Profile) {
        do {
            _ = try modListMgr.saveProfile(name: profile.name, states: self.modStates)
            loadProfiles()
            showNotification(title: loc("profiles_title"), message: "Profile '\(profile.name)' updated with current mod configuration.")
            objectWillChange.send()
        } catch {
            showNotification(title: loc("profiles_title"), message: error.localizedDescription, isError: true)
        }
    }

    public func activateProfile(_ profile: Profile) async {
        let (success, _, missing) = modListMgr.loadProfile(name: profile.name)
        if success {
            loadInstalledMods()
            objectWillChange.send()
            if missing.isEmpty {
                showNotification(title: loc("profiles_title"), message: "Profile '\(profile.name)' activated successfully!")
            } else {
                showNotification(title: loc("profiles_title"), message: "\(missing.count) mods from profile missing on disk. Resolving...")
                await resolveAndInstall(targets: missing)
            }
        } else {
            showNotification(title: loc("profiles_title"), message: "Failed to load profile '\(profile.name)'.", isError: true)
        }
    }

    public func deleteProfile(_ profile: Profile) {
        if modListMgr.deleteProfile(name: profile.name, filename: profile.filename) {
            loadProfiles()
            showNotification(title: loc("profiles_title"), message: "Profile '\(profile.name)' deleted.")
            objectWillChange.send()
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
