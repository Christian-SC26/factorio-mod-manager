import Foundation
import Testing
@testable import FactorioModManagerMac

@Suite(.tags(.fast), .timeLimit(.minutes(1)))
struct AppStateModelsTests {
    @Test(arguments: [nil, ".", "...", "  ", " - "] as [String?])
    func replacesMeaninglessTitleWithFormattedName(title: String?) {
        let item = OptionalModItem(
            name: "bob_lib-2", title: title, owner: "", summary: "", factorioVersions: "", downloadsCount: 0,
            suggestedBy: ["Squeak Through"]
        )
        #expect(item.title == "Bob Lib 2", "'\(title ?? "nil")' cannot be shown as a title")
    }

    @Test
    func keepsMeaningfulTitle() {
        let title = "Космос ✓"
        let item = OptionalModItem(name: "x", title: title, owner: "", summary: "", factorioVersions: "", downloadsCount: 0, suggestedBy: [])
        #expect(item.title == title, "a real title is shown as is")
    }

    @Test
    func dropsLoneDotSummary() {
        let item = OptionalModItem(name: "x", title: nil, owner: "", summary: " .\n", factorioVersions: "", downloadsCount: 0, suggestedBy: [])
        #expect(item.summary.isEmpty, "a single dot is not a description")
    }
}
