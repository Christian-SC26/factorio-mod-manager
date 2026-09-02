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
}

/// Global convenience forwarder for existing code
public func formatBytes(_ size: Int64) -> String {
    Formatters.formatBytes(size)
}
