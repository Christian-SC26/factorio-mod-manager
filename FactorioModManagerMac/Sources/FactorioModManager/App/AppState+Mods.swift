import Foundation
import SwiftUI

extension AppState {
    // MARK: - Official Mods Construction
    public func buildOfficialMods(states: [String: Bool]) -> [LocalMod] {
        let factorioVer = effectiveFactorioVersion
        let isV2 = factorioVer.hasPrefix("2.")

        var list: [LocalMod] = []

        // Base mod
        let baseInfo = LocalModInfo(
            name: FactorioConstants.baseModName,
            version: factorioVer,
            title: "Base mod",
            author: "Wube Software",
            description: "Basic gameplay data and core engine assets for Factorio.",
            factorio_version: factorioVer
        )
        let baseMod = LocalMod(
            name: FactorioConstants.baseModName,
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
            for def in FactorioConstants.officialExpansions {
                let isEnabled = states[def.name] ?? true
                let dlcInfo = LocalModInfo(
                    name: def.name,
                    version: factorioVer,
                    title: def.title,
                    author: "Wube Software",
                    description: def.description,
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

    // MARK: - Loading Installed Mods
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
            if FactorioConstants.isOfficialMod(name) {
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

    // MARK: - Portal Owners Cache
    private static var portalOwnersCacheURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
        let dir = appSupport.appendingPathComponent("FactorioModManager", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("portal_owners_cache.json")
    }

    public static func loadPersistedPortalOwners() -> [String: String] {
        if let data = try? Data(contentsOf: portalOwnersCacheURL),
           let dict = try? JSONDecoder().decode([String: String].self, from: data) {
            return dict
        }
        return [:]
    }

    public static func savePersistedPortalOwners(_ dict: [String: String]) {
        if let data = try? JSONEncoder().encode(dict) {
            try? data.write(to: portalOwnersCacheURL, options: .atomic)
        }
    }

    public func fetchMissingPortalOwners() {
        let existing = self.modPortalOwners
        let targets = installedMods.map(\.name).filter { existing[$0] == nil && $0 != FactorioConstants.baseModName }
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

                while let result = await group.next() {
                    let (name, owner) = result
                    if let o = owner {
                        newFetched[name] = o
                    }
                    if let nextName = iterator.next() {
                        group.addTask {
                            if let info = try? await ModPortalClient.shared.fetchModInfo(nextName), !info.owner.isEmpty {
                                return (nextName, info.owner)
                            }
                            return (nextName, nil)
                        }
                    }
                }
            }

            guard !newFetched.isEmpty else { return }
            let batch = newFetched

            await MainActor.run { [weak self] in
                guard let self = self else { return }
                for (k, v) in batch {
                    self.modPortalOwners[k] = v
                }
                Self.savePersistedPortalOwners(self.modPortalOwners)
                self.objectWillChange.send()
            }
        }
    }

    // MARK: - Mod State Toggling (Instant In-Memory Update)
    public func isModEnabled(_ name: String) -> Bool {
        modStates[name] ?? true
    }

    private func updateInMemoryModState(name: String, enabled: Bool) {
        for i in 0..<installedMods.count where installedMods[i].name == name {
            installedMods[i].enabled = enabled
        }
        for i in 0..<officialMods.count where officialMods[i].name == name {
            officialMods[i].enabled = enabled
        }
        for i in 0..<communityMods.count where communityMods[i].name == name {
            communityMods[i].enabled = enabled
        }
    }

    public func setModEnabled(_ name: String, enabled: Bool) {
        if name == FactorioConstants.baseModName && !enabled { return }
        modStates[name] = enabled
        updateInMemoryModState(name: name, enabled: enabled)
        modListMgr.setModState(name, enabled: enabled)
        objectWillChange.send()
    }

    public func setMultipleModsEnabled(_ names: [String], enabled: Bool) {
        let nameSet = Set(names)
        for n in names where n != FactorioConstants.baseModName || enabled {
            modStates[n] = enabled
        }
        for i in 0..<installedMods.count where nameSet.contains(installedMods[i].name) && (installedMods[i].name != FactorioConstants.baseModName || enabled) {
            installedMods[i].enabled = enabled
        }
        for i in 0..<officialMods.count where nameSet.contains(officialMods[i].name) && (officialMods[i].name != FactorioConstants.baseModName || enabled) {
            officialMods[i].enabled = enabled
        }
        for i in 0..<communityMods.count where nameSet.contains(communityMods[i].name) && (communityMods[i].name != FactorioConstants.baseModName || enabled) {
            communityMods[i].enabled = enabled
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
        var currentStates = modListMgr.readModListJson()
        for mod in mods {
            guard mod.name != FactorioConstants.baseModName else { continue }
            let cur = currentStates[mod.name] ?? mod.enabled
            currentStates[mod.name] = !cur
        }
        currentStates[FactorioConstants.baseModName] = true
        try? modListMgr.writeModListJson(currentStates)
        self.modStates = currentStates
        syncModStatesFromDisk()
    }

    public func enableAllMods() {
        let names = installedMods.map(\.name)
        setMultipleModsEnabled(names, enabled: true)
    }

    public func disableAllMods() {
        let names = installedMods.map(\.name)
        setMultipleModsEnabled(names, enabled: false)
    }

    // MARK: - Mod Deletion & Dependency Breakage Checking
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
        let depNames = dependentMods.map(\.name)
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

    // MARK: - Mod Details Sheet
    public func openModDetails(for mod: LocalMod) {
        self.selectedModDetail = mod
        self.selectedModInfoDetail = nil
        self.isDetailSheetPresented = true
        Task {
            if let info = try? await ModPortalClient.shared.fetchModInfo(mod.name) {
                self.selectedModInfoDetail = info
            }
        }
    }

    public func openModDetails(for modName: String) {
        let local = installedMods.first(where: { $0.name == modName })
        self.selectedModDetail = local
        self.selectedModInfoDetail = nil
        self.isDetailSheetPresented = true
        Task {
            if let info = try? await ModPortalClient.shared.fetchModInfo(modName) {
                self.selectedModInfoDetail = info
            }
        }
    }
}
