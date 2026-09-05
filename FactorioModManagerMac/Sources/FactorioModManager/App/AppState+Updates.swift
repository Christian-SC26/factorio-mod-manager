import Foundation
import SwiftUI

extension AppState {
    public var updatesAvailableMap: [String: ModUpdateItem] {
        Dictionary(uniqueKeysWithValues: updatesAvailable.map { ($0.name, $0) })
    }

    public func checkForUpdates() async {
        isCheckingUpdates = true
        updatesAvailable = []
        updatesCheckedCount = 0

        let community = communityMods
        updatesTotalCount = community.count
        guard !community.isEmpty else {
            isCheckingUpdates = false
            return
        }

        let targetBranch = effectiveFactorioBranch

        await withTaskGroup(of: ModUpdateItem?.self) { group in
            var iterator = community.makeIterator()
            let maxConcurrent = 8

            for _ in 0..<maxConcurrent {
                if let mod = iterator.next() {
                    group.addTask {
                        guard let info = try? await ModPortalClient.shared.fetchModInfo(mod.name),
                              let latest = info.findRelease(targetFactorioBranch: targetBranch),
                              latest.version > mod.version else {
                            return nil
                        }
                        return ModUpdateItem(
                            name: mod.name,
                            title: mod.displayTitle,
                            localVersion: mod.version,
                            remoteVersion: latest.version,
                            modInfo: info
                        )
                    }
                }
            }

            while let res = await group.next() {
                self.updatesCheckedCount += 1
                if let item = res {
                    self.updatesAvailable.append(item)
                }
                if let nextMod = iterator.next() {
                    group.addTask {
                        guard let info = try? await ModPortalClient.shared.fetchModInfo(nextMod.name),
                              let latest = info.findRelease(targetFactorioBranch: targetBranch),
                              latest.version > nextMod.version else {
                            return nil
                        }
                        return ModUpdateItem(
                            name: nextMod.name,
                            title: nextMod.displayTitle,
                            localVersion: nextMod.version,
                            remoteVersion: latest.version,
                            modInfo: info
                        )
                    }
                }
            }
        }

        self.updatesAvailable.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        self.isCheckingUpdates = false
    }

    public func updateAllMods() async {
        let targets = updatesAvailable.map { "\($0.name)@\($0.remoteVersion.raw)" }
        guard !targets.isEmpty else { return }
        await resolveDependencies(
            targets: targets,
            includeRecommended: true,
            includeOptional: false,
            forceReinstall: false
        )
    }

    public func directUpdateAllMods() async {
        let updates = updatesAvailable
        guard !updates.isEmpty else { return }

        self.isDirectUpdating = true
        self.directUpdateCurrentCount = 0
        self.directUpdateTotalCount = updates.count

        let targets = updates.map { "\($0.name)@\($0.remoteVersion.raw)" }
        let resolver = DependencyResolver(
            client: ModPortalClient.shared,
            modListMgr: modListMgr,
            targetFactorioBranch: effectiveFactorioVersion,
            includeRecommended: true,
            includeOptional: false,
            forceReinstall: false
        )

        let result = await resolver.resolve(targets: targets)
        let modsToDownload = result.modsToDownload

        if !modsToDownload.isEmpty {
            self.isDownloading = true
            self.downloadProgressList = modsToDownload.map {
                DownloadProgress(modName: $0.name, version: $0.release.version.raw)
            }

            let downloader = ModDownloader(
                modListMgr: modListMgr,
                cleanOld: cleanOldVersions,
                autoEnable: autoEnableMods
            )

            _ = await downloader.downloadAll(mods: modsToDownload) { [weak self] p in
                guard let self else { return }
                let app = self
                Task { @MainActor in
                    if let idx = app.downloadProgressList.firstIndex(where: { $0.modName == p.modName }) {
                        app.downloadProgressList[idx] = p
                    }
                    let finished = app.downloadProgressList.filter { $0.isCompleted }.count
                    app.directUpdateCurrentCount = finished
                }
            }
            self.isDownloading = false
        }

        let namesToEnable = modsToDownload.map(\.name)
        if autoEnableMods && !namesToEnable.isEmpty {
            setMultipleModsEnabled(namesToEnable, enabled: true)
        }

        loadInstalledMods()
        loadProfiles()
        loadSavedModpacks()

        let installedNames = Set(modsToDownload.map(\.name))
        self.updatesAvailable.removeAll { installedNames.contains($0.name) }
        self.isDirectUpdating = false
    }

    public func updateSingleMod(_ item: ModUpdateItem) async {
        await resolveDependencies(
            targets: ["\(item.name)@\(item.remoteVersion.raw)"],
            includeRecommended: true,
            includeOptional: false,
            forceReinstall: false
        )
    }
}
