import XCTest
@testable import FactorioModManagerMac

final class MarkdownSanitizerTests: XCTestCase {
    func testHeadingMissingSpaceFixed() {
        let input = """
        #All The Resource Mods (atrm)
        Some description text.
        ##Main compatibility targets
        - Item 1
        ###Sub-heading
        """

        let output = MarkdownSanitizer.sanitize(input)
        XCTAssertTrue(output.contains("# All The Resource Mods (atrm)"))
        XCTAssertTrue(output.contains("## Main compatibility targets"))
        XCTAssertTrue(output.contains("### Sub-heading"))
    }
}
