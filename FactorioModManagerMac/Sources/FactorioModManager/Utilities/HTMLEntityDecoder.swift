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
    public static func unescape(_ text: String) -> String {
        guard text.contains("&") else { return text }

        var result = text
        // Fast path: replace most common named entities
        for (entity, replacement) in namedEntities {
            if result.contains(entity) {
                result = result.replacingOccurrences(of: entity, with: replacement)
            }
        }

        // Numeric entity replacement &#...; and &#x...;
        guard result.contains("&#") else { return result }

        var output = ""
        output.reserveCapacity(result.count)
        var iterator = result.makeIterator()

        while let char = iterator.next() {
            if char == "&" {
                var buffer = "&"
                var foundSemicolon = false

                while let next = iterator.next() {
                    buffer.append(next)
                    if next == ";" {
                        foundSemicolon = true
                        break
                    }
                    if buffer.count > 10 {
                        break
                    }
                }

                if foundSemicolon && buffer.hasPrefix("&#") {
                    let content = buffer.dropFirst(2).dropLast(1)
                    if content.hasPrefix("x") || content.hasPrefix("X") {
                        let hexStr = content.dropFirst()
                        if let codePoint = UInt32(hexStr, radix: 16),
                           let unicodeScalar = UnicodeScalar(codePoint) {
                            output.append(Character(unicodeScalar))
                            continue
                        }
                    } else {
                        if let codePoint = UInt32(content, radix: 10),
                           let unicodeScalar = UnicodeScalar(codePoint) {
                            output.append(Character(unicodeScalar))
                            continue
                        }
                    }
                }

                // If not parsed as entity, append buffer as raw text
                output.append(buffer)
            } else {
                output.append(char)
            }
        }

        return output
    }
}
