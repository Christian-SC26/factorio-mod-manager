import Foundation

/// Every literal key passed to `loc("...")` anywhere in the production sources.
enum LocalizationKeys {
    static func used(file: String = #filePath) -> [String] {
        let sources = URL(fileURLWithPath: file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources", isDirectory: true)
        let regex = try! NSRegularExpression(pattern: #"\bloc\("([A-Za-z0-9_]+)""#)
        let files = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? []
        var keys = Set<String>()
        for url in files {
            let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                if let range = Range(match.range(at: 1), in: text) {
                    keys.insert(String(text[range]))
                }
            }
        }
        return keys.sorted()
    }
}
