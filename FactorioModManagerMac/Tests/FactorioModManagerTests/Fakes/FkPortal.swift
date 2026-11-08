import Foundation
@testable import FactorioModManagerMac

/// In-memory mod portal: an honest implementation of `ModPortalClientProtocol` without network.
actor FkPortal: ModPortalClientProtocol {
    private let mods: [String: ModInfo]

    init(_ mods: ModInfo...) {
        self.mods = Dictionary(mods.map { ($0.name, $0) }, uniquingKeysWith: { _, last in last })
    }

    func fetchModInfo(_ modName: String) async throws -> ModInfo {
        guard let mod = mods[modName] else {
            throw FMMError.modNotFound(name: modName)
        }
        return mod
    }

    func searchPortalMods(query: String, onlyV2: Bool, maxPages: Int) async throws -> [SearchModItem] {
        mods.values
            .filter { $0.name.localizedCaseInsensitiveContains(query) }
            .map {
                SearchModItem(
                    name: $0.name,
                    title: $0.title,
                    owner: $0.owner,
                    summary: $0.summary,
                    factorioVersions: $0.factorioVersion,
                    downloadsCount: $0.downloadsCount,
                    isDeprecated: false
                )
            }
    }

    func fetchAuthorMods(authorOrUrl: String) async throws -> (author: String, mods: [AuthorModItem]) {
        let own = mods.values
            .filter { $0.owner == authorOrUrl }
            .map { AuthorModItem(name: $0.name, title: $0.title, owner: $0.owner) }
        return (authorOrUrl, own)
    }

    func fetchPortalModpacks(targetFactorioBranch: String?) async throws -> [PortalModpackItem] {
        []
    }

    static func mod(_ name: String, _ releases: ReleaseInfo...) -> ModInfo {
        ModInfo(name: name, title: name, owner: "Zoë O'Brien", releases: releases)
    }

    static func release(_ version: String, factorio: String, _ dependencies: String...) -> ReleaseInfo {
        ReleaseInfo(
            version: FactorioVersion(version),
            factorioVersion: factorio,
            dependencies: dependencies.compactMap { Dependency.parse($0) },
            sha1: nil,
            fileName: "",
            releasedAt: "",
            downloadUrl: "http://127.0.0.1:9/\(version).zip"
        )
    }

    static func resolved(_ name: String, _ version: String, url: String) -> ResolvedMod {
        let release = ReleaseInfo(
            version: FactorioVersion(version),
            factorioVersion: "2.0",
            dependencies: [],
            sha1: nil,
            fileName: "\(name)_\(version).zip",
            releasedAt: "",
            downloadUrl: url
        )
        return ResolvedMod(name: name, info: mod(name, release), release: release)
    }
}
