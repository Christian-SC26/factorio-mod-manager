import XCTest
@testable import FactorioModManagerMac

final class DependencyTests: XCTestCase {
    func testDependencyParsing() {
        let d1 = Dependency.parse("base >= 2.0.0")
        XCTAssertNotNil(d1)
        XCTAssertEqual(d1?.name, "base")
        XCTAssertEqual(d1?.depType, .required)
        XCTAssertEqual(d1?.op, ">=")
        XCTAssertEqual(d1?.version, FactorioVersion("2.0.0"))

        let d2 = Dependency.parse("! space-age")
        XCTAssertNotNil(d2)
        XCTAssertEqual(d2?.name, "space-age")
        XCTAssertEqual(d2?.depType, .incompatible)

        let d3 = Dependency.parse("+ flib >= 0.14.0")
        XCTAssertNotNil(d3)
        XCTAssertEqual(d3?.name, "flib")
        XCTAssertEqual(d3?.depType, .recommended)

        let d4 = Dependency.parse("? alien-biomes")
        XCTAssertNotNil(d4)
        XCTAssertEqual(d4?.name, "alien-biomes")
        XCTAssertEqual(d4?.depType, .optional)

        let d5 = Dependency.parse("(?) hidden-mod")
        XCTAssertNil(d5, "Hidden optional '(?)' should be skipped")

        let d6 = Dependency.parse("~ load-order-mod")
        XCTAssertNil(d6, "Load order hint '~' should be skipped")
    }

    func testDependencySatisfaction() {
        let dep = Dependency.parse("flib >= 0.14.0")!
        XCTAssertTrue(dep.satisfies(FactorioVersion("0.14.0")))
        XCTAssertTrue(dep.satisfies(FactorioVersion("0.15.2")))
        XCTAssertFalse(dep.satisfies(FactorioVersion("0.13.9")))

        let exactDep = Dependency.parse("mod == 1.2.0")!
        XCTAssertTrue(exactDep.satisfies(FactorioVersion("1.2.0")))
        XCTAssertFalse(exactDep.satisfies(FactorioVersion("1.2.1")))
    }

    func testModInputParsing() {
        let (n1, v1, op1) = ModPortalClient.parseModInput("https://mods.factorio.com/mod/space-exploration")
        XCTAssertEqual(n1, "space-exploration")
        XCTAssertNil(v1)
        XCTAssertNil(op1)

        let (n2, v2, op2) = ModPortalClient.parseModInput("flib@0.15.0")
        XCTAssertEqual(n2, "flib")
        XCTAssertEqual(v2, "0.15.0")
        XCTAssertEqual(op2, "==")

        let (n3, v3, op3) = ModPortalClient.parseModInput("https://re146.dev/factorio/mods#Krastorio2#1.3.24")
        XCTAssertEqual(n3, "Krastorio2")
        XCTAssertEqual(v3, "1.3.24")
        XCTAssertEqual(op3, "==")
    }
}
