import XCTest
@testable import FactorioModManagerMac

final class FactorioVersionTests: XCTestCase {
    func testVersionParsing() {
        let v1 = FactorioVersion("2.1.17")
        XCTAssertEqual(v1.parts, [2, 1, 17])
        XCTAssertEqual(v1.raw, "2.1.17")

        let v2 = FactorioVersion("1.1")
        XCTAssertEqual(v2.parts, [1, 1])

        let v3 = FactorioVersion("0.17.2-1")
        XCTAssertEqual(v3.parts, [0, 17, 2])
    }

    func testVersionComparison() {
        XCTAssertTrue(FactorioVersion("2.1.0") > FactorioVersion("2.0.28"))
        XCTAssertTrue(FactorioVersion("2.0.0") > FactorioVersion("1.1.80"))
        XCTAssertTrue(FactorioVersion("1.1.80") == FactorioVersion("1.1.80"))
        XCTAssertTrue(FactorioVersion("2.0") == FactorioVersion("2.0.0"))
        XCTAssertTrue(FactorioVersion("2.0.1") >= FactorioVersion("2.0"))
        XCTAssertTrue(FactorioVersion("1.1.5") < FactorioVersion("1.1.10"))
    }

    func testMajorMinorCompatibility() {
        let v = FactorioVersion("2.1.17")
        XCTAssertTrue(v.isCompatibleMajorMinor("2.1"))
        XCTAssertFalse(v.isCompatibleMajorMinor("2.0"))
        XCTAssertFalse(v.isCompatibleMajorMinor("1.1"))

        let v2 = FactorioVersion("2.0.32")
        XCTAssertTrue(v2.isCompatibleMajorMinor("2.0"))
        XCTAssertFalse(v2.isCompatibleMajorMinor("2.1"))
    }
}
