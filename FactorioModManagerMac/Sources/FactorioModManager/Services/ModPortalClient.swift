import Foundation

public actor ModPortalClient {
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
            let pattern = #"mods\.factorio\.com/mod(?:s/[^/]+)?/([^/?#]+)"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: raw.utf16.count)
                if let match = regex.firstMatch(in: raw, options: [], range: range),
                   let nameRange = Range(match.range(at: 1), in: raw) {
                    let modName = String(raw[nameRange])
                    
                    var ver: String? = nil
                    let verPattern = #"/downloads#?(\d+(?:\.\d+)*)?"#
                    if let verRegex = try? NSRegularExpression(pattern: verPattern) {
                        if let vMatch = verRegex.firstMatch(in: raw, options: [], range: range),
                           vMatch.range(at: 1).location != NSNotFound,
                           let vRange = Range(vMatch.range(at: 1), in: raw) {
                            ver = String(raw[vRange])
                        }
                    }
                    return (modName, ver, ver != nil ? "==" : nil)
                }
            }
        }

        // 3. Check version specifier: name@version, name==version, name>=version, etc.
        let specPattern = #"^([%\w\.-]+)\s*(@|==|=|>=|<=|>|<)\s*(\d+(?:\.\d+)*)$"#
        if let specRegex = try? NSRegularExpression(pattern: specPattern) {
            let range = NSRange(location: 0, length: raw.utf16.count)
            if let match = specRegex.firstMatch(in: raw, options: [], range: range),
               let nRange = Range(match.range(at: 1), in: raw),
               let opRange = Range(match.range(at: 2), in: raw),
               let vRange = Range(match.range(at: 3), in: raw) {
                let name = String(raw[nRange])
                let op = String(raw[opRange])
                let ver = String(raw[vRange])
                let opNorm = (op == "@" || op == "=") ? "==" : op
                return (name, ver, opNorm)
            }
        }

        return (raw, nil, nil)
    }

    /// Fetch metadata for a mod by ID / name, trying re146 mirror first then official portal
    public func fetchModInfo(_ modName: String) async throws -> ModInfo {
        let cleaned = modName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            throw NSError(domain: "FMM", code: 400, userInfo: [NSLocalizedDescriptionKey: "Mod name cannot be empty"])
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
                            throw NSError(domain: "FMM", code: 404, userInfo: [NSLocalizedDescriptionKey: "Mod '\(cleaned)' not found on portal (404 Not Found)"])
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
            throw NSError(domain: "FMM", code: 404, userInfo: [NSLocalizedDescriptionKey: "Mod '\(cleaned)' not found or data corrupted"])
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

    /// Search mods on Factorio Mod Portal
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
                    if onlyV2 && !c.factorioVersions.isEmpty {
                        if !c.factorioVersions.contains("2.0") && !c.factorioVersions.contains("2.1") && !c.factorioVersions.contains("2.") {
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

    /// Parse HTML cards from Factorio portal pages
    private nonisolated func parseHtmlModCards(_ html: String) -> [SearchModItem] {
        var cards: [SearchModItem] = []
        let chunks = html.components(separatedBy: "class=\"panel-inset-lighter flex-column p0")
        guard chunks.count > 1 else { return [] }

        for chunk in chunks.dropFirst() {
            guard let nameMatch = chunk.firstMatch(pattern: #"href="/mod/([^"/?#]+)"#) else { continue }
            let name = nameMatch.trimmingCharacters(in: .whitespaces)

            // Title
            let rawTitle = chunk.firstMatch(pattern: #"<h2[^>]*>.*?<a[^>]*>(.*?)</a>"#) ?? name
            let title = unescapeHtml(stripHtmlTags(rawTitle)).trimmingCharacters(in: .whitespaces)

            // Owner
            let owner = chunk.firstMatch(pattern: #"href="/user/([^"/?#]+)""#) ?? "Unknown"

            // Summary
            let rawSummary = chunk.firstMatch(pattern: #"<p\s+class="[^"<>]*result-field[^"<>]*"[^>]*>(.*?)(?:</p>|</div>)"#)
                ?? chunk.firstMatch(pattern: #"<p[^>]*class="[^"<>]*line-clamp[^"<>]*"[^>]*>(.*?)(?:</p>|</div>)"#)
                ?? chunk.firstMatch(pattern: #"<div class="mod-card-summary[^"]*"[^>]*>(.*?)</div>"#)
                ?? ""
            let summary = unescapeHtml(stripHtmlTags(rawSummary)).trimmingCharacters(in: .whitespaces)

            // Factorio versions
            let fVer = chunk.firstMatch(pattern: #"title="Available for these Factorio versions"[^>]*>.*?<i[^>]*></i>\s*([^<\n]+)"#) ?? ""

            // Downloads count
            let dlStr = chunk.firstMatch(pattern: #"title="Downloads[^"]*"[^>]*>.*?<span title="(\d+)""#) ?? "0"
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
        guard let regex = try? NSRegularExpression(pattern: "<[^<]+?>", options: []) else { return str }
        return regex.stringByReplacingMatches(in: str, options: [], range: NSRange(location: 0, length: str.utf16.count), withTemplate: "")
    }

    private nonisolated func unescapeHtml(_ str: String) -> String {
        guard let data = str.data(using: .utf8) else { return str }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        if let attr = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return attr.string
        }
        return str
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}

private extension String {
    func firstMatch(pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return nil }
        let range = NSRange(location: 0, length: self.utf16.count)
        guard let match = regex.firstMatch(in: self, options: [], range: range) else { return nil }
        if match.numberOfRanges > 1, match.range(at: 1).location != NSNotFound, let r = Range(match.range(at: 1), in: self) {
            return String(self[r])
        }
        return nil
    }
}
