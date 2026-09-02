import XCTest
@testable import FactorioModManagerMac

final class HTMLEntityDecoderTests: XCTestCase {
    func testNamedEntities() {
        let input = "Factorio &amp; Space Age &quot;Expansion&quot; &lt;v2.0&gt; &#39;Special&#39; &nbsp; &copy; 2026"
        let expected = "Factorio & Space Age \"Expansion\" <v2.0> 'Special'   © 2026"
        XCTAssertEqual(HTMLEntityDecoder.unescape(input), expected)
    }

    func testDecimalEntities() {
        let input = "&#60;Hello&#38;World&#62;"
        let expected = "<Hello&World>"
        XCTAssertEqual(HTMLEntityDecoder.unescape(input), expected)
    }

    func testHexEntities() {
        let input = "&#x3C;Mod&#x20;Name&#x3E;"
        let expected = "<Mod Name>"
        XCTAssertEqual(HTMLEntityDecoder.unescape(input), expected)
    }

    func testPlainTextUnchanged() {
        let input = "Plain text without any entities or ampersands"
        XCTAssertEqual(HTMLEntityDecoder.unescape(input), input)
    }

    func testMalformedEntitiesHandledGracefully() {
        let input = "Broken &amp & incomplete &#abc; or &#99999999999; entity"
        let output = HTMLEntityDecoder.unescape(input)
        XCTAssertFalse(output.isEmpty)
    }
}
