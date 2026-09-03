import Foundation

/// Centralized precompiled regular expressions for zero-cost repeated regex matching.
public enum RegexHelper {
    // MARK: - Dependencies & Versions
    public static let dependency: NSRegularExpression = {
        let pattern = #"^(?:\s*(\?|\(\?\)|!|~|\+))?\s*([%\w\s\.-]+?)(?:\s*(<=|>=|==|=|<|>)\s*(\d+(?:\.\d+)*))?$"#
        return try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    }()

    public static let portalUrl: NSRegularExpression = {
        let pattern = #"mods\.factorio\.com/mod(?:s/[^/]+)?/([^/?#]+)"#
        return try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    }()

    public static let portalDownloadVersion: NSRegularExpression = {
        let pattern = #"/downloads#?(\d+(?:\.\d+)*)?"#
        return try! NSRegularExpression(pattern: pattern)
    }()

    public static let versionSpecifier: NSRegularExpression = {
        let pattern = #"^([%\w\.-]+)\s*(@|==|=|>=|<=|>|<)\s*(\d+(?:\.\d+)*)$"#
        return try! NSRegularExpression(pattern: pattern)
    }()

    // MARK: - File System Patterns
    public static let zipFilename: NSRegularExpression = {
        let pattern = #"^(.+)_(\d+(?:\.\d+)*)\.zip$"#
        return try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    }()

    public static let dirModName: NSRegularExpression = {
        let pattern = #"^(.+)_(\d+(?:\.\d+)*)$"#
        return try! NSRegularExpression(pattern: pattern)
    }()

    public static let logFactorioVersion: NSRegularExpression = {
        let pattern = #"Factorio\s+(\d+\.\d+\.\d+)"#
        return try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    }()

    public static let logBaseModVersion: NSRegularExpression = {
        let pattern = #"Loading\s+mod\s+(?:base|core)\s+(\d+\.\d+\.\d+)"#
        return try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    }()

    public static let authorYear: NSRegularExpression = {
        let pattern = #",?\s*\b20\d{2}\b.*$"#
        return try! NSRegularExpression(pattern: pattern)
    }()

    public static let htmlTag: NSRegularExpression = {
        let pattern = #"<[^<]+?>"#
        return try! NSRegularExpression(pattern: pattern, options: [])
    }()

    // MARK: - Portal HTML Card Scraping
    public static let portalCardLink: NSRegularExpression = {
        let pattern = #"href="/mod/([^"/?#\s]+)"#
        return try! NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
    }()

    public static let portalCardTitle: NSRegularExpression = {
        let pattern = #"<h2[^>]*>.*?<a[^>]*>(.*?)</a>"#
        return try! NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
    }()

    public static let portalCardOwner: NSRegularExpression = {
        let pattern = #"href="/user/([^"/?#\s]+)"#
        return try! NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
    }()

    public static let portalCardSummary1: NSRegularExpression = {
        let pattern = #"<p\s+class="[^"<>]*result-field[^"<>]*"[^>]*>(.*?)(?:</p>|</div>)"#
        return try! NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
    }()

    public static let portalCardSummary2: NSRegularExpression = {
        let pattern = #"<p[^>]*class="[^"<>]*line-clamp[^"<>]*"[^>]*>(.*?)(?:</p>|</div>)"#
        return try! NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
    }()

    public static let portalCardSummary3: NSRegularExpression = {
        let pattern = #"<div class="mod-card-summary[^"]*"[^>]*>(.*?)</div>"#
        return try! NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
    }()

    public static let portalCardVersions: NSRegularExpression = {
        let pattern = #"title="Available for these Factorio versions"[^>]*>.*?<i[^>]*></i>\s*([^<\n]+)"#
        return try! NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
    }()

    public static let portalCardDownloads: NSRegularExpression = {
        let pattern = #"title="Downloads[^"]*"[^>]*>.*?<span title="(\d+)""#
        return try! NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
    }()

    public static let portalCardLastUpdated: NSRegularExpression = {
        let pattern = #"title="Last updated"[^>]*>.*?<span[^>]*>([^<]+)</span>"#
        return try! NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
    }()

    // MARK: - Helpers
    public static func firstCapturedGroup(in string: String, regex: NSRegularExpression, groupIndex: Int = 1) -> String? {
        let range = NSRange(location: 0, length: string.utf16.count)
        guard let match = regex.firstMatch(in: string, options: [], range: range),
              match.numberOfRanges > groupIndex,
              match.range(at: groupIndex).location != NSNotFound,
              let groupRange = Range(match.range(at: groupIndex), in: string) else {
            return nil
        }
        return String(string[groupRange])
    }
}
