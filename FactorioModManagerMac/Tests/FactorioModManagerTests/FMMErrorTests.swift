import Foundation
import Testing
@testable import FactorioModManagerMac

@Suite(.tags(.fast), .timeLimit(.minutes(1)))
struct FMMErrorTests {
    @Test
    func mentionsModNameWhenModIsMissing() {
        let name = "Squeak Through 🦔 100%"
        #expect(
            FMMError.modNotFound(name: name).errorDescription?.contains(name) == true,
            "the user must see which mod was not found"
        )
    }

    @Test
    func omitsEmptyHttpMessage() {
        #expect(FMMError.httpError(statusCode: 503, message: "").errorDescription == "HTTP 503", "no dangling colon")
    }

    @Test
    func mentionsBranchWhenNoReleaseMatches() {
        let branch = "2.0"
        #expect(
            FMMError.noMatchingRelease(modName: "bob_lib-2", branch: branch).errorDescription?.contains(branch) == true,
            "the user must see which Factorio version has no release"
        )
    }

    @Test
    func passesCustomMessageThrough() {
        let message = "Диск переполнен\n\t"
        #expect(FMMError.custom(message).errorDescription == message, "custom messages are shown as is")
    }
}
