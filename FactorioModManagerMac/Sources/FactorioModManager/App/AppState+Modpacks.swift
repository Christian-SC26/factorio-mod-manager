import Foundation
import SwiftUI
import AppKit

extension AppState {
    private static var portalModpacksCacheURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
        let dir = appSupport.appendingPathComponent("FactorioModManager", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("portal_modpacks_cache.json")
    }

    public static func loadPersistedPortalModpacks(forBranch branch: String? = nil) -> [PortalModpackItem] {
        if let data = try? Data(contentsOf: portalModpacksCacheURL),
           let list = try? JSONDecoder().decode([PortalModpackItem].self, from: data) {
            if let b = branch, !b.isEmpty {
                return list.filter {
                    FactorioVersion($0.factorioVersion).isCompatibleMajorMinor(b)
                }
            }
            return list
        }
        return []
    }

    public static func savePersistedPortalModpacks(_ list: [PortalModpackItem]) {
        if let data = try? JSONEncoder().encode(list) {
            try? data.write(to: portalModpacksCacheURL, options: .atomic)
        }
    }

    public func loadSavedModpacks() {
        self.savedModpacks = modListMgr.listSavedModpacks()
    }

    public func loadPortalModpacks() {
        let branch = effectiveFactorioBranch
        let cached = Self.loadPersistedPortalModpacks(forBranch: branch)
        if !cached.isEmpty {
            self.portalModpacks = cached
        }

        Task {
            self.isLoadingPortalModpacks = true
            do {
                let packs = try await ModPortalClient.shared.fetchPortalModpacks(targetFactorioBranch: branch)
                if !packs.isEmpty {
                    self.portalModpacks = packs
                    Self.savePersistedPortalModpacks(packs)
                }
            } catch {}
            self.isLoadingPortalModpacks = false
        }
    }

    public func fetchPortalModpacks() {
        loadPortalModpacks()
    }

    public func installCuratedModpack(_ pack: ModListManager.ModpackDefinition, exclusive: Bool = false) async {
        self.isExclusiveModpackResolution = exclusive
        await resolveDependencies(
            targets: pack.targetMods,
            includeRecommended: true,
            includeOptional: false,
            forceReinstall: false
        )
    }

    public func installPortalModpack(_ pack: PortalModpackItem, exclusive: Bool = false) async {
        self.isExclusiveModpackResolution = exclusive
        await resolveDependencies(
            targets: [pack.name],
            includeRecommended: true,
            includeOptional: false,
            forceReinstall: false
        )
    }

    public func applyPortalModpack(_ pack: PortalModpackItem) async {
        await installPortalModpack(pack, exclusive: true)
    }

    public func applyModpack(from url: URL) async {
        do {
            let targets = try modListMgr.importModpack(from: url)
            guard !targets.isEmpty else { return }
            self.isExclusiveModpackResolution = true
            await resolveDependencies(
                targets: targets,
                includeRecommended: true,
                includeOptional: false,
                forceReinstall: false
            )
        } catch {
            showNotification(title: loc("export_import_title"), message: error.localizedDescription, isError: true)
        }
    }

    public func exportModpack() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "factorio-modpack.json"
        savePanel.title = loc("export_modpack_title")

        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                let count = try modListMgr.exportModpack(to: url)
                loadSavedModpacks()
                showNotification(
                    title: loc("export_import_title"),
                    message: String(format: loc("exported_success"), count, url.lastPathComponent)
                )
            } catch {
                showNotification(
                    title: loc("export_import_title"),
                    message: error.localizedDescription,
                    isError: true
                )
            }
        }
    }

    public func importModpack() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json, .plainText]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.title = loc("import_modpack_title")

        if openPanel.runModal() == .OK, let url = openPanel.url {
            do {
                let targets = try modListMgr.importModpack(from: url)
                guard !targets.isEmpty else {
                    showNotification(
                        title: loc("export_import_title"),
                        message: "No valid mods found in file.",
                        isError: true
                    )
                    return
                }

                showNotification(
                    title: loc("export_import_title"),
                    message: "Importing \(targets.count) mods from \(url.lastPathComponent)..."
                )

                Task {
                    await resolveDependencies(
                        targets: targets,
                        includeRecommended: true,
                        includeOptional: false,
                        forceReinstall: false
                    )
                }
            } catch {
                showNotification(
                    title: loc("export_import_title"),
                    message: error.localizedDescription,
                    isError: true
                )
            }
        }
    }

    public func importModpackFromFile() {
        importModpack()
    }

    public func exportCurrentModpackToFile() {
        exportModpack()
    }
}
