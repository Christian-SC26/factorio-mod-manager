import Foundation
import Testing
@testable import FactorioModManagerMac

@Suite(.tags(.fast), .timeLimit(.minutes(1)))
struct HTMLEntityDecoderTests {
    @Test
    func decodesNamedEntities() {
        let text = "Factorio &amp; Space Age &quot;Expansion&quot; &lt;v2.0&gt; &#39;Special&#39; &nbsp; &copy; 2026"
        #expect(
            HTMLEntityDecoder.unescape(text) == "Factorio & Space Age \"Expansion\" <v2.0> 'Special'   © 2026",
            "the common named entities become characters"
        )
    }

    @Test
    func decodesDecimalEntities() {
        #expect(HTMLEntityDecoder.unescape("&#60;Hello&#38;World&#62;") == "<Hello&World>", "decimal code points decode")
    }

    @Test
    func decodesHexEntities() {
        #expect(HTMLEntityDecoder.unescape("&#x3C;Mod&#x20;Name&#X3E;") == "<Mod Name>", "hex code points decode")
    }

    @Test
    func decodesAstralCodePoint() {
        #expect(HTMLEntityDecoder.unescape("Ёж &#x1F994;") == "Ёж 🦔", "code points above U+FFFF decode")
    }

    @Test
    func leavesPlainTextUntouched() {
        let text = "Plain text, Юникод и 😀 без амперсандов"
        #expect(HTMLEntityDecoder.unescape(text) == text, "text without entities is returned as is")
    }

    @Test(arguments: ["Broken &amp & incomplete", "&#abc; or &#99999999999;", "trailing &", "&;", "&#;", "&#x;", "&#xD800;"])
    func keepsMalformedEntitiesVerbatim(text: String) {
        #expect(HTMLEntityDecoder.unescape(text) == text, "'\(text)' is not a valid entity and must survive")
    }

    @Test(arguments: 1...20)
    func decodesEscapedAmpersandOnlyOnce(attempt: Int) {
        #expect(HTMLEntityDecoder.unescape("&amp;lt;b&amp;gt;") == "&lt;b&gt;", "attempt \(attempt): an escaped entity is text, not markup")
    }

    @Test
    func decodesEntityRightAfterLoneAmpersand() {
        #expect(HTMLEntityDecoder.unescape("Q & &#65;") == "Q & A", "a stray '&' must not swallow the next entity")
    }
}
