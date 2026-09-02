import Foundation
import SwiftUI

extension AppState {
    public func resolveDependencies(
        targets: [String],
        includeRecommended: Bool = true,
        includeOptional: Bool = false,
        forceReinstall: Bool = false
    ) async {
        isResolving = true
        let resolver = DependencyResolver(
            client: ModPortalClient.shared,
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

    public func resolveAndInstall(targets: [String]) async {
        await resolveDependencies(
            targets: targets,
            includeRecommended: true,
            includeOptional: false,
            forceReinstall: false
        )
    }

    public func cancelResolution() {
        isResolutionModalPresented = false
        isExclusiveModpackResolution = false
        currentResolutionResult = nil
    }

    public func executeDownload(for customMods: [ResolvedMod]? = nil) async {
        guard let res = currentResolutionResult else { return }
        let modsToDownload = customMods ?? res.modsToDownload

        if !modsToDownload.isEmpty {
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
        }

        // Modpack and download enabling
        let namesToEnable = (modsToDownload.map(\.name) + (currentResolutionResult?.modsUpToDate.map(\.name) ?? []))

        if isExclusiveModpackResolution {
            var newStates: [String: Bool] = [:]
            for mod in installedMods {
                if FactorioConstants.isOfficialMod(mod.name) {
                    newStates[mod.name] = modStates[mod.name] ?? true
                } else {
                    newStates[mod.name] = false
                }
            }
            for name in namesToEnable {
                newStates[name] = true
            }
            newStates[FactorioConstants.baseModName] = true
            try? modListMgr.writeModListJson(newStates)
            isExclusiveModpackResolution = false
        } else if autoEnableMods && !namesToEnable.isEmpty {
            setMultipleModsEnabled(namesToEnable, enabled: true)
        }

        loadInstalledMods()
        loadProfiles()
        loadSavedModpacks()

        // Remove successfully installed mods from updatesAvailable list
        let installedDownloadedNames = Set(modsToDownload.map(\.name))
        self.updatesAvailable.removeAll { installedDownloadedNames.contains($0.name) }
    }
}
