import Foundation

public struct Profile: Identifiable, Hashable, Codable, Sendable {
    public var id: String { name }
    public let name: String
    public let factorioVersion: String?
    public let mods: [String: String]
    public let allStates: [String: Bool]?
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        name: String,
        factorioVersion: String? = nil,
        mods: [String: String] = [:],
        allStates: [String: Bool]? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.name = name
        self.factorioVersion = factorioVersion
        self.mods = mods
        self.allStates = allStates
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case name
        case factorioVersion = "factorio_version"
        case mods
        case allStates = "all_states"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Unnamed"
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
