import XCTest
@testable import FactorioModManagerMac

final class ChangelogParserTests: XCTestCase {
    func testParseFactorioChangelog() {
        let text = """
        ---------------------------------------------------------------------------------------------------
        Version: 1.5.0
        Date: 2026-06-25
          Changes:
            - Updated to Factorio 2.1.
        ---------------------------------------------------------------------------------------------------
        Version: 1.4.4
        Date: 2025-09-22
          Bugfixes:
            - Fixed a crash when loading with Space Exploration.
        """

        let entries = ChangelogParser.parse(text)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].version, "1.5.0")
        XCTAssertEqual(entries[0].date, "2026-06-25")
        XCTAssertTrue(entries[0].lines.contains(where: { $0.contains("Updated to Factorio 2.1") }))

        XCTAssertEqual(entries[1].version, "1.4.4")
        XCTAssertEqual(entries[1].date, "2025-09-22")
    }

    func testParseEmptyChangelog() {
        let entries = ChangelogParser.parse("")
        XCTAssertTrue(entries.isEmpty)
    }
}
