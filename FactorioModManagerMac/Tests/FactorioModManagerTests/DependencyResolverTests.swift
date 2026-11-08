import Foundation
import Testing
@testable import FactorioModManagerMac

@Suite(.tags(.fast), .timeLimit(.minutes(1)))
struct DependencyResolverTests {
    @Test
    func resolvesTransitiveDependencies() async throws {
        let portal = FkPortal(
            FkPortal.mod("Squeak Through", FkPortal.release("1.0.0", factorio: "2.0", "bob_lib-2 >= 1.0.0")),
            FkPortal.mod("bob_lib-2", FkPortal.release("1.2.0", factorio: "2.0", "K2 core")),
            FkPortal.mod("K2 core", FkPortal.release("0.0.1", factorio: "2.0"))
        )
        let resolver = DependencyResolver(client: portal, modListMgr: try FkMods().manager(), targetFactorioBranch: "2.0", includeRecommended: true, includeOptional: false, forceReinstall: false)
        let result = await resolver.resolve(targets: ["Squeak Through"], onProgress: nil)
        #expect(Set(result.modsToDownload.map(\.name)) == ["Squeak Through", "bob_lib-2", "K2 core"], "the whole chain is downloaded")
    }

    @Test
    func reportsConflictBetweenIncompatibleTargets() async throws {
        let portal = FkPortal(
            FkPortal.mod("modA", FkPortal.release("1.0.0", factorio: "2.0", "! modB")),
            FkPortal.mod("modB", FkPortal.release("1.0.0", factorio: "2.0"))
        )
        let resolver = DependencyResolver(client: portal, modListMgr: try FkMods().manager(), targetFactorioBranch: "2.0", includeRecommended: true, includeOptional: false, forceReinstall: false)
        let result = await resolver.resolve(targets: ["modA", "modB"], onProgress: nil)
        #expect(result.conflicts.map { [$0.modA, $0.modB] } == [["modA", "modB"]], "modA declares itself incompatible with modB")
    }

    @Test
    func reportsConflictWithInstalledEnabledMod() async throws {
        let portal = FkPortal(FkPortal.mod("newcomer", FkPortal.release("1.0.0", factorio: "2.0", "! rival mod")))
        let resolver = DependencyResolver(client: portal, modListMgr: try FkMods().folder("rival mod", "1.0.0").manager(), targetFactorioBranch: "2.0", includeRecommended: true, includeOptional: false, forceReinstall: false)
        let result = await resolver.resolve(targets: ["newcomer"], onProgress: nil)
        #expect(result.conflicts.count == 1, "an enabled installed mod conflicts as well")
    }

    @Test
    func ignoresBuiltinDependencies() async throws {
        let portal = FkPortal(FkPortal.mod("modA", FkPortal.release("1.0.0", factorio: "2.0", "base >= 2.0", "space-age", "? quality")))
        let resolver = DependencyResolver(client: portal, modListMgr: try FkMods().manager(), targetFactorioBranch: "2.0", includeRecommended: true, includeOptional: true, forceReinstall: false)
        let result = await resolver.resolve(targets: ["modA"], onProgress: nil)
        #expect(result.missingMods.isEmpty, "base and the expansions come with the game, not the portal")
    }

    @Test
    func reportsMissingDependencyWithItsParent() async throws {
        let portal = FkPortal(FkPortal.mod("modA", FkPortal.release("1.0.0", factorio: "2.0", "ghost mod")))
        let resolver = DependencyResolver(client: portal, modListMgr: try FkMods().manager(), targetFactorioBranch: "2.0", includeRecommended: true, includeOptional: false, forceReinstall: false)
        let result = await resolver.resolve(targets: ["modA"], onProgress: nil)
        #expect(result.missingMods == [MissingMod(name: "ghost mod", requiredBy: "modA")], "the user must see who needs the missing mod")
    }

    @Test
    func reportsTargetWithoutReleaseForBranch() async throws {
        let portal = FkPortal(FkPortal.mod("old-mod", FkPortal.release("0.4.0", factorio: "1.1")))
        let resolver = DependencyResolver(client: portal, modListMgr: try FkMods().manager(), targetFactorioBranch: "2.0", includeRecommended: true, includeOptional: false, forceReinstall: false)
        let result = await resolver.resolve(targets: ["old-mod"], onProgress: nil)
        #expect(result.missingMods.map(\.name) == ["old-mod"], "a 1.1-only mod cannot be installed on 2.0")
    }

    @Test
    func keepsInstalledModThatIsUpToDate() async throws {
        let portal = FkPortal(FkPortal.mod("flib", FkPortal.release("0.15.0", factorio: "2.0")))
        let resolver = DependencyResolver(client: portal, modListMgr: try FkMods().folder("flib", "0.15.0").manager(), targetFactorioBranch: "2.0", includeRecommended: true, includeOptional: false, forceReinstall: false)
        let result = await resolver.resolve(targets: ["flib"], onProgress: nil)
        #expect(result.modsUpToDate.map(\.name) == ["flib"], "nothing to download when the newest release is installed")
    }

    @Test
    func schedulesUpdateForOlderInstalledMod() async throws {
        let portal = FkPortal(FkPortal.mod("flib", FkPortal.release("0.14.0", factorio: "2.0"), FkPortal.release("0.15.0", factorio: "2.0")))
        let resolver = DependencyResolver(client: portal, modListMgr: try FkMods().folder("flib", "0.14.0").manager(), targetFactorioBranch: "2.0", includeRecommended: true, includeOptional: false, forceReinstall: false)
        let result = await resolver.resolve(targets: ["flib"], onProgress: nil)
        #expect(result.modsToDownload.map(\.action) == [.update], "an older local copy is updated")
    }

    @Test
    func reinstallsUpToDateModWhenForced() async throws {
        let portal = FkPortal(FkPortal.mod("flib", FkPortal.release("0.15.0", factorio: "2.0")))
        let resolver = DependencyResolver(client: portal, modListMgr: try FkMods().folder("flib", "0.15.0").manager(), targetFactorioBranch: "2.0", includeRecommended: true, includeOptional: false, forceReinstall: true)
        let result = await resolver.resolve(targets: ["flib"], onProgress: nil)
        #expect(result.modsToDownload.map(\.action) == [.download], "force means download again")
    }

    @Test
    func survivesCircularDependencies() async throws {
        let portal = FkPortal(
            FkPortal.mod("chicken", FkPortal.release("1.0.0", factorio: "2.0", "egg")),
            FkPortal.mod("egg", FkPortal.release("1.0.0", factorio: "2.0", "chicken >= 1.0"))
        )
        let resolver = DependencyResolver(client: portal, modListMgr: try FkMods().manager(), targetFactorioBranch: "2.0", includeRecommended: true, includeOptional: false, forceReinstall: false)
        let result = await resolver.resolve(targets: ["chicken"], onProgress: nil)
        #expect(result.modsToDownload.map(\.name) == ["chicken", "egg"], "a cycle resolves once and terminates")
    }

    @Test
    func skipsOptionalDependenciesByDefault() async throws {
        let portal = FkPortal(FkPortal.mod("core-pack", FkPortal.release("1.0.0", factorio: "2.0", "? extra")), FkPortal.mod("extra", FkPortal.release("1.0.0", factorio: "2.0")))
        let resolver = DependencyResolver(client: portal, modListMgr: try FkMods().manager(), targetFactorioBranch: "2.0", includeRecommended: true, includeOptional: false, forceReinstall: false)
        let result = await resolver.resolve(targets: ["core-pack"], onProgress: nil)
        #expect(result.modsToDownload.map(\.name) == ["core-pack"], "optional means not installed unless asked")
    }

    @Test
    func includesOptionalDependenciesOfTargetOnRequest() async throws {
        let portal = FkPortal(FkPortal.mod("core-pack", FkPortal.release("1.0.0", factorio: "2.0", "? extra")), FkPortal.mod("extra", FkPortal.release("1.0.0", factorio: "2.0")))
        let resolver = DependencyResolver(client: portal, modListMgr: try FkMods().manager(), targetFactorioBranch: "2.0", includeRecommended: true, includeOptional: true, forceReinstall: false)
        let result = await resolver.resolve(targets: ["core-pack"], onProgress: nil)
        #expect(result.modsToDownload.map(\.name) == ["core-pack", "extra"], "the user asked for optional mods")
    }

    @Test
    func warnsAboutModMadeForAnotherGeneration() async throws {
        let portal = FkPortal(FkPortal.mod("relic", FkPortal.release("1.0.0", factorio: "2.0", "base >= 1.1.0")))
        let resolver = DependencyResolver(client: portal, modListMgr: try FkMods().manager(), targetFactorioBranch: "2.0", includeRecommended: true, includeOptional: false, forceReinstall: false)
        let result = await resolver.resolve(targets: ["relic"], onProgress: nil)
        #expect(result.warnings.count == 1, "a mod built against 1.1 must raise a warning on 2.0")
    }

    @Test
    func pinsVersionRequestedByUser() async throws {
        let portal = FkPortal(FkPortal.mod("flib", FkPortal.release("0.14.0", factorio: "2.0"), FkPortal.release("0.15.0", factorio: "2.0")))
        let resolver = DependencyResolver(client: portal, modListMgr: try FkMods().manager(), targetFactorioBranch: "2.0", includeRecommended: true, includeOptional: false, forceReinstall: false)
        let result = await resolver.resolve(targets: ["flib@0.14.0"], onProgress: nil)
        #expect(result.modsToDownload.map(\.release.version.raw) == ["0.14.0"], "the user pinned 0.14.0")
    }

    @Test
    func downloadsReleaseDemandedByLaterConstraint() async throws {
        let portal = FkPortal(
            FkPortal.mod("shared lib", FkPortal.release("1.5.0", factorio: "2.0"), FkPortal.release("2.0.0", factorio: "2.0")),
            FkPortal.mod("old-user", FkPortal.release("1.0.0", factorio: "2.0", "shared lib < 2.0.0")),
            FkPortal.mod("new-user", FkPortal.release("1.0.0", factorio: "2.0", "shared lib >= 2.0.0"))
        )
        let resolver = DependencyResolver(client: portal, modListMgr: try FkMods().folder("shared lib", "1.5.0").manager(), targetFactorioBranch: "2.0", includeRecommended: true, includeOptional: false, forceReinstall: false)
        let result = await resolver.resolve(targets: ["old-user", "new-user"], onProgress: nil)
        #expect(result.modsToDownload.map(\.name).contains("shared lib"), "the selected 2.0.0 is not installed, so it must be downloaded")
    }

    @Test
    func sortsDownloadsAlphabetically() async throws {
        let portal = FkPortal(FkPortal.mod("zeta", FkPortal.release("1.0.0", factorio: "2.0")), FkPortal.mod("Alpha", FkPortal.release("1.0.0", factorio: "2.0")), FkPortal.mod("beta", FkPortal.release("1.0.0", factorio: "2.0")))
        let resolver = DependencyResolver(client: portal, modListMgr: try FkMods().manager(), targetFactorioBranch: "2.0", includeRecommended: true, includeOptional: false, forceReinstall: false)
        let result = await resolver.resolve(targets: ["zeta", "Alpha", "beta"], onProgress: nil)
        #expect(result.modsToDownload.map(\.name) == ["Alpha", "beta", "zeta"], "the list is sorted ignoring case")
    }
}
