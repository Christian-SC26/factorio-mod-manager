import Foundation

public struct AuthorModItem: Identifiable, Hashable, Codable, Sendable {
    public var id: String { name }
    public let name: String
    public let title: String
    public let factorioVersions: String
    public let downloadsCount: Int
    public let isDeprecated: Bool

    public init(
        name: String,
        title: String,
        factorioVersions: String,
        downloadsCount: Int,
        isDeprecated: Bool
    ) {
        self.name = name
        self.title = title
        self.factorioVersions = factorioVersions
        self.downloadsCount = downloadsCount
        self.isDeprecated = isDeprecated
    }
}

public struct SearchModItem: Identifiable, Hashable, Codable, Sendable {
    public var id: String { name }
    public let name: String
    public let title: String
    public let owner: String
    public let summary: String
    public let factorioVersions: String
    public let downloadsCount: Int
    public let isDeprecated: Bool

    public init(
        name: String,
        title: String,
        owner: String,
        summary: String,
        factorioVersions: String,
        downloadsCount: Int,
        isDeprecated: Bool
    ) {
        self.name = name
        self.title = title
        self.owner = owner
        self.summary = summary
        self.factorioVersions = factorioVersions
        self.downloadsCount = downloadsCount
        self.isDeprecated = isDeprecated
    }
}

public struct ReleaseInfo: Hashable, Identifiable, Codable, Sendable {
    public var id: String { "\(version.raw)_\(fileName)" }
    public let version: FactorioVersion
    public let factorioVersion: String
    public let dependencies: [Dependency]
    public let sha1: String?
    public let fileName: String
    public let releasedAt: String
    public let downloadUrl: String

    public init(
        version: FactorioVersion,
        factorioVersion: String = "2.0",
        dependencies: [Dependency] = [],
        sha1: String? = nil,
        fileName: String = "",
        releasedAt: String = "",
        downloadUrl: String = ""
    ) {
        self.version = version
        self.factorioVersion = factorioVersion
        self.dependencies = dependencies
        self.sha1 = sha1
        self.fileName = fileName.isEmpty ? "\(version.raw).zip" : fileName
        self.releasedAt = releasedAt
        self.downloadUrl = downloadUrl
    }
}

public struct ModInfo: Identifiable, Hashable, Sendable {
    public var id: String { name }
    public let name: String
    public let title: String
    public let owner: String
    public let summary: String
    public let category: String
    public let downloadsCount: Int
    public let releases: [ReleaseInfo]

    public init(
        name: String,
        title: String = "",
        owner: String = "Unknown",
        summary: String = "",
        category: String = "",
        downloadsCount: Int = 0,
        releases: [ReleaseInfo] = []
    ) {
        self.name = name
        self.title = title.isEmpty ? name : title
        self.owner = owner
        self.summary = summary
        self.category = category
        self.downloadsCount = downloadsCount
        self.releases = releases
    }

    /// Get latest release matching Factorio branch (e.g. "2.1", "2.0", "1.1")
    public func getLatestRelease(targetFactorioBranch: String? = nil) -> ReleaseInfo? {
        guard !releases.isEmpty else { return nil }
        guard let branch = targetFactorioBranch, !branch.isEmpty else {
            return releases.last
        }

        let targetV = FactorioVersion(branch)

        // 1. Exact branch match
        for rel in releases.reversed() {
            if !rel.factorioVersion.isEmpty {
                let relFV = FactorioVersion(rel.factorioVersion)
                if relFV.isCompatibleMajorMinor(branch) {
                    return rel
                }
            }

            for dep in rel.dependencies {
                if dep.name == "base", let depV = dep.version {
                    if depV.isCompatibleMajorMinor(branch) {
                        return rel
                    }
                }
            }
        }

        // 2. Compatible version within the same major version family
        for rel in releases.reversed() {
            if !rel.factorioVersion.isEmpty {
                let relFV = FactorioVersion(rel.factorioVersion)
                if !relFV.parts.isEmpty && !targetV.parts.isEmpty && relFV.parts[0] == targetV.parts[0] {
                    if relFV <= targetV {
                        let baseDep = rel.dependencies.first { $0.name == "base" }
                        if baseDep == nil || baseDep!.satisfies(targetV) {
                            return rel
                        }
                    }
                }
            }
        }

        return releases.last
    }

    /// Find release satisfying version constraints and branch compatibility
    public func findRelease(
        versionReq: String? = nil,
        op: String? = nil,
        targetFactorioBranch: String? = nil
    ) -> ReleaseInfo? {
        guard !releases.isEmpty else { return nil }
        guard let reqStr = versionReq, !reqStr.isEmpty else {
            return getLatestRelease(targetFactorioBranch: targetFactorioBranch)
        }

        let reqV = FactorioVersion(reqStr)
        let operatorStr = op ?? "=="

        var candidates: [ReleaseInfo] = []
        for rel in releases {
            var matches = false
            switch operatorStr {
            case "==", "=":
                matches = (rel.version == reqV)
            case ">=":
                matches = (rel.version >= reqV)
            case "<=":
                matches = (rel.version <= reqV)
            case ">":
                matches = (rel.version > reqV)
            case "<":
                matches = (rel.version < reqV)
            default:
                matches = (rel.version == reqV)
            }

            if matches {
                candidates.append(rel)
            }
        }

        if candidates.isEmpty { return nil }

        if let branch = targetFactorioBranch, !branch.isEmpty {
            let targetV = FactorioVersion(branch)
            let branchCandidates = candidates.filter {
                FactorioVersion($0.factorioVersion).isCompatibleMajorMinor(branch)
            }
            if let last = branchCandidates.last {
                return last
            }

            let majorCandidates = candidates.filter {
                let rFV = FactorioVersion($0.factorioVersion)
                return !rFV.parts.isEmpty && !targetV.parts.isEmpty
                    && rFV.parts[0] == targetV.parts[0]
                    && rFV <= targetV
            }
            if let last = majorCandidates.last {
                return last
            }
        }

        return candidates.last
    }
}
