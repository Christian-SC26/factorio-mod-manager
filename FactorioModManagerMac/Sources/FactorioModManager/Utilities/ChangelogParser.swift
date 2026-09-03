import Foundation

public struct ChangelogVersionEntry: Identifiable, Hashable, Sendable {
    public var id: String { "\(version)_\(date)" }
    public let version: String
    public let date: String
    public let lines: [String]

    public init(version: String, date: String, lines: [String]) {
        self.version = version
        self.date = date
        self.lines = lines
    }
}

public enum ChangelogParser {
    public static func parse(_ raw: String) -> [ChangelogVersionEntry] {
        guard !raw.isEmpty else { return [] }

        var entries: [ChangelogVersionEntry] = []
        var currentVersion = ""
        var currentDate = ""
        var currentLines: [String] = []

        func flush() {
            if !currentVersion.isEmpty {
                entries.append(ChangelogVersionEntry(
                    version: currentVersion,
                    date: currentDate,
                    lines: currentLines
                ))
            }
            currentVersion = ""
            currentDate = ""
            currentLines = []
        }

        let rawLines = raw.components(separatedBy: .newlines)
        for line in rawLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || (trimmed.count >= 3 && trimmed.allSatisfy({ $0 == "-" || $0 == "=" })) {
                continue
            }

            if trimmed.lowercased().hasPrefix("version:") {
                flush()
                let val = trimmed.dropFirst("version:".count).trimmingCharacters(in: .whitespaces)
                currentVersion = val
            } else if trimmed.lowercased().hasPrefix("date:") && !currentVersion.isEmpty {
                let val = trimmed.dropFirst("date:".count).trimmingCharacters(in: .whitespaces)
                currentDate = val
            } else if !currentVersion.isEmpty {
                currentLines.append(line)
            }
        }
        flush()
        return entries
    }
}
