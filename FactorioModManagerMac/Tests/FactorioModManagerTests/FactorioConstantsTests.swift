import Foundation
import Testing
@testable import FactorioModManagerMac

@Suite(.tags(.fast), .timeLimit(.minutes(1)))
struct FactorioConstantsTests {
    @Test(arguments: ["base", "Base", "space-age", "QUALITY", "elevated-rails", "recycler"])
    func recognizesOfficialMod(name: String) {
        #expect(FactorioConstants.isOfficialMod(name), "'\(name)' is shipped by Wube")
    }

    @Test(arguments: ["Krastorio2", "space-exploration", "flib", "base-extended", ""])
    func rejectsCommunityMod(name: String) {
        #expect(!FactorioConstants.isOfficialMod(name), "'\(name)' is not an official mod")
    }

    @Test(arguments: ["base", "core", "space-age", "Recycler"])
    func recognizesVirtualBuiltin(name: String) {
        #expect(FactorioConstants.isVirtualBuiltin(name), "'\(name)' is never downloaded from the portal")
    }

    @Test
    func rejectsCommunityModAsBuiltin() {
        #expect(!FactorioConstants.isVirtualBuiltin("alien-biomes"), "community mods must be downloaded")
    }

    @Test
    func listsEveryExpansionAsOfficial() {
        #expect(
            Set(FactorioConstants.officialExpansions.map(\.name)) == ["space-age", "quality", "elevated-rails", "recycler"],
            "the UI shows exactly the four Space Age expansions"
        )
    }
}
