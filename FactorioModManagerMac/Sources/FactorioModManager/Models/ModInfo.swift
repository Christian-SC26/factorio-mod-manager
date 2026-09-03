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
    public let lastUpdated: String?

    public init(
        name: String,
        title: String,
        owner: String,
        summary: String,
        factorioVersions: String,
        downloadsCount: Int,
        isDeprecated: Bool,
        lastUpdated: String? = nil
    ) {
        self.name = name
        self.title = title
        self.owner = owner
        self.summary = summary
        self.factorioVersions = factorioVersions
        self.downloadsCount = downloadsCount
        self.isDeprecated = isDeprecated
        self.lastUpdated = lastUpdated
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

public struct ModScreenshot: Hashable, Identifiable, Codable, Sendable {
    public var id: String
    public let url: String
    public let thumbnail: String

    public init(id: String, url: String, thumbnail: String) {
        self.id = id
        self.url = url
        self.thumbnail = thumbnail
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
    public let description: String
    public let changelog: String
    public let screenshots: [ModScreenshot]

    public init(
        name: String,
        title: String = "",
        owner: String = "Unknown",
        summary: String = "",
        category: String = "",
        downloadsCount: Int = 0,
        releases: [ReleaseInfo] = [],
        description: String = "",
        changelog: String = "",
        screenshots: [ModScreenshot] = []
    ) {
        self.name = name
        self.title = title.isEmpty ? name : title
        self.owner = owner
        self.summary = summary
        self.category = category
        self.downloadsCount = downloadsCount
        self.releases = releases
        self.description = description
        self.changelog = changelog
        self.screenshots = screenshots
    }

    /// Get latest release matching Factorio branch (e.g. "2.1", "2.0", "1.1")
    public func getLatestRelease(targetFactorioBranch: String? = nil) -> ReleaseInfo? {
        guard !releases.isEmpty else { return nil }
        guard let branch = targetFactorioBranch, !branch.isEmpty else {
            return releases.last
        }

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

        return nil
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
            let branchCandidates = candidates.filter {
                FactorioVersion($0.factorioVersion).isCompatibleMajorMinor(branch)
            }
            if let last = branchCandidates.last {
                return last
            }
            return nil
        }

        return candidates.last
    }
}
