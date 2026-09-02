import Foundation

/// Unified constants for Factorio built-in content, official expansions, and virtual mods.
public enum FactorioConstants {
    /// Official base mod identifier
    public static let baseModName = "base"

    /// Virtual built-in mods that are part of the Factorio engine/distribution
    public static let virtualBuiltins: Set<String> = [
        "base",
        "core",
        "quality",
        "space-age",
        "elevated-rails",
        "recycler"
    ]

    /// Official DLC expansions released with Factorio 2.0 / Space Age
    public static let dlcExpansions: [String] = [
        "space-age",
        "quality",
        "elevated-rails",
        "recycler"
    ]

    /// All official mods including base
    public static let allOfficialModNames: Set<String> = [
        "base",
        "space-age",
        "quality",
        "elevated-rails",
        "recycler"
    ]

    /// Official mod metadata definitions for UI display
    public struct OfficialModDefinition: Sendable {
        public let name: String
        public let title: String
        public let description: String

        public init(name: String, title: String, description: String) {
            self.name = name
            self.title = title
            self.description = description
        }
    }

    public static let officialExpansions: [OfficialModDefinition] = [
        OfficialModDefinition(
            name: "space-age",
            title: "Space Age",
            description: "Official expansion adding space platforms, interplanetary travel, and new worlds: Vulcanus, Gleba, Fulgora, and Aquilo."
        ),
        OfficialModDefinition(
            name: "quality",
            title: "Quality",
            description: "Official expansion adding quality levels to items, machines, and equipment."
        ),
        OfficialModDefinition(
            name: "elevated-rails",
            title: "Elevated Rails",
            description: "Official expansion adding elevated train ramps, rails, and rail supports."
        ),
        OfficialModDefinition(
            name: "recycler",
            title: "Recycler",
            description: "Official built-in recycling mechanics, data, and recycling facilities."
        )
    ]

    /// Check if a mod name corresponds to an official base or expansion mod
    public static func isOfficialMod(_ name: String) -> Bool {
        allOfficialModNames.contains(name.lowercased())
    }

    /// Check if a mod name is a virtual built-in (base, core, etc.)
    public static func isVirtualBuiltin(_ name: String) -> Bool {
        virtualBuiltins.contains(name.lowercased())
    }
}
