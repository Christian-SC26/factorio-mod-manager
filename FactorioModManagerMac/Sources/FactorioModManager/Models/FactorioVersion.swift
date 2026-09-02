import Foundation

/// Represents a Factorio semantic version (e.g. "1.1.80", "2.0.28", "2.1.17", "0.17.2-1").
public struct FactorioVersion: Comparable, Hashable, CustomStringConvertible, Codable, Sendable {
    public let raw: String
    public let parts: [Int]

    public init(_ versionStr: String) {
        let trimmed = versionStr.trimmingCharacters(in: .whitespacesAndNewlines)
        self.raw = trimmed
        // Strip suffixes like -1 or +build
        let clean = trimmed.components(separatedBy: CharacterSet(charactersIn: "-+"))[0]
        let segments = clean.components(separatedBy: ".")
        var parsed: [Int] = []
        for seg in segments {
            if let num = Int(seg) {
                parsed.append(num)
            } else {
                parsed.append(0)
            }
        }
        self.parts = parsed.isEmpty ? [0, 0, 0] : parsed
    }

    public init(parts: [Int]) {
        self.parts = parts.isEmpty ? [0, 0, 0] : parts
        self.raw = parts.map { String($0) }.joined(separator: ".")
    }

    public var description: String {
        raw
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(raw)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let str = try container.decode(String.self)
        self.init(str)
    }

    private static func pad(_ a: [Int], _ b: [Int]) -> ([Int], [Int]) {
        let maxLen = max(a.count, b.count)
        var p1 = a
        var p2 = b
        while p1.count < maxLen { p1.append(0) }
        while p2.count < maxLen { p2.append(0) }
        return (p1, p2)
    }

    public static func == (lhs: FactorioVersion, rhs: FactorioVersion) -> Bool {
        let (p1, p2) = pad(lhs.parts, rhs.parts)
        return p1 == p2
    }

    public static func < (lhs: FactorioVersion, rhs: FactorioVersion) -> Bool {
        let (p1, p2) = pad(lhs.parts, rhs.parts)
        for (a, b) in zip(p1, p2) {
            if a < b { return true }
            if a > b { return false }
        }
        return false
    }

    public static func <= (lhs: FactorioVersion, rhs: FactorioVersion) -> Bool {
        lhs < rhs || lhs == rhs
    }

    public static func > (lhs: FactorioVersion, rhs: FactorioVersion) -> Bool {
        !(lhs <= rhs)
    }

    public static func >= (lhs: FactorioVersion, rhs: FactorioVersion) -> Bool {
        !(lhs < rhs)
    }

    /// Check if this version belongs to branch like "1.1", "2.0", or "2.1"
    public func isCompatibleMajorMinor(_ branch: String) -> Bool {
        let branchVer = FactorioVersion(branch)
        if branchVer.parts.count == 1 {
            return !parts.isEmpty && parts[0] == branchVer.parts[0]
        }
        if branchVer.parts.count >= 2 {
            return parts.count >= 2 && parts[0] == branchVer.parts[0] && parts[1] == branchVer.parts[1]
        }
        return true
    }

    /// Check if this version belongs to the same game generation (e.g. 2.x vs 1.x)
    public func isCompatibleGeneration(_ target: String) -> Bool {
        let targetVer = FactorioVersion(target)
        guard !parts.isEmpty && !targetVer.parts.isEmpty else { return true }
        return parts[0] == targetVer.parts[0]
    }

    public func hash(into hasher: inout Hasher) {
        let padded = parts + Array(repeating: 0, count: max(0, 3 - parts.count))
        hasher.combine(padded)
    }
}
