import Foundation

public enum MarkdownSanitizer {
    public static func sanitize(_ input: String) -> String {
        guard !input.isEmpty else { return "" }

        var text = HTMLEntityDecoder.unescape(input)

        // Convert common HTML formatting to Markdown equivalents
        text = text.replacingOccurrences(of: "<br\\s*/?>", with: "\n\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "</p>", with: "\n\n", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "<p>", with: "", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "</div>", with: "\n", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "<div[^>]*>", with: "", options: .regularExpression)

        text = text.replacingOccurrences(of: "<b>", with: "**", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "</b>", with: "**", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "<strong>", with: "**", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "</strong>", with: "**", options: .caseInsensitive)

        text = text.replacingOccurrences(of: "<i>", with: "*", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "</i>", with: "*", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "<em>", with: "*", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "</em>", with: "*", options: .caseInsensitive)

        text = text.replacingOccurrences(of: "<code>", with: "`", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "</code>", with: "`", options: .caseInsensitive)

        // Fix potential excessive newlines (> 3)
        text = text.replacingOccurrences(of: "\n{4,}", with: "\n\n\n", options: .regularExpression)

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
