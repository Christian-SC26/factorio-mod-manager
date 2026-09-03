import XCTest
@testable import FactorioModManagerMac

final class FormattersTests: XCTestCase {
    func testFormatBytes() {
        XCTAssertEqual(Formatters.formatBytes(500), "500 B")
        XCTAssertEqual(Formatters.formatBytes(1024), "1.0 KB")
        XCTAssertEqual(Formatters.formatBytes(1536), "1.5 KB")
        XCTAssertEqual(Formatters.formatBytes(1024 * 1024), "1.0 MB")
        XCTAssertEqual(Formatters.formatBytes(25 * 1024 * 1024), "25.0 MB")
        XCTAssertEqual(Formatters.formatBytes(1024 * 1024 * 1024), "1.00 GB")
    }

    func testFormatDownloads() {
        XCTAssertEqual(Formatters.formatDownloads(42), "42")
        XCTAssertEqual(Formatters.formatDownloads(999), "999")
        XCTAssertEqual(Formatters.formatDownloads(1_500), "1.5k")
        XCTAssertEqual(Formatters.formatDownloads(45_300), "45.3k")
        XCTAssertEqual(Formatters.formatDownloads(1_200_000), "1.2M")
        XCTAssertEqual(Formatters.formatDownloads(25_000_000), "25.0M")
    }

    func testIsValidHumanTitle() {
        XCTAssertFalse(Formatters.isValidHumanTitle("."))
        XCTAssertFalse(Formatters.isValidHumanTitle("..."))
        XCTAssertFalse(Formatters.isValidHumanTitle("   .   "))
        XCTAssertFalse(Formatters.isValidHumanTitle(""))
        XCTAssertFalse(Formatters.isValidHumanTitle(" - "))
        XCTAssertTrue(Formatters.isValidHumanTitle("Maraxsis"))
        XCTAssertTrue(Formatters.isValidHumanTitle("Factorissimo 2"))
        XCTAssertTrue(Formatters.isValidHumanTitle("A."))
    }

    func testFormatModNameAsTitle() {
        XCTAssertEqual(Formatters.formatModNameAsTitle("maraxsis"), "Maraxsis")
        XCTAssertEqual(Formatters.formatModNameAsTitle("factorissimo-2-notnotmelon"), "Factorissimo 2 Notnotmelon")
        XCTAssertEqual(Formatters.formatModNameAsTitle("space_exploration"), "Space Exploration")
    }
}
