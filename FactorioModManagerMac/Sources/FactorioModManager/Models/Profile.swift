import Foundation

public struct Profile: Identifiable, Hashable, Codable, Sendable {
    public var id: String { filename ?? name }
    public var name: String
    public var filename: String?
    public let factorioVersion: String?
    public let mods: [String: String]
    public let allStates: [String: Bool]?
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        name: String,
        filename: String? = nil,
        factorioVersion: String? = nil,
        mods: [String: String] = [:],
        allStates: [String: Bool]? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.name = name
        self.filename = filename
        self.factorioVersion = factorioVersion
        self.mods = mods
        self.allStates = allStates
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case name
        case filename
        case factorioVersion = "factorio_version"
        case mods
        case allStates = "all_states"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Unnamed"
        self.filename = try container.decodeIfPresent(String.self, forKey: .filename)
        self.factorioVersion = try container.decodeIfPresent(String.self, forKey: .factorioVersion)
        self.allStates = try container.decodeIfPresent([String: Bool].self, forKey: .allStates)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)

        if let dict = try? container.decode([String: String].self, forKey: .mods) {
            self.mods = dict
        } else if let arr = try? container.decode([String].self, forKey: .mods) {
            var map: [String: String] = [:]
            for item in arr where item != "base" {
                map[item] = "latest"
            }
            self.mods = map
        } else if let objArr = try? container.decode([[String: String]].self, forKey: .mods) {
            var map: [String: String] = [:]
            for item in objArr {
                if let mName = item["name"], mName != "base" {
                    map[mName] = item["version"] ?? "latest"
                }
            }
            self.mods = map
        } else if let rawObjArr = try? container.decode([[String: AnyCodableValue]].self, forKey: .mods) {
            var map: [String: String] = [:]
            var states: [String: Bool] = [:]
            for item in rawObjArr {
                if let mName = item["name"]?.stringValue, mName != "base" {
                    let isEnabled = item["enabled"]?.boolValue ?? true
                    states[mName] = isEnabled
                    if isEnabled {
                        map[mName] = item["version"]?.stringValue ?? "latest"
                    }
                }
            }
            self.mods = map
        } else {
            self.mods = [:]
        }
    }

    public func extractActiveMods() -> Set<String> {
        var active = Set<String>()
        for (k, _) in mods where k != "base" {
            active.insert(k)
        }
        if let states = allStates {
            for (k, enabled) in states where enabled && k != "base" {
                active.insert(k)
            }
        }
        return active
    }
}

// Helper to decode loose polymorphic JSON values
public enum AnyCodableValue: Codable, Hashable, Sendable {
    case string(String)
    case bool(Bool)
    case int(Int)
    case double(Double)

    public var stringValue: String? {
        if case let .string(s) = self { return s }
        return nil
    }

    public var boolValue: Bool? {
        if case let .bool(b) = self { return b }
        return nil
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let boolVal = try? container.decode(Bool.self) {
            self = .bool(boolVal)
        } else if let strVal = try? container.decode(String.self) {
            self = .string(strVal)
        } else if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
        } else if let dblVal = try? container.decode(Double.self) {
            self = .double(dblVal)
        } else {
            self = .string("")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .bool(let b): try container.encode(b)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        }
    }
}
