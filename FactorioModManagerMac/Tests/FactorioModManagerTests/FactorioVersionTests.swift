import Foundation
import Testing
@testable import FactorioModManagerMac

@Suite(.tags(.fast), .timeLimit(.minutes(1)))
struct FactorioVersionTests {
    @Test(arguments: [
        ("2.0.28", "2.1.0"),
        ("1.1.80", "2.0.0"),
        ("1.1.5", "1.1.10"),
        ("0.17.79", "0.18"),
        ("2.0", "2.0.1"),
        ("2.0", "2.0.0.1")
    ])
    func ordersOlderVersionBeforeNewer(older: String, newer: String) {
        #expect(FactorioVersion(older) < FactorioVersion(newer), "\(older) must sort before \(newer)")
    }

    @Test(arguments: [("2.0", "2.0.0"), ("1.1.80", "1.1.80"), ("3", "3.0.0.0"), (" 1.2.3\n", "1.2.3")])
    func treatsTrailingZerosAsSameVersion(left: String, right: String) {
        #expect(FactorioVersion(left) == FactorioVersion(right), "\(left) and \(right) name the same release")
    }

    @Test
    func hashesEqualVersionsIdentically() {
        #expect(
            FactorioVersion("1.2.3.0").hashValue == FactorioVersion("1.2.3").hashValue,
            "versions that compare as equal must land in the same Set/Dictionary bucket"
        )
    }

    @Test
    func dropsBuildSuffixFromParts() {
        #expect(FactorioVersion("0.17.2-1").parts == [0, 17, 2], "the '-1' build suffix is not a version part")
    }

    @Test
    func keepsRawTextForDisplay() {
        let raw = "2.1.17"
        #expect(FactorioVersion(raw).raw == raw, "shows the version exactly as the mod author wrote it")
    }

    @Test(arguments: [
        ("2.1.17", "2.1", true),
        ("2.1.17", "2.0", false),
        ("2.1.17", "1.1", false),
        ("2.0.32", "2.0", true),
        ("2.0.32", "2.1", false),
        ("2.0.32", "2", true)
    ])
    func matchesMajorMinorBranch(version: String, branch: String, expected: Bool) {
        #expect(
            FactorioVersion(version).isCompatibleMajorMinor(branch) == expected,
            "\(version) on branch \(branch) must give \(expected)"
        )
    }

    @Test
    func separatesGameGenerations() {
        #expect(!FactorioVersion("1.1.110").isCompatibleGeneration("2.0.28"), "1.x mods do not run on Factorio 2.x")
    }

    @Test
    func survivesJsonRoundTripWithRawText() throws {
        let raw = "2.0.28-1"
        let decoded = try JSONDecoder().decode(FactorioVersion.self, from: JSONEncoder().encode(FactorioVersion(raw)))
        #expect(decoded.raw == raw, "encodes the version as its original string")
    }
}
