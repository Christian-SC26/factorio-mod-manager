import Foundation

public final class ModListManager: Sendable {
    public let modsDirectory: URL
    public let modListJsonURL: URL

    public init(modsDirectory: URL? = nil) {
        let dir = modsDirectory ?? Self.defaultFactorioModsDir()
        self.modsDirectory = dir
        self.modListJsonURL = dir.appendingPathComponent("mod-list.json")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    /// Locate default Factorio mods directory on macOS
    public static func defaultFactorioModsDir() -> URL {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser

        // 1. Check custom environment variable
        if let envCustom = ProcessInfo.processInfo.environment["FACTORIO_MODS_DIR"], !envCustom.isEmpty {
            let customUrl = URL(fileURLWithPath: (envCustom as NSString).expandingTildeInPath)
            return customUrl
        }

        // 2. Standard macOS path
        let appSupportFactorio = home.appendingPathComponent("Library/Application Support/factorio", isDirectory: true)
        let standardMods = appSupportFactorio.appendingPathComponent("mods", isDirectory: true)

        if fileManager.fileExists(atPath: appSupportFactorio.path) || fileManager.fileExists(atPath: standardMods.path) {
            return standardMods
        }

        // 3. Fallback to Steam or Home .factorio
        let dotFactorio = home.appendingPathComponent(".factorio/mods", isDirectory: true)
        if fileManager.fileExists(atPath: dotFactorio.deletingLastPathComponent().path) {
            return dotFactorio
        }

        return standardMods
    }

    /// Detect installed Factorio version from logs or app bundles
    public func detectInstalledFactorioVersion() -> String {
        let fileManager = FileManager.default
        let factorioDir = modsDirectory.deletingLastPathComponent()

        // 1. Check logs
        let logCandidates = [
            factorioDir.appendingPathComponent("factorio-current.log"),
            factorioDir.appendingPathComponent("factorio-previous.log"),
            factorioDir.appendingPathComponent("config/factorio-current.log")
        ]

        for logURL in logCandidates {
            if fileManager.fileExists(atPath: logURL.path),
               let handle = try? FileHandle(forReadingFrom: logURL) {
                defer { try? handle.close() }
                if let logData = try? handle.read(upToCount: 8192),
                   let content = String(data: logData, encoding: .utf8) {
                    let lines = content.components(separatedBy: .newlines)
                    for line in lines.prefix(60) {
                        let pattern = #"Factorio\s+(\d+\.\d+\.\d+)"#
                        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                            let range = NSRange(location: 0, length: line.utf16.count)
                            if let match = regex.firstMatch(in: line, options: [], range: range),
                               let vRange = Range(match.range(at: 1), in: line) {
                                return String(line[vRange])
                            }
                        }

                        let modBasePattern = #"Loading\s+mod\s+(?:base|core)\s+(\d+\.\d+\.\d+)"#
                        if let regex = try? NSRegularExpression(pattern: modBasePattern, options: .caseInsensitive) {
                            let range = NSRange(location: 0, length: line.utf16.count)
                            if let match = regex.firstMatch(in: line, options: [], range: range),
                               let vRange = Range(match.range(at: 1), in: line) {
                                return String(line[vRange])
                            }
                        }
                    }
                }
            }
        }

        // 2. Check macOS app bundles
        let home = fileManager.homeDirectoryForCurrentUser
        let appCandidates = [
            URL(fileURLWithPath: "/Applications/factorio.app"),
            home.appendingPathComponent("Applications/factorio.app"),
            home.appendingPathComponent("Library/Application Support/Steam/steamapps/common/Factorio/factorio.app")
        ]

        for app in appCandidates {
            let plistURL = app.appendingPathComponent("Contents/Info.plist")
            if fileManager.fileExists(atPath: plistURL.path),
               let data = try? Data(contentsOf: plistURL),
               let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                if let ver = plist["CFBundleShortVersionString"] as? String ?? plist["CFBundleVersion"] as? String {
                    return ver.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        // 3. Check base info.json
        let baseCandidates = [
            URL(fileURLWithPath: "/Applications/factorio.app/Contents/data/base/info.json"),
            home.appendingPathComponent("Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/data/base/info.json")
        ]

        for base in baseCandidates {
            if fileManager.fileExists(atPath: base.path),
               let data = try? Data(contentsOf: base),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let ver = json["version"] as? String {
                return ver.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return "2.1"
    }

    /// Read mod-list.json into dictionary of [mod_name: enabled_bool]
    public func readModListJson() -> [String: Bool] {
        guard FileManager.default.fileExists(atPath: modListJsonURL.path),
              let data = try? Data(contentsOf: modListJsonURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let mods = json["mods"] as? [[String: Any]] else {
            return ["base": true]
        }

        var result: [String: Bool] = [:]
        for m in mods {
            if let name = m["name"] as? String {
                let enabled = m["enabled"] as? Bool ?? true
                result[name] = enabled
            }
        }
        result["base"] = true
        return result
    }

    /// Quick scan of all mod names present in the directory
    public func scanInstalledModNames() -> Set<String> {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(
            at: modsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var names: Set<String> = []
        for entry in contents {
            let filename = entry.lastPathComponent
            if filename == "mod-list.json" || filename.hasSuffix(".tmp") || filename.hasSuffix(".part") || filename.hasPrefix(".")
                || filename.lowercased() == "modpacks" || filename.lowercased() == ".fmm_profiles" {
                continue
            }

            let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if !isDir, let regex = Self.zipRegex {
                let range = NSRange(location: 0, length: filename.utf16.count)
                if let match = regex.firstMatch(in: filename, options: [], range: range),
                   let nRange = Range(match.range(at: 1), in: filename) {
                    names.insert(String(filename[nRange]))
                    continue
                }
            }

            let baseName = isDir ? filename : entry.deletingPathExtension().lastPathComponent
            if let regex = Self.dirModRegex {
                let range = NSRange(location: 0, length: baseName.utf16.count)
                if let match = regex.firstMatch(in: baseName, options: [], range: range),
                   let nRange = Range(match.range(at: 1), in: baseName) {
                    names.insert(String(baseName[nRange]))
                    continue
                }
            }

            names.insert(baseName)
        }
        return names
    }

    /// Write complete mod states to mod-list.json atomically
    public func writeModListJson(_ states: [String: Bool]) throws {
        try FileManager.default.createDirectory(at: modsDirectory, withIntermediateDirectories: true)

        var modStates = states
        modStates["base"] = true

        // Ensure EVERY installed mod in the directory has an explicit state in mod-list.json
        let allInstalled = scanInstalledModNames()
        for name in allInstalled {
            if modStates[name] == nil {
                modStates[name] = true
            }
        }

        var modsList: [[String: Any]] = []
        // Base always comes first
        modsList.append(["name": "base", "enabled": true])

        // Space Age / official DLC expansions next if present
        let dlcNames = ["elevated-rails", "quality", "space-age"]
        for dlc in dlcNames {
            if let enabled = modStates[dlc] {
                modsList.append(["name": dlc, "enabled": enabled])
            }
        }

        // All other mods alphabetically
        for (name, enabled) in modStates.sorted(by: { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }) {
            if name != "base" && !dlcNames.contains(name) {
                modsList.append(["name": name, "enabled": enabled])
            }
        }

        let dict: [String: Any] = ["mods": modsList]
        let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: modListJsonURL, options: .atomic)
    }

    private static let cacheLock = NSLock()
    private static var infoCache: [String: (Date, LocalModInfo)] = [:]
    private static let zipRegex = try? NSRegularExpression(pattern: #"^(.+)_(\d+(?:\.\d+)*)\.zip$"#, options: .caseInsensitive)
    private static let dirModRegex = try? NSRegularExpression(pattern: #"^(.+)_(\d+(?:\.\d+)*)$"#)

    /// Scan mods directory for all installed mod archives and directories
    public func scanInstalledMods() -> [String: [LocalMod]] {
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: modsDirectory, withIntermediateDirectories: true)
        let states = readModListJson()

        guard let contents = try? fileManager.contentsOfDirectory(
            at: modsDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return [:]
        }

        var installed: [String: [LocalMod]] = [:]

        for entry in contents {
            let filename = entry.lastPathComponent
            if filename == "mod-list.json" || filename.hasSuffix(".tmp") || filename.hasSuffix(".part") || filename.hasPrefix(".")
                || filename.lowercased() == "modpacks" || filename.lowercased() == ".fmm_profiles" {
                continue
            }

            let values = try? entry.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
            let isDir = values?.isDirectory ?? false
            let size = Int64(values?.fileSize ?? 0)
            let modDate = values?.contentModificationDate ?? Date()

            var modName: String? = nil
            var versionStr: String? = nil
            var modInfo: LocalModInfo? = nil

            // Check in-memory metadata cache first (thread-safe)
            Self.cacheLock.lock()
            let cached = Self.infoCache[filename]
            Self.cacheLock.unlock()

            if let cached = cached, cached.0 == modDate {
                modInfo = cached.1
                modName = modInfo?.name
                versionStr = modInfo?.version
            } else {
                // Parse info.json via pure Swift in-memory reader
                if let parsedInfo = LocalMod.loadInfoJson(from: entry, isDirectory: isDir) {
                    modInfo = parsedInfo
                    modName = parsedInfo.name
                    versionStr = parsedInfo.version
                    Self.cacheLock.lock()
                    Self.infoCache[filename] = (modDate, parsedInfo)
                    Self.cacheLock.unlock()
                }
            }

            // Fast fallback to filename if needed
            if modName == nil || versionStr == nil {
                if !isDir, let regex = Self.zipRegex {
                    let range = NSRange(location: 0, length: filename.utf16.count)
                    if let match = regex.firstMatch(in: filename, options: [], range: range),
                       let nRange = Range(match.range(at: 1), in: filename),
                       let vRange = Range(match.range(at: 2), in: filename) {
                        modName = String(filename[nRange])
                        versionStr = String(filename[vRange])
                    }
                }
            }

            if modName == nil || versionStr == nil {
                let baseName = isDir ? filename : entry.deletingPathExtension().lastPathComponent
                if let regex = Self.dirModRegex {
                    let range = NSRange(location: 0, length: baseName.utf16.count)
                    if let match = regex.firstMatch(in: baseName, options: [], range: range),
                       let nRange = Range(match.range(at: 1), in: baseName),
                       let vRange = Range(match.range(at: 2), in: baseName) {
                        modName = String(baseName[nRange])
                        versionStr = String(baseName[vRange])
                    }
                }
            }

            if let name = modName, let ver = versionStr {
                let enabled = states[name] ?? true
                let localMod = LocalMod(
                    name: name,
                    version: FactorioVersion(ver),
                    fileURL: entry,
                    isDirectory: isDir,
                    enabled: enabled,
                    fileSize: size,
                    modificationDate: modDate,
                    info: modInfo
                )

                if installed[name] == nil {
                    installed[name] = []
                }
                installed[name]?.append(localMod)
            }
        }

        // Sort each mod list descending by version
        for name in installed.keys {
            installed[name]?.sort { $0.version > $1.version }
        }

        return installed
    }

    public func enableMods(_ names: [String]) {
        var states = readModListJson()
        for name in names {
            states[name] = true
        }
        try? writeModListJson(states)
    }

    public func disableMods(_ names: [String]) {
        var states = readModListJson()
        for name in names where name != "base" {
            states[name] = false
        }
        try? writeModListJson(states)
    }

    public func setModState(_ name: String, enabled: Bool) {
        if name == "base" && !enabled { return }
        var states = readModListJson()
        states[name] = enabled
        try? writeModListJson(states)
    }

    public func toggleMod(_ name: String) -> Bool {
        var states = readModListJson()
        let current = states[name] ?? true
        let newState = !current
        states[name] = newState
        try? writeModListJson(states)
        return newState
    }

    public func removeMod(_ name: String, deleteFiles: Bool = true) -> Int {
        var removedCount = 0
        if deleteFiles {
            let installed = scanInstalledMods()
            if let list = installed[name] {
                for m in list {
                    do {
                        try FileManager.default.removeItem(at: m.fileURL)
                        removedCount += 1
                    } catch {}
                }
            }
        }

        var states = readModListJson()
        states.removeValue(forKey: name)
        try? writeModListJson(states)
        return removedCount
    }

    // MARK: - Profiles

    public var profilesDirectory: URL {
        let p = modsDirectory.appendingPathComponent(".fmm_profiles", isDirectory: true)
        try? FileManager.default.createDirectory(at: p, withIntermediateDirectories: true)
        return p
    }

    public static func safeProfileFilename(from name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "\\/:*?\"<>|")
        let cleaned = name.components(separatedBy: invalidChars).joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "default" : cleaned
    }

    public func listProfiles() -> [Profile] {
        let pDir = profilesDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(at: pDir, includingPropertiesForKeys: nil) else {
            return []
        }

        var profiles: [Profile] = []
        for file in files where file.pathExtension.lowercased() == "json" {
            let baseName = file.deletingPathExtension().lastPathComponent
            if let data = try? Data(contentsOf: file),
               var prof = try? JSONDecoder().decode(Profile.self, from: data) {
                let resolvedName = (prof.name.isEmpty || prof.name == "Unnamed") ? baseName : prof.name
                prof.name = resolvedName
                prof.filename = file.lastPathComponent
                profiles.append(prof)
            }
        }
        return profiles.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func saveProfile(name: String, states: [String: Bool]? = nil) throws -> URL {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            throw NSError(domain: "ProfileError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Profile name cannot be empty."])
        }

        let finalStates = states ?? readModListJson()
        let installed = scanInstalledMods()

        var activeMods: [String: String] = [:]
        for (mName, isEnabled) in finalStates where isEnabled && mName != "base" {
            if let local = installed[mName]?.first {
                activeMods[mName] = local.version.raw
            } else {
                activeMods[mName] = "latest"
            }
        }

        let safeFilename = Self.safeProfileFilename(from: cleanName)
        let profile = Profile(
            name: cleanName,
            filename: "\(safeFilename).json",
            factorioVersion: detectInstalledFactorioVersion(),
            mods: activeMods,
            allStates: finalStates,
            createdAt: Date(),
            updatedAt: Date()
        )

        let targetURL = profilesDirectory.appendingPathComponent("\(safeFilename).json")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(profile)
        try data.write(to: targetURL, options: .atomic)
        return targetURL
    }

    public func loadProfile(name: String) -> (success: Bool, activated: [String], missing: [String]) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeFilename = Self.safeProfileFilename(from: cleanName)

        var targetURL = profilesDirectory.appendingPathComponent("\(safeFilename).json")
        if !FileManager.default.fileExists(atPath: targetURL.path) {
            let directURL = profilesDirectory.appendingPathComponent("\(cleanName).json")
            if FileManager.default.fileExists(atPath: directURL.path) {
                targetURL = directURL
            } else if FileManager.default.fileExists(atPath: profilesDirectory.appendingPathComponent(cleanName).path) {
                targetURL = profilesDirectory.appendingPathComponent(cleanName)
            } else {
                let all = listProfiles()
                if let matched = all.first(where: { $0.name.localizedCaseInsensitiveCompare(cleanName) == .orderedSame || $0.filename == cleanName }) {
                    let matchedFile = matched.filename ?? "\(Self.safeProfileFilename(from: matched.name)).json"
                    targetURL = profilesDirectory.appendingPathComponent(matchedFile)
                }
            }
        }

        guard FileManager.default.fileExists(atPath: targetURL.path),
              let data = try? Data(contentsOf: targetURL),
              let profile = try? JSONDecoder().decode(Profile.self, from: data) else {
            return (false, [], [])
        }

        let installedNames = scanInstalledModNames()
        var newStates: [String: Bool] = [:]

        // If the profile saved complete states (both on and off), restore them faithfully
        if let savedStates = profile.allStates, !savedStates.isEmpty {
            for (mName, isEnabled) in savedStates {
                newStates[mName] = isEnabled
            }
            // For any installed mod not mentioned in profile, disable it
            for mName in installedNames {
                if newStates[mName] == nil {
                    newStates[mName] = false
                }
            }
        } else {
            // For legacy profiles with only active mods list:
            for mName in installedNames {
                newStates[mName] = false
            }
            for (mName, _) in profile.mods {
                newStates[mName] = true
            }
        }

        newStates["base"] = true

        var activated: [String] = []
        var missing: [String] = []

        for (mName, isEnabled) in newStates where isEnabled && mName != "base" {
            if installedNames.contains(mName) || VIRTUAL_BUILTINS.contains(mName.lowercased()) {
                activated.append(mName)
            } else {
                missing.append(mName)
            }
        }

        do {
            try writeModListJson(newStates)
            return (true, activated, missing)
        } catch {
            return (false, [], [])
        }
    }

    public func deleteProfile(name: String, filename: String? = nil) -> Bool {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeFilename = Self.safeProfileFilename(from: cleanName)

        var candidateURLs: [URL] = []
        if let fn = filename {
            candidateURLs.append(profilesDirectory.appendingPathComponent(fn))
        }
        candidateURLs.append(profilesDirectory.appendingPathComponent("\(safeFilename).json"))
        candidateURLs.append(profilesDirectory.appendingPathComponent("\(cleanName).json"))
        candidateURLs.append(profilesDirectory.appendingPathComponent(cleanName))

        for targetURL in candidateURLs {
            if FileManager.default.fileExists(atPath: targetURL.path) {
                do {
                    try FileManager.default.removeItem(at: targetURL)
                    return true
                } catch {}
            }
        }

        let all = listProfiles()
        if let matched = all.first(where: { $0.name.localizedCaseInsensitiveCompare(cleanName) == .orderedSame || $0.filename == cleanName }) {
            let matchedFile = matched.filename ?? "\(Self.safeProfileFilename(from: matched.name)).json"
            let targetURL = profilesDirectory.appendingPathComponent(matchedFile)
            if FileManager.default.fileExists(atPath: targetURL.path) {
                do {
                    try FileManager.default.removeItem(at: targetURL)
                    return true
                } catch {}
            }
        }

        return false
    }

    // MARK: - Modpack Export & Import

    public var modpacksDirectory: URL {
        let p = modsDirectory.appendingPathComponent("modpacks", isDirectory: true)
        try? FileManager.default.createDirectory(at: p, withIntermediateDirectories: true)
        return p
    }

    public func listSavedModpacks() -> [(name: String, url: URL)] {
        let pDir = modpacksDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(at: pDir, includingPropertiesForKeys: nil) else {
            return []
        }
        return files
            .filter { ["json", "txt"].contains($0.pathExtension.lowercased()) }
            .map { (name: $0.deletingPathExtension().lastPathComponent, url: $0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func exportModpack(to destinationURL: URL) throws -> Int {
        let states = readModListJson()
        let installed = scanInstalledMods()

        var entries: [[String: String]] = []
        for (name, enabled) in states where enabled && name != "base" {
            let ver = installed[name]?.first?.version.raw ?? "latest"
            entries.append([
                "name": name,
                "version": ver,
                "url": "https://mods.factorio.com/mod/\(name)"
            ])
        }

        if destinationURL.pathExtension.lowercased() == "json" {
            let dict: [String: Any] = [
                "factorio_version": detectInstalledFactorioVersion(),
                "mods": entries
            ]
            let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: destinationURL, options: .atomic)
        } else {
            var txt = ""
            for item in entries {
                if let u = item["url"] {
                    txt += "\(u)\n"
                }
            }
            try txt.write(to: destinationURL, atomically: true, encoding: .utf8)
        }

        return entries.count
    }

    public func importModpack(from sourceURL: URL) throws -> [String] {
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw NSError(domain: "FMM", code: 404, userInfo: [NSLocalizedDescriptionKey: "File not found: \(sourceURL.path)"])
        }

        var targets: [String] = []

        if sourceURL.pathExtension.lowercased() == "json" {
            let data = try Data(contentsOf: sourceURL)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let rawMods = json["mods"] as? [[String: Any]] {
                    for item in rawMods {
                        if let name = item["name"] as? String, !VIRTUAL_BUILTINS.contains(name.lowercased()) {
                            let url = item["url"] as? String ?? name
                            targets.append(url)
                        }
                    }
                } else if let rawMods = json["mods"] as? [String: String] {
                    for (k, _) in rawMods where !VIRTUAL_BUILTINS.contains(k.lowercased()) {
                        targets.append(k)
                    }
                }
            } else if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                for item in arr {
                    if let name = item["name"] as? String, !VIRTUAL_BUILTINS.contains(name.lowercased()) {
                        let url = item["url"] as? String ?? name
                        targets.append(url)
                    }
                }
            } else if let strArr = try? JSONSerialization.jsonObject(with: data) as? [String] {
                for item in strArr where !VIRTUAL_BUILTINS.contains(item.lowercased()) {
                    targets.append(item)
                }
            }
        } else {
            let content = try String(contentsOf: sourceURL, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                    targets.append(trimmed)
                }
            }
        }

        return targets
    }
}
