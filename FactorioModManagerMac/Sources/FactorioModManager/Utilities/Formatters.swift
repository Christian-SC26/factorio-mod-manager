import Foundation

/// Centralized, high-performance formatters for sizes, counts, and dates.
public enum Formatters {
    private static let shortDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()

    /// Format byte sizes in human-readable notation (B, KB, MB, GB)
    public static func formatBytes(_ size: Int64) -> String {
        let doubleSize = Double(size)
        if doubleSize < 1024.0 {
            return "\(size) B"
        } else if doubleSize < 1024.0 * 1024.0 {
            return String(format: "%.1f KB", doubleSize / 1024.0)
        } else if doubleSize < 1024.0 * 1024.0 * 1024.0 {
            return String(format: "%.1f MB", doubleSize / (1024.0 * 1024.0))
        } else {
            return String(format: "%.2f GB", doubleSize / (1024.0 * 1024.0 * 1024.0))
        }
    }

    /// Format download counts in compact notation (e.g. 1.2M, 45.3k, 120)
    public static func formatDownloads(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fk", Double(count) / 1_000.0)
        } else {
            return "\(count)"
        }
    }

    /// Format date to medium localized string
    public static func formatDate(_ date: Date) -> String {
        shortDateFormatter.string(from: date)
    }

    /// Format raw mod identifiers (e.g. "additional-cargo-landing-pads") into clean capitalized title
    public static func formatModNameAsTitle(_ name: String) -> String {
        let cleaned = name.replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        let words = cleaned.split(separator: " ").filter { !$0.isEmpty }
        return words.map { word -> String in
            let lower = word.lowercased()
            if ["se", "cr", "rpg", "t4", "gui", "hud", "ui", "hd", "2d", "3d"].contains(lower) {
                return lower.uppercased()
            }
            if word.count <= 2 {
                return word.uppercased()
            }
            let str = String(word)
            return str.prefix(1).uppercased() + str.dropFirst()
        }.joined(separator: " ")
    }

    /// Check if a title string contains actual human-readable letters rather than just dots or punctuation
    public static func isValidHumanTitle(_ title: String) -> Bool {
        let stripped = title.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .punctuationCharacters)
        return !stripped.isEmpty
    }
}

/// Global convenience forwarder for existing code
public func formatBytes(_ size: Int64) -> String {
    Formatters.formatBytes(size)
}
