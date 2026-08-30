import Foundation

public enum DependencyType: String, Codable, Sendable {
    case required = "required"         // No prefix: strictly required
    case recommended = "recommended"   // '+': recommended by author
    case optional = "optional"         // '?': optional addon
    case incompatible = "incompatible" // '!': incompatible conflict
}

public let VIRTUAL_BUILTINS: Set<String> = [
    "base",
    "core",
    "quality",
    "space-age",
    "elevated-rails",
    "recycler"
]

public struct Dependency: Hashable, CustomStringConvertible, Codable, Sendable {
    public let name: String
    public let depType: DependencyType
    public let op: String?
    public let version: FactorioVersion?
    public let rawString: String

    public init(
        name: String,
        depType: DependencyType = .required,
        op: String? = nil,
        version: FactorioVersion? = nil,
        rawString: String = ""
    ) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.depType = depType
        self.op = (op == "=") ? "==" : op
        self.version = version
        self.rawString = rawString
    }

    public var isVirtual: Bool {
        VIRTUAL_BUILTINS.contains(name.lowercased())
    }

    public var isRequired: Bool {
        depType == .required
    }

    public var isConflict: Bool {
        depType == .incompatible
    }

    public var description: String {
        let verStr = (op != nil && version != nil) ? " \(op!) \(version!)" : ""
        return "[\(depType.rawValue)] \(name)\(verStr)"
    }

    /// Parse a Factorio dependency string (e.g. "? base >= 2.0.0", "! conflict-mod", "flib", "+ space-age")
    public static func parse(_ depStr: String) -> Dependency? {
        let trimmed = depStr.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        // Regex pattern matching: prefix? name [op version]?
        let pattern = #"^(?:\s*(\?|\(\?\)|!|~|\+))?\s*([%\w\s\.-]+?)(?:\s*(<=|>=|==|=|<|>)\s*(\d+(?:\.\d+)*))?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return Dependency(name: trimmed, rawString: depStr)
        }

        let range = NSRange(location: 0, length: trimmed.utf16.count)
        guard let match = regex.firstMatch(in: trimmed, options: [], range: range) else {
            return Dependency(name: trimmed, rawString: depStr)
        }

        var prefix: String? = nil
        if match.range(at: 1).location != NSNotFound, let r = Range(match.range(at: 1), in: trimmed) {
            prefix = String(trimmed[r]).trimmingCharacters(in: .whitespaces)
        }

        guard match.range(at: 2).location != NSNotFound, let nameRange = Range(match.range(at: 2), in: trimmed) else {
            return Dependency(name: trimmed, rawString: depStr)
        }
        let name = String(trimmed[nameRange]).trimmingCharacters(in: .whitespaces)

        var op: String? = nil
        if match.range(at: 3).location != NSNotFound, let r = Range(match.range(at: 3), in: trimmed) {
            op = String(trimmed[r])
        }

        var ver: FactorioVersion? = nil
        if match.range(at: 4).location != NSNotFound, let r = Range(match.range(at: 4), in: trimmed) {
            ver = FactorioVersion(String(trimmed[r]))
        }

        // Ignore hidden optional '(?)' and load-order '~' hints completely
        if let p = prefix, (p == "(?)" || p == "( ? )" || p == "~") {
            return nil
        }

        var type = DependencyType.required
        if let p = prefix {
            if p == "!" {
                type = .incompatible
            } else if p == "+" {
                type = .recommended
            } else if p == "?" {
                type = .optional
            }
        }

        return Dependency(
            name: name,
            depType: type,
            op: op,
            version: ver,
            rawString: depStr
        )
    }

    /// Check if targetVersion satisfies this dependency condition
    public func satisfies(_ targetVersion: FactorioVersion) -> Bool {
        guard let req = self.version, let op = self.op else {
            return true
        }

        switch op {
        case "==", "=":
            return targetVersion == req
        case ">=":
            return targetVersion >= req
        case "<=":
            return targetVersion <= req
        case ">":
            return targetVersion > req
        case "<":
            return targetVersion < req
        default:
            return true
        }
    }
}
