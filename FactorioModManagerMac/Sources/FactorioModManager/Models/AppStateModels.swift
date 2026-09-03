import Foundation

public enum SidebarTab: String, CaseIterable, Identifiable, Sendable {
    case installed
    case install
    case updates
    case profiles
    case search
    case authors
    case optional
    case exportImport
    case settings

    public var id: String { rawValue }
}

public struct ModUpdateItem: Identifiable, Hashable, Sendable {
    public var id: String { name }
    public let name: String
    public let title: String
    public let localVersion: FactorioVersion
    public let remoteVersion: FactorioVersion
    public let modInfo: ModInfo

    public init(name: String, title: String, localVersion: FactorioVersion, remoteVersion: FactorioVersion, modInfo: ModInfo) {
        self.name = name
        self.title = title
        self.localVersion = localVersion
        self.remoteVersion = remoteVersion
        self.modInfo = modInfo
    }
}

public struct OptionalModItem: Identifiable, Hashable, Sendable {
    public var id: String { name }
    public let name: String
    public var title: String
    public var owner: String
    public var summary: String
    public var factorioVersions: String
    public var downloadsCount: Int
    public let suggestedBy: [String]

    public init(
        name: String,
        title: String? = nil,
        owner: String = "",
        summary: String = "",
        factorioVersions: String = "",
        downloadsCount: Int = 0,
        suggestedBy: [String]
    ) {
        self.name = name
        self.title = (title != nil && !title!.isEmpty) ? title! : Formatters.formatModNameAsTitle(name)
        self.owner = owner
        self.summary = summary
        self.factorioVersions = factorioVersions
        self.downloadsCount = downloadsCount
        self.suggestedBy = suggestedBy
    }
}

public struct BrokenDependencyInfo: Identifiable, Sendable {
    public var id: String { "\(dependentMod.id)_\(brokenDependencyName)" }
    public let dependentMod: LocalMod
    public let brokenDependencyName: String

    public init(dependentMod: LocalMod, brokenDependencyName: String) {
        self.dependentMod = dependentMod
        self.brokenDependencyName = brokenDependencyName
    }
}

public struct AppNotification: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let message: String
    public let isError: Bool

    public init(id: UUID = UUID(), title: String, message: String, isError: Bool = false) {
        self.id = id
        self.title = title
        self.message = message
        self.isError = isError
    }
}

public extension Notification.Name {
    static let focusModSearch = Notification.Name("fmm_focus_mod_search")
    static let focusModTable = Notification.Name("fmm_focus_mod_table")
}
