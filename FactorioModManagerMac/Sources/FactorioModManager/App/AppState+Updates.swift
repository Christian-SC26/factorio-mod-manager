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
        var foundUpdates: [ModUpdateItem] = []

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
                    foundUpdates.append(item)
                    self.updatesAvailable = foundUpdates.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
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

        self.updatesAvailable = foundUpdates.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
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

    public func updateSingleMod(_ item: ModUpdateItem) async {
        await resolveDependencies(
            targets: ["\(item.name)@\(item.remoteVersion.raw)"],
            includeRecommended: true,
            includeOptional: false,
            forceReinstall: false
        )
    }
}
