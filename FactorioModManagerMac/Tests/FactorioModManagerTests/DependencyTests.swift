import Foundation
import Testing
@testable import FactorioModManagerMac

@Suite(.tags(.fast), .timeLimit(.minutes(1)))
struct DependencyTests {
    @Test(arguments: [
        ("base >= 2.0.0", DependencyType.required),
        ("! space-age", .incompatible),
        ("+ flib >= 0.14.0", .recommended),
        ("? alien-biomes", .optional),
        ("?Squeak Through", .optional)
    ])
    func recognizesDependencyKind(line: String, kind: DependencyType) {
        #expect(Dependency.parse(line)?.depType == kind, "'\(line)' must be parsed as \(kind)")
    }

    @Test(arguments: ["(?) hidden-mod", "~ load-order-mod", "", "   \t  "])
    func skipsHintsThatAreNotDependencies(line: String) {
        #expect(Dependency.parse(line) == nil, "'\(line)' does not require anything")
    }

    @Test(arguments: [
        ("base >= 2.0.0", "base"),
        ("! space-age", "space-age"),
        ("+ flib >= 0.14.0", "flib"),
        ("Squeak Through >= 1.8.2", "Squeak Through"),
        ("  bob_lib-2  ", "bob_lib-2")
    ])
    func extractsModName(line: String, name: String) {
        #expect(Dependency.parse(line)?.name == name, "'\(line)' names the mod '\(name)'")
    }

    @Test
    func readsVersionFromConstraint() {
        #expect(Dependency.parse("base >= 2.0.0")?.version == FactorioVersion("2.0.0"), "keeps the required version")
    }

    @Test
    func normalizesSingleEqualsOperator() {
        #expect(Dependency.parse("rail-signals = 1.0.3")?.op == "==", "'=' and '==' mean the same constraint")
    }

    @Test(arguments: [
        ("flib >= 0.14.0", "0.14.0", true),
        ("flib >= 0.14.0", "0.15.2", true),
        ("flib >= 0.14.0", "0.13.9", false),
        ("mod == 1.2.0", "1.2.0", true),
        ("mod == 1.2.0", "1.2.1", false),
        ("old < 1.0", "0.99.99", true),
        ("old < 1.0", "1.0.0", false),
        ("new > 2.0", "2.0.0", false),
        ("cap <= 1.1", "1.1.0", true)
    ])
    func checksVersionConstraint(line: String, candidate: String, expected: Bool) {
        #expect(
            Dependency.parse(line)?.satisfies(FactorioVersion(candidate)) == expected,
            "\(candidate) against '\(line)' must give \(expected)"
        )
    }

    @Test
    func acceptsAnyVersionWithoutConstraint() {
        #expect(Dependency.parse("Krastorio2")?.satisfies(FactorioVersion("0.0.1")) == true, "no constraint means any release")
    }

    @Test
    func treatsBuiltinNameAsVirtualIgnoringCase() {
        #expect(Dependency.parse("Space-Age")?.isVirtual == true, "built-in expansions ship with the game")
    }
}
