import Foundation
import Testing
@testable import FactorioModManagerMac

@Suite(.tags(.fast), .timeLimit(.minutes(1)))
struct MarkdownSanitizerTests {
    @Test(arguments: [
        ("#All The Resource Mods (atrm)", "# All The Resource Mods (atrm)"),
        ("##Main compatibility targets", "## Main compatibility targets"),
        ("Intro\n###Sub-heading", "Intro\n### Sub-heading")
    ])
    func insertsSpaceAfterHeadingHashes(text: String, markdown: String) {
        #expect(MarkdownSanitizer.sanitize(text) == markdown, "'#Title' must render as a heading")
    }

    @Test
    func convertsUppercaseLineBreakTag() {
        #expect(MarkdownSanitizer.sanitize("one<BR>two") == "one\n\ntwo", "HTML tags are case-insensitive")
    }

    @Test
    func turnsBoldTagsIntoMarkdown() {
        #expect(MarkdownSanitizer.sanitize("<b>Space</b> Age") == "**Space** Age", "<b> becomes **")
    }

    @Test
    func decodesEntitiesBeforeConverting() {
        #expect(MarkdownSanitizer.sanitize("Q&amp;A <em>сейчас</em>") == "Q&A *сейчас*", "entities and tags both convert")
    }

    @Test
    func squeezesLongRunsOfBlankLines() {
        #expect(MarkdownSanitizer.sanitize("a\n\n\n\n\n\nb") == "a\n\n\nb", "at most two blank lines remain")
    }

    @Test
    func returnsEmptyTextForEmptyInput() {
        #expect(MarkdownSanitizer.sanitize("").isEmpty, "nothing in, nothing out")
    }
}
