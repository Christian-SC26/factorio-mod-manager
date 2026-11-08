import Foundation
import Testing
@testable import FactorioModManagerMac

@Suite(.tags(.fast), .timeLimit(.minutes(1)))
struct LocalizationTests {
    @Test(arguments: LocalizationKeys.used())
    func translatesEveryKeyUsedInSources(key: String) {
        #expect(LocalizationManager.shared.localized(key, []) != key, "'\(key)' is used in the UI but has no text")
    }

    @Test
    func substitutesArgumentIntoTranslation() {
        let name = "Zoë 🦔 %d"
        #expect(LocalizationManager.shared.localized("error_mod_not_found", [name]).contains(name), "the mod name appears verbatim")
    }

    @Test
    func fallsBackToKeyForUnknownText() {
        let key = "no_such_key_\(UUID().uuidString)"
        #expect(LocalizationManager.shared.localized(key, []) == key, "a missing text shows its key instead of crashing")
    }
}
