import Foundation

/// Blazing-fast pure-Swift HTML entity decoder that replaces slow NSAttributedString WebKit parsing.
public enum HTMLEntityDecoder {
    private static let namedEntities: [String: String] = [
        "&amp;": "&",
        "&quot;": "\"",
        "&apos;": "'",
        "&#39;": "'",
        "&lt;": "<",
        "&gt;": ">",
        "&nbsp;": " ",
        "&copy;": "©",
        "&reg;": "®",
        "&trade;": "™",
        "&mdash;": "—",
        "&ndash;": "–",
        "&hellip;": "…",
        "&laquo;": "«",
        "&raquo;": "»",
        "&bull;": "•",
        "&euro;": "€",
        "&pound;": "£",
        "&yen;": "¥"
    ]

    /// Unescape HTML entities from a string in pure Swift without loading WebKit or Cocoa text subsystem
    /// Single pass: every entity is decoded exactly once, so "&amp;lt;" stays "&lt;".
    public static func unescape(_ text: String) -> String {
        guard text.contains("&") else { return text }

        var output = ""
        output.reserveCapacity(text.count)
        var index = text.startIndex

        while index < text.endIndex {
            let char = text[index]
            if char == "&",
               let semicolon = text[index...].prefix(maxEntityLength).firstIndex(of: ";"),
               let decoded = decode(text[index...semicolon]) {
                output.append(decoded)
                index = text.index(after: semicolon)
                continue
            }
            output.append(char)
            index = text.index(after: index)
        }

        return output
    }

    /// Longest supported entity is "&#x10FFFF;" / "&#1114111;" (10 characters)
    private static let maxEntityLength = 12

    private static func decode(_ entity: Substring) -> String? {
        if let named = namedEntities[String(entity)] {
            return named
        }
        guard entity.hasPrefix("&#") else { return nil }
        let body = entity.dropFirst(2).dropLast()
        let codePoint: UInt32?
        if body.first == "x" || body.first == "X" {
            codePoint = UInt32(body.dropFirst(), radix: 16)
        } else {
            codePoint = UInt32(body, radix: 10)
        }
        guard let value = codePoint, let scalar = Unicode.Scalar(value) else { return nil }
        return String(Character(scalar))
    }
}
