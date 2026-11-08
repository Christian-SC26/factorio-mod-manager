import Foundation
import Testing
@testable import FactorioModManagerMac

@Suite(.tags(.fast), .timeLimit(.minutes(1)))
struct ModInfoTests {
    @Test
    func picksNewestReleaseOfRequestedBranch() {
        let mod = FkPortal.mod(
            "Squeak Through",
            FkPortal.release("1.8.2", factorio: "1.1"),
            FkPortal.release("2.0.0", factorio: "2.0"),
            FkPortal.release("2.0.1", factorio: "2.0"),
            FkPortal.release("3.0.0", factorio: "2.1")
        )
        #expect(mod.getLatestRelease(targetFactorioBranch: "2.0")?.version.raw == "2.0.1", "newest 2.0 build wins")
    }

    @Test
    func fallsBackToBaseDependencyWhenFactorioVersionIsBlank() {
        let mod = FkPortal.mod("legacy", FkPortal.release("4.2.0", factorio: "", "base >= 2.0.0"))
        #expect(mod.getLatestRelease(targetFactorioBranch: "2.0") != nil, "the base dependency tells the game version")
    }

    @Test
    func returnsNothingForUnsupportedBranch() {
        let mod = FkPortal.mod("m", FkPortal.release("1.0.0", factorio: "1.1"), FkPortal.release("2.0.0", factorio: "2.0"))
        #expect(mod.getLatestRelease(targetFactorioBranch: "0.18") == nil, "no release was made for 0.18")
    }

    @Test
    func returnsNewestReleaseWithoutBranch() {
        let mod = FkPortal.mod("m", FkPortal.release("1.0.0", factorio: "1.1"), FkPortal.release("2.0.0", factorio: "2.1"))
        #expect(mod.getLatestRelease(targetFactorioBranch: nil)?.version.raw == "2.0.0", "no branch means newest")
    }

    @Test
    func findsNewestReleaseAboveMinimum() {
        let mod = FkPortal.mod("m", FkPortal.release("0.9.0", factorio: "2.0"), FkPortal.release("1.0.0", factorio: "2.0"), FkPortal.release("1.5.0", factorio: "2.0"))
        #expect(mod.findRelease(versionReq: "1.0", op: ">=", targetFactorioBranch: nil)?.version.raw == "1.5.0", "'>=' prefers the newest")
    }

    @Test
    func findsNewestReleaseBelowCeiling() {
        let mod = FkPortal.mod("m", FkPortal.release("1.0.0", factorio: "2.0"), FkPortal.release("1.9.9", factorio: "2.0"), FkPortal.release("2.0.0", factorio: "2.0"))
        #expect(mod.findRelease(versionReq: "2.0.0", op: "<", targetFactorioBranch: nil)?.version.raw == "1.9.9", "'<' excludes the ceiling")
    }

    @Test
    func findsNothingForUnknownExactVersion() {
        let mod = FkPortal.mod("m", FkPortal.release("1.0.0", factorio: "2.0"))
        #expect(mod.findRelease(versionReq: "9.9.9", op: "==", targetFactorioBranch: nil) == nil, "no such release exists")
    }

    @Test
    func respectsBranchWhenSearchingByConstraint() {
        let mod = FkPortal.mod("m", FkPortal.release("1.8.2", factorio: "1.1"), FkPortal.release("2.0.0", factorio: "2.0"))
        #expect(mod.findRelease(versionReq: "1.0", op: ">=", targetFactorioBranch: "1.1")?.version.raw == "1.8.2", "2.0.0 is for another game")
    }

    @Test
    func usesNameAsTitleWhenTitleIsBlank() {
        let name = "bob_lib-2"
        let mod = ModInfo(name: name, title: "", owner: "o", summary: "", category: "", downloadsCount: 0, releases: [], description: "", changelog: "", screenshots: [], thumbnail: nil)
        #expect(mod.title == name, "a mod always has something to show as its title")
    }

    @Test
    func reportsNoFactorioVersionWithoutReleases() {
        let mod = FkPortal.mod("unreleased")
        #expect(mod.factorioVersion.isEmpty, "a mod without releases supports nothing")
    }
}
