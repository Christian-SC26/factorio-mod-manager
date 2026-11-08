import Foundation
import Testing
@testable import FactorioModManagerMac

@Suite(.tags(.fast), .timeLimit(.minutes(1)))
struct ChangelogParserTests {
    @Test
    func splitsChangelogIntoVersions() {
        let text = """
        ---------------------------------------------------------------------------------------------------
        Version: 1.5.0
        Date: 2026-06-25
          Changes:
            - Updated to Factorio 2.1.
        ---------------------------------------------------------------------------------------------------
        Version: 1.4.4
        """
        #expect(ChangelogParser.parse(text).map(\.version) == ["1.5.0", "1.4.4"], "each 'Version:' starts a new entry")
    }

    @Test
    func readsReleaseDate() {
        let text = "Version: 1.4.4\nDate: 2025-09-22\n  Bugfixes:\n    - Fixed a crash."
        #expect(ChangelogParser.parse(text).first?.date == "2025-09-22", "the date belongs to its version")
    }

    @Test
    func keepsChangeLines() {
        let line = "    - Обновлено до Factorio 2.1 🚀"
        #expect(ChangelogParser.parse("Version: 1.5.0\n\(line)").first?.lines == [line], "change lines are kept verbatim")
    }

    @Test
    func returnsNothingForEmptyText() {
        #expect(ChangelogParser.parse("").isEmpty, "an empty changelog has no entries")
    }

    @Test
    func ignoresTextBeforeFirstVersion() {
        #expect(ChangelogParser.parse("Intro line\nVersion: 0.1.0").first?.lines.isEmpty == true, "a preamble is not a change")
    }

    @Test
    func handlesWindowsLineEndings() {
        let text = "Version: 2.0.0\r\nDate: 01.01.2026\r\n  Features:\r\n"
        #expect(ChangelogParser.parse(text).first?.date == "01.01.2026", "CRLF must not leak into fields")
    }

    @Test
    func acceptsLowercaseVersionHeader() {
        #expect(ChangelogParser.parse("version: 3.0.0").map(\.version) == ["3.0.0"], "the header is case-insensitive")
    }
}
