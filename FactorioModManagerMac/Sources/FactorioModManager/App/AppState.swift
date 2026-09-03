import Foundation
import SwiftUI

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    // MARK: - Navigation
    @Published public var selectedTab: SidebarTab = .installed
    @Published public var selectedModDetail: LocalMod? = nil
    @Published public var selectedModInfoDetail: ModInfo? = nil
    @Published public var isDetailSheetPresented: Bool = false
    @Published public var isKeyboardShortcutsSheetPresented: Bool = false

    // MARK: - Settings (Persisted in AppStorage/UserDefaults)
    @AppStorage("custom_mods_dir") private var customModsDirPath: String = ""
    @AppStorage("custom_factorio_ver") public var customFactorioVersion: String = ""
    @AppStorage("clean_old_versions") public var cleanOldVersions: Bool = true
    @AppStorage("auto_enable_mods") public var autoEnableMods: Bool = true

    // MARK: - Core Services & Managers
    @Published public var modsDirectory: URL = ModListManager.defaultFactorioModsDir()
    @Published public var detectedFactorioVersion: String = "2.1"

    public var effectiveFactorioVersion: String {
        customFactorioVersion.isEmpty ? detectedFactorioVersion : customFactorioVersion
    }

    public var effectiveFactorioBranch: String {
        let full = effectiveFactorioVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = full.components(separatedBy: ".")
        if parts.count >= 2 {
            return "\(parts[0]).\(parts[1])"
        }
        return full
    }

    public private(set) var modListMgr: ModListManager = ModListManager()

    // MARK: - Installed Mods State
    @Published public var installedMods: [LocalMod] = []
    @Published public var officialMods: [LocalMod] = []
    @Published public var communityMods: [LocalMod] = []
    @Published public var installedModsMap: [String: [LocalMod]] = [:]
    @Published public var modStates: [String: Bool] = [:]
    @Published public var isLoadingMods: Bool = false
    @Published public var modPortalOwners: [String: String] = [:]

    // MARK: - Profiles State
    @Published public var profiles: [Profile] = []

    // MARK: - Updates State
    @Published public var updatesAvailable: [ModUpdateItem] = []
    @Published public var isCheckingUpdates: Bool = false
    @Published public var updatesCheckedCount: Int = 0
    @Published public var updatesTotalCount: Int = 0
    @Published public var isDirectUpdating: Bool = false
    @Published public var directUpdateCurrentCount: Int = 0
    @Published public var directUpdateTotalCount: Int = 0

    // MARK: - Search Portal State
    @Published public var searchResults: [SearchModItem] = []
    @Published public var isSearching: Bool = false
    @Published public var lastSearchQuery: String = ""

    // MARK: - Author Browse State
    @Published public var authorResults: [AuthorModItem] = []
    @Published public var isFetchingAuthor: Bool = false
    @Published public var currentAuthorName: String = ""

    // MARK: - Optional Mods State
    @Published public var optionalMods: [OptionalModItem] = []
    @Published public var isScanningOptional: Bool = false
    public var cachedModInfo: [String: ModInfo] = [:]

    // MARK: - Modpacks State
    @Published public var savedModpacks: [(name: String, url: URL)] = []
    @Published public var portalModpacks: [PortalModpackItem] = []
    @Published public var isLoadingPortalModpacks: Bool = false
    public var isExclusiveModpackResolution: Bool = false

    // MARK: - Resolution & Downloads State
    @Published public var isResolving: Bool = false
    @Published public var resolvingStatusText: String = ""
    @Published public var currentResolutionResult: ResolutionResult? = nil
    @Published public var isResolutionModalPresented: Bool = false
    @Published public var downloadProgressList: [DownloadProgress] = []
    @Published public var isDownloading: Bool = false

    // MARK: - Notifications
    @Published public var currentNotification: AppNotification? = nil

    private var fileWatcherSource: DispatchSourceFileSystemObject? = nil
    private var activeObserver: NSObjectProtocol? = nil

    private init() {
        if !customModsDirPath.isEmpty {
            let url = URL(fileURLWithPath: (customModsDirPath as NSString).expandingTildeInPath)
            self.modsDirectory = url
            self.modListMgr = ModListManager(modsDirectory: url)
        } else {
            let defaultDir = ModListManager.defaultFactorioModsDir()
            self.modsDirectory = defaultDir
            self.modListMgr = ModListManager(modsDirectory: defaultDir)
        }
        refreshAll()
        setupDiskSyncWatcher()
    }

    deinit {
        fileWatcherSource?.cancel()
        if let obs = activeObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    // MARK: - Refresh
    public func refreshAll() {
        detectedFactorioVersion = modListMgr.detectInstalledFactorioVersion()
        loadInstalledMods()
        loadProfiles()
        loadPortalModpacks()
        loadSavedModpacks()
    }

    // MARK: - Directory Management
    public func setModsDirectory(_ url: URL) {
        self.modsDirectory = url
        self.customModsDirPath = url.path
        self.modListMgr = ModListManager(modsDirectory: url)
        refreshAll()
        startDirectoryWatcher()
    }

    public func resetModsDirectory() {
        self.customModsDirPath = ""
        let defaultDir = ModListManager.defaultFactorioModsDir()
        self.modsDirectory = defaultDir
        self.modListMgr = ModListManager(modsDirectory: defaultDir)
        refreshAll()
        startDirectoryWatcher()
    }

    private func setupDiskSyncWatcher() {
        if activeObserver == nil {
            activeObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.syncModStatesFromDisk()
                }
            }
        }
        startDirectoryWatcher()
    }

    private func startDirectoryWatcher() {
        fileWatcherSource?.cancel()
        fileWatcherSource = nil

        let dirPath = modsDirectory.path
        let fd = open(dirPath, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .attrib, .link],
            queue: DispatchQueue.global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.syncModStatesFromDisk()
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        self.fileWatcherSource = source
    }

    public func syncModStatesFromDisk() {
        let diskStates = modListMgr.readModListJson()
        var hasChanges = false

        if diskStates != self.modStates {
            self.modStates = diskStates
            hasChanges = true
        }

        for i in 0..<installedMods.count {
            let diskEnabled = diskStates[installedMods[i].name] ?? true
            if installedMods[i].enabled != diskEnabled {
                installedMods[i].enabled = diskEnabled
                hasChanges = true
            }
        }
        for i in 0..<officialMods.count {
            let diskEnabled = diskStates[officialMods[i].name] ?? true
            if officialMods[i].enabled != diskEnabled {
                officialMods[i].enabled = diskEnabled
                hasChanges = true
            }
        }
        for i in 0..<communityMods.count {
            let diskEnabled = diskStates[communityMods[i].name] ?? true
            if communityMods[i].enabled != diskEnabled {
                communityMods[i].enabled = diskEnabled
                hasChanges = true
            }
        }

        if hasChanges {
            objectWillChange.send()
        }
    }

    // MARK: - Notifications Helper
    public func showNotification(title: String, message: String, isError: Bool = false) {
        currentNotification = AppNotification(title: title, message: message, isError: isError)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
            if self?.currentNotification?.message == message {
                self?.currentNotification = nil
            }
        }
    }

    // MARK: - Launch Factorio
    public func launchFactorio() {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser

        let candidates = [
            URL(fileURLWithPath: "/Applications/factorio.app"),
            URL(fileURLWithPath: "/Applications/Factorio.app"),
            home.appendingPathComponent("Applications/factorio.app"),
            home.appendingPathComponent("Applications/Factorio.app"),
            home.appendingPathComponent("Library/Application Support/Steam/steamapps/common/Factorio/factorio.app")
        ]

        for appURL in candidates {
            if fileManager.fileExists(atPath: appURL.path) {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
                    if let err = error {
                        Task { @MainActor in
                            self.showNotification(title: "Factorio", message: err.localizedDescription, isError: true)
                        }
                    }
                }
                return
            }
        }

        if let steamURL = URL(string: "steam://run/427520"), NSWorkspace.shared.urlForApplication(toOpen: steamURL) != nil {
            NSWorkspace.shared.open(steamURL)
            return
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        proc.arguments = ["-a", "factorio"]
        try? proc.run()
    }

    /// Navigate to Browse by Author tab and load mods for the given author
    public func navigateToAuthor(_ author: String) {
        let clean = author.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        self.isDetailSheetPresented = false
        self.selectedTab = .authors
        Task {
            await self.fetchAuthorMods(author: clean)
        }
    }
}
