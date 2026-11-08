import Foundation
import Testing
@testable import FactorioModManagerMac

@Suite(.tags(.fast), .timeLimit(.minutes(1)))
struct ModPortalClientTests {
    @Test(arguments: [
        ("https://mods.factorio.com/mod/space-exploration", "space-exploration"),
        ("https://mods.factorio.com/mod/Krastorio2?from=search", "Krastorio2"),
        ("https://mods.factorio.com/mods/earendel/space-exploration", "space-exploration"),
        ("  flib@0.15.0\n", "flib"),
        ("https://re146.dev/factorio/mods#Krastorio2#1.3.24", "Krastorio2"),
        ("https://re146.dev/factorio/mods#https://mods.factorio.com/mod/flib", "flib"),
        ("bob_lib-2", "bob_lib-2")
    ])
    func extractsModName(input: String, name: String) {
        #expect(ModPortalClient.parseModInput(input).name == name, "'\(input)' refers to '\(name)'")
    }

    @Test
    func decodesPercentEncodedNameInPortalLink() {
        #expect(
            ModPortalClient.parseModInput("https://mods.factorio.com/mod/Squeak%20Through").name == "Squeak Through",
            "a link copied from the browser must give the real mod name"
        )
    }

    @Test(arguments: [
        ("flib@0.15.0", "=="),
        ("flib=0.15.0", "=="),
        ("flib >= 0.15", ">="),
        ("flib<=1.0", "<="),
        ("flib<1.0", "<"),
        ("https://re146.dev/factorio/mods#Krastorio2#1.3.24", "==")
    ])
    func normalizesVersionOperator(input: String, op: String) {
        #expect(ModPortalClient.parseModInput(input).op == op, "'\(input)' must use '\(op)'")
    }

    @Test
    func readsVersionFromDownloadLink() {
        #expect(
            ModPortalClient.parseModInput("https://mods.factorio.com/mod/flib/downloads#0.16.1").version == "0.16.1",
            "a download link pins the version"
        )
    }

    @Test
    func leavesVersionEmptyForBareName() {
        #expect(ModPortalClient.parseModInput("Krastorio2").version == nil, "a bare name means the newest release")
    }

    @Test
    func returnsEmptyNameForBlankInput() {
        #expect(ModPortalClient.parseModInput(" \t\n").name.isEmpty, "blank input names nothing")
    }
}
