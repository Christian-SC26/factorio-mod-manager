import Foundation
import Testing
@testable import FactorioModManagerMac

@Suite(.tags(.fast), .timeLimit(.minutes(1)))
struct RegexHelperTests {
    @Test
    func capturesModNameFromZipFilename() {
        #expect(
            RegexHelper.firstCapturedGroup(in: "space-exploration_0.6.140.zip", regex: RegexHelper.zipFilename, groupIndex: 1) == "space-exploration",
            "the name is everything before the last '_version'"
        )
    }

    @Test
    func capturesVersionFromZipFilename() {
        #expect(
            RegexHelper.firstCapturedGroup(in: "space-exploration_0.6.140.zip", regex: RegexHelper.zipFilename, groupIndex: 2) == "0.6.140",
            "the version follows the last underscore"
        )
    }

    @Test
    func rejectsZipWithoutVersion() {
        #expect(RegexHelper.firstCapturedGroup(in: "mod.zip", regex: RegexHelper.zipFilename, groupIndex: 1) == nil, "no version, no match")
    }

    @Test
    func capturesVersionFromFolderName() {
        #expect(
            RegexHelper.firstCapturedGroup(in: "Krastorio2_1.3.24", regex: RegexHelper.dirModName, groupIndex: 2) == "1.3.24",
            "unpacked mods carry the version in the folder name"
        )
    }

    @Test
    func capturesModFromPortalCardLink() {
        let html = #"<h2 class="title"><a href="/mod/test-mod">My Test Mod</a></h2>"#
        #expect(RegexHelper.firstCapturedGroup(in: html, regex: RegexHelper.portalCardLink, groupIndex: 1) == "test-mod", "reads the slug")
    }

    @Test
    func capturesGameVersionFromLog() {
        let line = "   0.000 2026-11-08 12:00:00; Factorio 2.0.28 (build 80000, mac-arm64, steam, space-age)"
        #expect(RegexHelper.firstCapturedGroup(in: line, regex: RegexHelper.logFactorioVersion, groupIndex: 1) == "2.0.28", "reads the version")
    }

    @Test
    func returnsNothingForMissingOptionalGroup() {
        #expect(
            RegexHelper.firstCapturedGroup(in: "/mod/x/downloads", regex: RegexHelper.portalDownloadVersion, groupIndex: 1) == nil,
            "an unmatched optional group is absent, not empty"
        )
    }

    @Test
    func returnsNothingForGroupBeyondPattern() {
        #expect(
            RegexHelper.firstCapturedGroup(in: "x_1.0.zip", regex: RegexHelper.zipFilename, groupIndex: 7) == nil,
            "asking for a group that does not exist must not crash"
        )
    }
}
