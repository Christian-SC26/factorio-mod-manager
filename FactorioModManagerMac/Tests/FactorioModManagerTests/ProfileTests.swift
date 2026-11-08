import Foundation
import Testing
@testable import FactorioModManagerMac

@Suite(.tags(.fast), .timeLimit(.minutes(1)))
struct ProfileTests {
    @Test
    func excludesDisabledModsAfterJsonRoundTrip() throws {
        let profile = Profile(
            name: "Space Age Run", filename: nil, factorioVersion: "2.0.32",
            mods: ["space-age": "2.0.32", "flib": "0.15.0"],
            allStates: ["base": true, "space-age": true, "flib": true, "pycoalprocessing": false],
            createdAt: Date(timeIntervalSince1970: 0), updatedAt: nil
        )
        let decoded = try JSONDecoder().decode(Profile.self, from: JSONEncoder().encode(profile))
        #expect(decoded.extractActiveMods() == ["space-age", "flib"], "disabled mods must stay disabled after saving")
    }

    @Test
    func keepsFactorioVersionAfterJsonRoundTrip() throws {
        let version = "2.0.32"
        let profile = Profile(name: "Ж", filename: "ж.json", factorioVersion: version, mods: [:], allStates: nil, createdAt: nil, updatedAt: nil)
        let decoded = try JSONDecoder().decode(Profile.self, from: JSONEncoder().encode(profile))
        #expect(decoded.factorioVersion == version, "the game version is stored under 'factorio_version'")
    }

    @Test
    func decodesLegacyListOfNamesWithoutBase() throws {
        let json = #"{"name": "Old ✓", "mods": ["base", "Squeak Through", "bob_lib-2"]}"#
        #expect(
            try JSONDecoder().decode(Profile.self, from: Data(json.utf8)).mods == ["Squeak Through": "latest", "bob_lib-2": "latest"],
            "old profiles listed bare names, base included"
        )
    }

    @Test
    func decodesListOfObjectsWithVersions() throws {
        let json = #"{"name": "Pack", "mods": [{"name": "flib", "version": "0.16.1"}, {"name": "base", "version": "2.0"}]}"#
        #expect(
            try JSONDecoder().decode(Profile.self, from: Data(json.utf8)).mods == ["flib": "0.16.1"],
            "modpack-style objects keep their versions"
        )
    }

    @Test
    func dropsModsDisabledInsideObjectList() throws {
        let json = #"{"name": "Mixed", "mods": [{"name": "off", "version": "1.0", "enabled": false}, {"name": "on", "enabled": true}]}"#
        #expect(
            try JSONDecoder().decode(Profile.self, from: Data(json.utf8)).extractActiveMods() == ["on"],
            "a mod marked 'enabled: false' is not active"
        )
    }

    @Test
    func namesProfileWithoutNameUnnamed() throws {
        #expect(try JSONDecoder().decode(Profile.self, from: Data(#"{"mods": {}}"#.utf8)).name == "Unnamed", "a name is always present")
    }

    @Test
    func toleratesUnexpectedModsShape() throws {
        #expect(try JSONDecoder().decode(Profile.self, from: Data(#"{"name": "x", "mods": 42}"#.utf8)).mods.isEmpty, "garbage is not a crash")
    }

    @Test
    func ignoresBaseAmongActiveMods() {
        let profile = Profile(name: "b", filename: nil, factorioVersion: nil, mods: ["base": "2.0", "rails": "1"], allStates: nil, createdAt: nil, updatedAt: nil)
        #expect(profile.extractActiveMods() == ["rails"], "base is always on and never part of a profile")
    }

    @Test
    func doesNotMatchWhenNothingIsActive() {
        let profile = Profile(name: "empty", filename: nil, factorioVersion: nil, mods: [:], allStates: nil, createdAt: nil, updatedAt: nil)
        #expect(!profile.isMatchingActiveMods([]), "an empty profile is never highlighted as active")
    }

    @Test
    func matchesExactSetOfActiveMods() {
        let profile = Profile(name: "p", filename: nil, factorioVersion: nil, mods: ["a b": "1", "c_d": "2"], allStates: nil, createdAt: nil, updatedAt: nil)
        #expect(profile.isMatchingActiveMods(["a b", "c_d"]), "the same set of enabled mods means this profile is active")
    }
}
