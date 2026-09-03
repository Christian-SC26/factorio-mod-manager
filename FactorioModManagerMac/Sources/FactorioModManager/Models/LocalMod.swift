import Foundation
import Compression

public struct LocalModInfo: Codable, Hashable, Sendable {
    public let name: String?
    public let version: String?
    public let title: String?
    public let author: String?
    public let description: String?
    public let factorio_version: String?
    public let dependencies: [String]?

    public init(
        name: String? = nil,
        version: String? = nil,
        title: String? = nil,
        author: String? = nil,
        description: String? = nil,
        factorio_version: String? = nil,
        dependencies: [String]? = nil
    ) {
        self.name = name
        self.version = version
        self.title = title
        self.author = author
        self.description = description
        self.factorio_version = factorio_version
        self.dependencies = dependencies
    }
}

public struct LocalMod: Identifiable, Hashable, Sendable {
    public var id: String { "\(name)_\(version.raw)_\(fileURL.path)" }
    public let name: String
    public let version: FactorioVersion
    public let fileURL: URL
    public let isDirectory: Bool
    public var enabled: Bool
    public let fileSize: Int64
    public let modificationDate: Date?
    public var info: LocalModInfo?

    // Precomputed properties for instant table rendering & zero-cost sorting
    public let displayTitle: String
    public let author: String
    public let cleanAuthorName: String
    public let primaryAuthor: String
    public let summary: String
    public let factorioVersion: String
    public let formattedDate: String
    public let dateSortKey: Date

    public var title: String { displayTitle }
    public var enabledSortKey: Int { enabled ? 1 : 0 }

    public init(
        name: String,
        version: FactorioVersion,
        fileURL: URL,
        isDirectory: Bool,
        enabled: Bool = true,
        fileSize: Int64 = 0,
        modificationDate: Date? = nil,
        info: LocalModInfo? = nil
    ) {
        self.name = name
        self.version = version
        self.fileURL = fileURL
        self.isDirectory = isDirectory
        self.enabled = enabled
        self.fileSize = fileSize
        self.modificationDate = modificationDate
        self.info = info

        // 1. Precompute title
        if let rawTitle = info?.title?.trimmingCharacters(in: .whitespacesAndNewlines), !rawTitle.isEmpty {
            let upper = rawTitle.uppercased()
            if !upper.contains("MOD DISPLAY NAME") && !rawTitle.hasPrefix("__") && !upper.contains("LOCALE") && rawTitle != "[mod-name]" {
                self.displayTitle = rawTitle
            } else {
                self.displayTitle = Self.cleanHumanTitle(from: name)
            }
        } else {
            self.displayTitle = Self.cleanHumanTitle(from: name)
        }

        // 2. Precompute author
        let rawAuthor = info?.author?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let resolvedAuthor = rawAuthor.isEmpty ? "—" : rawAuthor
        self.author = resolvedAuthor

        if resolvedAuthor == "—" {
            self.cleanAuthorName = "—"
            self.primaryAuthor = ""
        } else {
            var cleaned = resolvedAuthor
            let range = NSRange(location: 0, length: cleaned.utf16.count)
            cleaned = RegexHelper.authorYear.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
            if let paren = cleaned.range(of: "(") {
                cleaned = String(cleaned[..<paren.lowerBound])
            }
            let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalClean = trimmed.isEmpty ? resolvedAuthor : trimmed
            self.cleanAuthorName = finalClean

            let first = finalClean.components(separatedBy: ",")[0]
            self.primaryAuthor = first.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 3. Precompute metadata
        self.summary = info?.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.factorioVersion = info?.factorio_version?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "2.1"
        self.dateSortKey = modificationDate ?? Date.distantPast
        if let d = modificationDate {
            self.formattedDate = Formatters.formatDate(d)
        } else {
            self.formattedDate = "—"
        }
    }

    public static func == (lhs: LocalMod, rhs: LocalMod) -> Bool {
        lhs.id == rhs.id && lhs.enabled == rhs.enabled && lhs.displayTitle == rhs.displayTitle
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(enabled)
    }

    public static func cleanHumanTitle(from rawName: String) -> String {
        Formatters.formatModNameAsTitle(rawName)
    }

    public func portalAuthorURL(portalOwner: String?) -> URL? {
        let username = (portalOwner != nil && !portalOwner!.isEmpty) ? portalOwner! : primaryAuthor
        guard !username.isEmpty, username != "—" else { return nil }
        let encoded = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        return URL(string: "https://mods.factorio.com/user/\(encoded)")
    }

    public func getDependencies() -> [Dependency] {
        guard let rawDeps = info?.dependencies else { return [] }
        return rawDeps.compactMap { Dependency.parse($0) }
    }

    public static func loadInfoJson(from url: URL, isDirectory: Bool) -> LocalModInfo? {
        if isDirectory {
            let infoPath = url.appendingPathComponent("info.json")
            guard FileManager.default.fileExists(atPath: infoPath.path),
                  let data = try? Data(contentsOf: infoPath) else { return nil }
            return try? JSONDecoder().decode(LocalModInfo.self, from: data)
        } else if url.pathExtension.lowercased() == "zip" {
            return ZipArchiveReader.readInfoJson(from: url)
        }
        return nil
    }

    /// Pure Swift in-memory ZIP parser for info.json (delegates to ZipArchiveReader)
    public static func readInfoJsonFromZipInPureSwift(url: URL) -> LocalModInfo? {
        ZipArchiveReader.readInfoJson(from: url)
    }
}
