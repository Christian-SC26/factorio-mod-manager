import Foundation

public protocol ModPortalClientProtocol: Actor {
    func fetchModInfo(_ modName: String) async throws -> ModInfo
    func searchPortalMods(query: String, onlyV2: Bool, maxPages: Int) async throws -> [SearchModItem]
    func searchPortalMods(query: String, version: String, maxPages: Int) async throws -> [SearchModItem]
    func fetchCatalog(version: String, pageSize: Int) async throws -> [SearchModItem]
    func fetchAuthorMods(authorOrUrl: String) async throws -> (author: String, mods: [AuthorModItem])
    func fetchPortalModpacks(targetFactorioBranch: String?) async throws -> [PortalModpackItem]
}

public extension ModPortalClientProtocol {
    func searchPortalMods(query: String, version: String = "2.1", maxPages: Int = 5) async throws -> [SearchModItem] {
        return []
    }
    func fetchCatalog(version: String = "2.1", pageSize: Int = 100) async throws -> [SearchModItem] {
        return []
    }
}

public actor ModPortalClient: ModPortalClientProtocol {
    public static let shared = ModPortalClient()

    private let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    private let re146BaseStorage = "https://mods-storage.re146.dev/"
    private let re146ModInfoUrl = "https://re146.dev/factorio/mods/modinfo?id="
    private let factorioPortalApi = "https://mods.factorio.com/api/mods/"

    private var cache: [String: ModInfo] = [:]

    public init() {}

    /// Parse user input (URL, versioned string, or simple name)
    public nonisolated static func parseModInput(_ input: String) -> (name: String, version: String?, op: String?) {
        var raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return ("", nil, nil) }

        // 1. Check re146 hash fragment
        if raw.contains("re146.dev/factorio/mods") {
            let parts = raw.components(separatedBy: "#")
            if parts.count > 1 {
                let frag = parts[1]
                let fragVer = parts.count > 2 ? parts[2] : nil
                if frag.contains("mods.factorio.com") {
                    raw = frag
                } else {
                    let modName = frag.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    return (modName, fragVer, fragVer != nil ? "==" : nil)
                }
            }
        }

        // 2. Check official portal URL
        if raw.contains("mods.factorio.com") {
            let range = NSRange(location: 0, length: raw.utf16.count)
            if let match = RegexHelper.portalUrl.firstMatch(in: raw, options: [], range: range),
               let nameRange = Range(match.range(at: 1), in: raw) {
                let modName = String(raw[nameRange])

                var ver: String? = nil
                if let vMatch = RegexHelper.portalDownloadVersion.firstMatch(in: raw, options: [], range: range),
                   vMatch.range(at: 1).location != NSNotFound,
                   let vRange = Range(vMatch.range(at: 1), in: raw) {
                    ver = String(raw[vRange])
                }
                return (modName, ver, ver != nil ? "==" : nil)
            }
        }

        // 3. Check version specifier: name@version, name==version, name>=version, etc.
        let range = NSRange(location: 0, length: raw.utf16.count)
        if let match = RegexHelper.versionSpecifier.firstMatch(in: raw, options: [], range: range),
           let nRange = Range(match.range(at: 1), in: raw),
           let opRange = Range(match.range(at: 2), in: raw),
           let vRange = Range(match.range(at: 3), in: raw) {
            let name = String(raw[nRange])
            let op = String(raw[opRange])
            let ver = String(raw[vRange])
            let opNorm = (op == "@" || op == "=") ? "==" : op
            return (name, ver, opNorm)
        }

        return (raw, nil, nil)
    }

    /// Fetch metadata for a mod by ID / name, trying re146 mirror first then official portal
    public func fetchModInfo(_ modName: String) async throws -> ModInfo {
        let cleaned = modName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            throw FMMError.emptyModName
        }

        if let cached = cache[cleaned] {
            return cached
        }

        var jsonObject: [String: Any]? = nil

        // 1. Try re146.dev modinfo endpoint
        if let encoded = cleaned.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "\(re146ModInfoUrl)\(encoded)") {
            var req = URLRequest(url: url, timeoutInterval: 12)
            req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                    jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                }
            } catch {}
        }

        // 2. Fallback to official mods.factorio.com API
        if jsonObject == nil || jsonObject?["name"] == nil {
            if let encoded = cleaned.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
               let url = URL(string: "\(factorioPortalApi)\(encoded)/full") {
                var req = URLRequest(url: url, timeoutInterval: 12)
                req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
                do {
                    let (data, response) = try await URLSession.shared.data(for: req)
                    if let httpResp = response as? HTTPURLResponse {
                        if httpResp.statusCode == 404 {
                            throw FMMError.modNotFound(name: cleaned)
                        }
                        if httpResp.statusCode == 200 {
                            jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                        }
                    }
                } catch {
                    throw error
                }
            }
        }

        guard let data = jsonObject, let name = data["name"] as? String else {
            throw FMMError.modNotFound(name: cleaned)
        }

        let title = data["title"] as? String ?? name
        let owner = data["owner"] as? String ?? "Unknown"
        let summary = data["summary"] as? String ?? ""
        let category = data["category"] as? String ?? ""
        let downloadsCount = data["downloads_count"] as? Int ?? 0

        var releases: [ReleaseInfo] = []
        if let rawReleases = data["releases"] as? [[String: Any]] {
            for r in rawReleases {
                let verStr = r["version"] as? String ?? "0.0.1"
                let infoJson = r["info_json"] as? [String: Any] ?? [:]
                let fVer = infoJson["factorio_version"] as? String ?? "2.1"
                let rawDeps = infoJson["dependencies"] as? [String] ?? []
                let deps = rawDeps.compactMap { Dependency.parse($0) }
                let sha1 = r["sha1"] as? String
                let fileName = r["file_name"] as? String ?? "\(name)_\(verStr).zip"
                let releasedAt = r["released_at"] as? String ?? ""
                let downloadUrl = "\(re146BaseStorage)\(name)/\(verStr).zip"

                let release = ReleaseInfo(
                    version: FactorioVersion(verStr),
                    factorioVersion: fVer,
                    dependencies: deps,
                    sha1: sha1,
                    fileName: fileName,
                    releasedAt: releasedAt,
                    downloadUrl: downloadUrl
                )
                releases.append(release)
            }
        }

        releases.sort { $0.version < $1.version }

        let modInfo = ModInfo(
            name: name,
            title: title,
            owner: owner,
            summary: summary,
            category: category,
            downloadsCount: downloadsCount,
            releases: releases
        )

        cache[cleaned] = modInfo
        return modInfo
    }

    /// Fetch full catalog of mods for a Factorio version (e.g. "2.1" or "2.0") sorted by update date
    public func fetchCatalog(version: String, pageSize: Int = 100) async throws -> [SearchModItem] {
        let v = (version == "2.0" || version == "2.1") ? version : "2.1"
        let urlStr = "https://mods.factorio.com/api/mods?version=\(v)&sort=updated_at&order=desc&page_size=\(pageSize)"
        guard let url = URL(string: urlStr) else { return [] }

        var req = URLRequest(url: url, timeoutInterval: 15)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
            return []
        }

        struct ApiCatalogResponse: Decodable {
            struct ModEntry: Decodable {
                let name: String
                let title: String
                let owner: String?
                let summary: String?
                let downloads_count: Int?
                let category: String?
                struct Release: Decodable {
                    let version: String?
                    struct Info: Decodable {
                        let factorio_version: String?
                    }
                    let info_json: Info?
                }
                let latest_release: Release?
            }
            let results: [ModEntry]?
        }

        guard let decoded = try? JSONDecoder().decode(ApiCatalogResponse.self, from: data),
              let list = decoded.results else {
            return []
        }

        return list.map { m in
            let fVer = m.latest_release?.info_json?.factorio_version ?? v
            return SearchModItem(
                name: m.name,
                title: m.title,
                owner: m.owner ?? "",
                summary: m.summary ?? "",
                factorioVersions: fVer,
                downloadsCount: m.downloads_count ?? 0,
                isDeprecated: m.category == "deprecated"
            )
        }
    }

    /// Search mods on Factorio Mod Portal filtered by version ("2.1" or "2.0")
    public func searchPortalMods(query: String, version: String = "2.1", maxPages: Int = 5) async throws -> [SearchModItem] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanQuery.isEmpty {
            return try await fetchCatalog(version: version)
        }

        var results: [SearchModItem] = []
        var seenNames = Set<String>()
        let v = (version == "2.0" || version == "2.1") ? version : "2.1"

        for page in 1...maxPages {
            var urlStr = "https://mods.factorio.com/search?query=\(cleanQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cleanQuery)&version=\(v)"
            if page > 1 {
                urlStr += "&page=\(page)"
            }

            guard let url = URL(string: urlStr) else { break }
            var req = URLRequest(url: url, timeoutInterval: 12)
            req.setValue(userAgent, forHTTPHeaderField: "User-Agent")

            guard let (data, response) = try? await URLSession.shared.data(for: req),
                  let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) else {
                break
            }

            let cards = parseHtmlModCards(html)
            var foundOnPage = 0
            for c in cards {
                if !seenNames.contains(c.name) {
                    seenNames.insert(c.name)
                    foundOnPage += 1
                    results.append(c)
                }
            }

            if foundOnPage == 0 { break }
        }

        return results
    }

    /// Search mods on Factorio Mod Portal (backward compatibility)
    public func searchPortalMods(query: String, onlyV2: Bool = false, maxPages: Int = 5) async throws -> [SearchModItem] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else { return [] }

        var results: [SearchModItem] = []
        var seenNames = Set<String>()

        for page in 1...maxPages {
            var urlStr = "https://mods.factorio.com/search?query=\(cleanQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cleanQuery)"
            if page > 1 {
                urlStr += "&page=\(page)"
            }

            guard let url = URL(string: urlStr) else { break }
            var req = URLRequest(url: url, timeoutInterval: 12)
            req.setValue(userAgent, forHTTPHeaderField: "User-Agent")

            guard let (data, response) = try? await URLSession.shared.data(for: req),
                  let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) else {
                break
            }

            let cards = parseHtmlModCards(html)
            var foundOnPage = 0
            for c in cards {
                if !seenNames.contains(c.name) {
                    seenNames.insert(c.name)
                    foundOnPage += 1
                    if !c.factorioVersions.isEmpty {
                        let isV2OrV21 = c.factorioVersions.contains("2.0") || c.factorioVersions.contains("2.1") || c.factorioVersions.contains("2.")
                        if !isV2OrV21 {
                            continue
                        }
                    }
                    results.append(c)
                }
            }

            if foundOnPage == 0 { break }
        }

        return results
    }

    /// Fetch all mods created by an author
    public func fetchAuthorMods(authorOrUrl: String) async throws -> (author: String, mods: [AuthorModItem]) {
        let raw = authorOrUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return ("", []) }

        var authorName = raw
        if raw.contains("mods.factorio.com/user/") {
            authorName = raw.components(separatedBy: "mods.factorio.com/user/").last?.components(separatedBy: "/").first?.components(separatedBy: "?").first ?? raw
        } else if raw.contains("factorio.com/user/") {
            authorName = raw.components(separatedBy: "factorio.com/user/").last?.components(separatedBy: "/").first?.components(separatedBy: "?").first ?? raw
        }
        authorName = authorName.trimmingCharacters(in: .whitespacesAndNewlines)

        var mods: [AuthorModItem] = []
        var seenNames = Set<String>()
        var page = 1

        while page <= 30 {
            let encoded = authorName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? authorName
            let urlStr = page > 1 ? "https://mods.factorio.com/user/\(encoded)/\(page)" : "https://mods.factorio.com/user/\(encoded)"
            guard let url = URL(string: urlStr) else { break }

            var req = URLRequest(url: url, timeoutInterval: 12)
            req.setValue(userAgent, forHTTPHeaderField: "User-Agent")

            guard let (data, response) = try? await URLSession.shared.data(for: req),
                  let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) else {
                break
            }

            let cards = parseHtmlModCards(html)
            var foundOnPage = 0
            for c in cards {
                if !seenNames.contains(c.name) {
                    seenNames.insert(c.name)
                    foundOnPage += 1
                    mods.append(AuthorModItem(
                        name: c.name,
                        title: c.title,
                        factorioVersions: c.factorioVersions,
                        downloadsCount: c.downloadsCount,
                        isDeprecated: c.isDeprecated
                    ))
                }
            }

            if foundOnPage == 0 { break }
            page += 1
        }

        return (authorName, mods)
    }

    /// Parse HTML cards from Factorio portal pages using precompiled regexes and fast entity decoder
    private nonisolated func parseHtmlModCards(_ html: String) -> [SearchModItem] {
        var cards: [SearchModItem] = []
        let chunks = html.components(separatedBy: "class=\"panel-inset-lighter flex-column p0")
        guard chunks.count > 1 else { return [] }

        for chunk in chunks.dropFirst() {
            guard let nameMatch = RegexHelper.firstCapturedGroup(in: chunk, regex: RegexHelper.portalCardLink) else { continue }
            let name = nameMatch.trimmingCharacters(in: .whitespaces)

            // Title
            let rawTitle = RegexHelper.firstCapturedGroup(in: chunk, regex: RegexHelper.portalCardTitle) ?? name
            let title = HTMLEntityDecoder.unescape(stripHtmlTags(rawTitle)).trimmingCharacters(in: .whitespaces)

            // Owner
            let owner = RegexHelper.firstCapturedGroup(in: chunk, regex: RegexHelper.portalCardOwner) ?? "Unknown"

            // Summary
            let rawSummary = RegexHelper.firstCapturedGroup(in: chunk, regex: RegexHelper.portalCardSummary1)
                ?? RegexHelper.firstCapturedGroup(in: chunk, regex: RegexHelper.portalCardSummary2)
                ?? RegexHelper.firstCapturedGroup(in: chunk, regex: RegexHelper.portalCardSummary3)
                ?? ""
            let summary = HTMLEntityDecoder.unescape(stripHtmlTags(rawSummary)).trimmingCharacters(in: .whitespaces)

            // Factorio versions
            let fVer = RegexHelper.firstCapturedGroup(in: chunk, regex: RegexHelper.portalCardVersions) ?? ""

            // Downloads count
            let dlStr = RegexHelper.firstCapturedGroup(in: chunk, regex: RegexHelper.portalCardDownloads) ?? "0"
            let downloads = Int(dlStr) ?? 0

            // Deprecated
            let isDepr = chunk.contains("class=\"deprecated\"") || (chunk.lowercased().contains("deprecated") && chunk.contains("<span"))

            cards.append(SearchModItem(
                name: name,
                title: title.isEmpty ? name : title,
                owner: owner,
                summary: summary,
                factorioVersions: fVer.trimmingCharacters(in: .whitespaces),
                downloadsCount: downloads,
                isDeprecated: isDepr
            ))
        }

        return cards
    }

    private nonisolated func stripHtmlTags(_ str: String) -> String {
        RegexHelper.htmlTag.stringByReplacingMatches(
            in: str,
            options: [],
            range: NSRange(location: 0, length: str.utf16.count),
            withTemplate: ""
        )
    }

    /// Fetch all modpacks from Factorio Portal API for the specified Factorio branch (e.g. "2.1", "2.0", "1.1")
    public func fetchPortalModpacks(targetFactorioBranch: String? = nil) async throws -> [PortalModpackItem] {
        guard let url = URL(string: "https://mods.factorio.com/api/mods?page_size=max") else { return [] }
        var req = URLRequest(url: url, timeoutInterval: 25)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
            return []
        }

        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = root["results"] as? [[String: Any]] else {
            return []
        }

        var packs: [PortalModpackItem] = []
        let rawBranch = targetFactorioBranch?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let branch: String
        let parts = rawBranch.components(separatedBy: ".")
        if parts.count >= 2 {
            branch = "\(parts[0]).\(parts[1])"
        } else {
            branch = rawBranch
        }

        for item in results {
            guard let cat = item["category"] as? String, cat == "mod-packs" else { continue }
            let name = item["name"] as? String ?? ""
            let title = item["title"] as? String ?? name
            let owner = item["owner"] as? String ?? ""
            let summary = item["summary"] as? String ?? ""
            let downloads = item["downloads_count"] as? Int ?? 0

            let rel = item["latest_release"] as? [String: Any] ?? [:]
            let info = rel["info_json"] as? [String: Any] ?? [:]
            let fVer = info["factorio_version"] as? String ?? ""
            let lVer = rel["version"] as? String ?? "1.0.0"

            if !branch.isEmpty && !fVer.isEmpty {
                if !FactorioVersion(fVer).isCompatibleMajorMinor(branch) {
                    continue
                }
            }

            packs.append(PortalModpackItem(
                name: name,
                title: title,
                owner: owner,
                summary: summary,
                downloadsCount: downloads,
                category: cat,
                factorioVersion: fVer,
                latestVersion: lVer
            ))
        }

        return packs.sorted { $0.downloadsCount > $1.downloadsCount }
    }
}

public struct PortalModpackItem: Identifiable, Hashable, Codable, Sendable {
    public var id: String { name }
    public let name: String
    public let title: String
    public let owner: String
    public let summary: String
    public let downloadsCount: Int
    public let category: String
    public let factorioVersion: String
    public let latestVersion: String

    public init(
        name: String,
        title: String,
        owner: String = "",
        summary: String = "",
        downloadsCount: Int = 0,
        category: String = "mod-packs",
        factorioVersion: String = "2.0",
        latestVersion: String = "1.0.0"
    ) {
        self.name = name
        self.title = title
        self.owner = owner
        self.summary = summary
        self.downloadsCount = downloadsCount
        self.category = category
        self.factorioVersion = factorioVersion
        self.latestVersion = latestVersion
    }
}
