import Foundation

public enum ResolvedAction: String, Codable, Sendable {
    case download = "DOWNLOAD"
    case update = "UPDATE"
    case keep = "KEEP"
    case conflict = "CONFLICT"
}

public struct ResolvedMod: Identifiable, Hashable, Sendable {
    public var id: String { name }
    public let name: String
    public let info: ModInfo
    public var release: ReleaseInfo
    public var requiredBy: Set<String>
    public var recommendedBy: Set<String>
    public var optionalBy: Set<String>
    public let isRoot: Bool
    public let isAlreadyInstalled: Bool
    public let installedVersion: FactorioVersion?
    public var action: ResolvedAction
    public var conflictReasons: [String]

    public init(
        name: String,
        info: ModInfo,
        release: ReleaseInfo,
        requiredBy: Set<String> = [],
        recommendedBy: Set<String> = [],
        optionalBy: Set<String> = [],
        isRoot: Bool = false,
        isAlreadyInstalled: Bool = false,
        installedVersion: FactorioVersion? = nil,
        action: ResolvedAction = .download,
        conflictReasons: [String] = []
    ) {
        self.name = name
        self.info = info
        self.release = release
        self.requiredBy = requiredBy
        self.recommendedBy = recommendedBy
        self.optionalBy = optionalBy
        self.isRoot = isRoot
        self.isAlreadyInstalled = isAlreadyInstalled
        self.installedVersion = installedVersion
        self.action = action
        self.conflictReasons = conflictReasons
    }
}

public struct ModConflict: Identifiable, Hashable, Sendable {
    public var id: String { "\(modA)_\(modB)" }
    public let modA: String
    public let modB: String
    public let reason: String

    public init(modA: String, modB: String, reason: String) {
        self.modA = modA
        self.modB = modB
        self.reason = reason
    }
}

public struct MissingMod: Identifiable, Hashable, Sendable {
    public var id: String { "\(name)_\(requiredBy)" }
    public let name: String
    public let requiredBy: String

    public init(name: String, requiredBy: String) {
        self.name = name
        self.requiredBy = requiredBy
    }
}

public struct ResolutionResult: Sendable {
    public let modsToDownload: [ResolvedMod]
    public let modsUpToDate: [ResolvedMod]
    public let conflicts: [ModConflict]
    public let missingMods: [MissingMod]
    public let warnings: [String]
    public let rootMods: [String]
    public let dependencyGraph: [String: [String]]

    public init(
        modsToDownload: [ResolvedMod] = [],
        modsUpToDate: [ResolvedMod] = [],
        conflicts: [ModConflict] = [],
        missingMods: [MissingMod] = [],
        warnings: [String] = [],
        rootMods: [String] = [],
        dependencyGraph: [String: [String]] = [:]
    ) {
        self.modsToDownload = modsToDownload
        self.modsUpToDate = modsUpToDate
        self.conflicts = conflicts
        self.missingMods = missingMods
        self.warnings = warnings
        self.rootMods = rootMods
        self.dependencyGraph = dependencyGraph
    }
}

public actor DependencyResolver {
    private let client: any ModPortalClientProtocol
    private let modListMgr: any ModListManaging
    private let targetFactorioBranch: String?
    private let includeRecommended: Bool
    private let includeOptional: Bool
    private let forceReinstall: Bool

    private var installedMods: [String: [LocalMod]] = [:]
    private var resolved: [String: ResolvedMod] = [:]
    private var conflicts: [ModConflict] = []
    private var missing: [MissingMod] = []
    private var warnings: [String] = []
    private var graph: [String: [String]] = [:]
    private var onProgress: (@Sendable (String) -> Void)? = nil

    public init(
        client: any ModPortalClientProtocol = ModPortalClient.shared,
        modListMgr: any ModListManaging,
        targetFactorioBranch: String? = nil,
        includeRecommended: Bool = true,
        includeOptional: Bool = false,
        forceReinstall: Bool = false
    ) {
        self.client = client
        self.modListMgr = modListMgr
        self.targetFactorioBranch = targetFactorioBranch
        self.includeRecommended = includeRecommended
        self.includeOptional = includeOptional
        self.forceReinstall = forceReinstall
    }

    public func resolve(targets: [String], onProgress: (@Sendable (String) -> Void)? = nil) async -> ResolutionResult {
        self.onProgress = onProgress
        self.installedMods = modListMgr.scanInstalledMods()
        self.resolved = [:]
        self.conflicts = []
        self.missing = []
        self.warnings = []
        self.graph = [:]

        var rootNames: [String] = []

        for rawInput in targets {
            let (name, verReq, op) = ModPortalClient.parseModInput(rawInput)
            if name.isEmpty { continue }

            onProgress?(name)
            rootNames.append(name)
            await resolveModRecursive(
                modName: name,
                versionReq: verReq,
                op: op,
                parent: nil,
                depType: .required,
                isRoot: true,
                depth: 0
            )
        }

        checkConflicts()

        var toDownload: [ResolvedMod] = []
        var upToDate: [ResolvedMod] = []

        for mod in resolved.values {
            if mod.action == .download || mod.action == .update {
                toDownload.append(mod)
            } else if mod.action == .keep {
                upToDate.append(mod)
            }
        }

        // Sort results cleanly
        toDownload.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        upToDate.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return ResolutionResult(
            modsToDownload: toDownload,
            modsUpToDate: upToDate,
            conflicts: conflicts,
            missingMods: missing,
            warnings: warnings,
            rootMods: rootNames,
            dependencyGraph: graph
        )
    }

    private func resolveModRecursive(
        modName: String,
        versionReq: String?,
        op: String?,
        parent: String?,
        depType: DependencyType,
        isRoot: Bool,
        depth: Int
    ) async {
        // Ignore virtual built-ins (base, core, etc.)
        if FactorioConstants.isVirtualBuiltin(modName) {
            return
        }

        // Track graph
        if let p = parent {
            if graph[p] == nil {
                graph[p] = []
            }
            if !graph[p]!.contains(modName) {
                graph[p]!.append(modName)
            }
        }

        // If already resolved in this session, update requiredBy / check constraint
        if var existing = resolved[modName] {
            if let p = parent {
                if depType == .required {
                    existing.requiredBy.insert(p)
                } else if depType == .recommended {
                    existing.recommendedBy.insert(p)
                } else if depType == .optional {
                    existing.optionalBy.insert(p)
                }
            }

            if let vReq = versionReq, let oper = op {
                let depCheck = Dependency(name: modName, op: oper, version: FactorioVersion(vReq))
                if !depCheck.satisfies(existing.release.version) {
                    if let newRel = existing.info.findRelease(versionReq: vReq, op: oper, targetFactorioBranch: targetFactorioBranch) {
                        existing.release = newRel
                    } else {
                        warnings.append("Version conflict for '\(modName)': requires \(oper) \(vReq) (for \(parent ?? "root")), but release \(existing.release.version) is selected")
                    }
                }
            }
            resolved[modName] = existing
            return
        }

        // Fetch mod info
        let modInfo: ModInfo
        do {
            modInfo = try await client.fetchModInfo(modName)
        } catch {
            missing.append(MissingMod(name: modName, requiredBy: parent ?? "user"))
            warnings.append("Could not find mod '\(modName)' (requested by '\(parent ?? "root")'): \(error.localizedDescription)")
            return
        }

        // Pick matching release
        guard let release = modInfo.findRelease(versionReq: versionReq, op: op, targetFactorioBranch: targetFactorioBranch) else {
            missing.append(MissingMod(name: modName, requiredBy: parent ?? "user"))
            warnings.append("No matching version found for '\(modName)' (\(op ?? "") \(versionReq ?? ""), Factorio: \(targetFactorioBranch ?? "any"))")
            return
        }

        // Check local installation
        var isInstalled = false
        var installedVer: FactorioVersion? = nil
        var action: ResolvedAction = .download

        if let localList = installedMods[modName], let latestLocal = localList.first {
            installedVer = latestLocal.version
            isInstalled = true

            if !forceReinstall {
                if latestLocal.version >= release.version {
                    action = .keep
                } else {
                    action = .update
                }
            }
        }

        var resMod = ResolvedMod(
            name: modName,
            info: modInfo,
            release: release,
            isRoot: isRoot,
            isAlreadyInstalled: isInstalled,
            installedVersion: installedVer,
            action: action
        )

        if let p = parent {
            if depType == .required {
                resMod.requiredBy.insert(p)
            } else if depType == .recommended {
                resMod.recommendedBy.insert(p)
            } else if depType == .optional {
                resMod.optionalBy.insert(p)
            }
        }

        resolved[modName] = resMod

        // Recursively resolve dependencies of this release
        for dep in release.dependencies {
            if dep.isVirtual {
                if dep.name == FactorioConstants.baseModName, let targetBranch = targetFactorioBranch {
                    let targetV = FactorioVersion(targetBranch)
                    if let depV = dep.version {
                        var isCompat = dep.satisfies(targetV)
                        if !depV.parts.isEmpty && !targetV.parts.isEmpty && depV.parts[0] != targetV.parts[0] {
                            isCompat = false
                        }
                        if !isCompat {
                            warnings.append("Mod '\(modName) v\(release.version)' requires Factorio \(dep.op ?? "") \(depV), but target game version is \(targetBranch)")
                        }
                    }
                }
                continue
            }

            if dep.isConflict {
                continue
            }

            var shouldResolve = false
            if dep.isRequired {
                shouldResolve = true
            } else if dep.depType == .recommended && includeRecommended {
                if depth < 2 {
                    shouldResolve = true
                }
            } else if dep.depType == .optional && includeOptional {
                if isRoot {
                    shouldResolve = true
                }
            }

            if shouldResolve {
                await resolveModRecursive(
                    modName: dep.name,
                    versionReq: dep.version?.raw,
                    op: dep.op,
                    parent: modName,
                    depType: dep.depType,
                    isRoot: false,
                    depth: depth + 1
                )
            }
        }
    }

    private func checkConflicts() {
        let keys = Array(resolved.keys)
        for modName in keys {
            guard var resMod = resolved[modName] else { continue }
            for dep in resMod.release.dependencies {
                if dep.isConflict {
                    let conflictTarget = dep.name
                    if resolved[conflictTarget] != nil {
                        conflicts.append(ModConflict(
                            modA: modName,
                            modB: conflictTarget,
                            reason: "Mod '\(modName)' is incompatible with '\(conflictTarget)'"
                        ))
                        resMod.action = .conflict
                        resMod.conflictReasons.append("Incompatible with \(conflictTarget)")
                    } else if let locals = installedMods[conflictTarget], locals.contains(where: { $0.enabled }) {
                        conflicts.append(ModConflict(
                            modA: modName,
                            modB: conflictTarget,
                            reason: "Mod '\(modName)' is incompatible with installed enabled mod '\(conflictTarget)'"
                        ))
                    }
                }
            }
            resolved[modName] = resMod
        }
    }
}
