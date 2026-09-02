import XCTest
@testable import FactorioModManagerMac

final class FactorioConstantsTests: XCTestCase {
    func testOfficialModsIdentification() {
        XCTAssertTrue(FactorioConstants.isOfficialMod("base"))
        XCTAssertTrue(FactorioConstants.isOfficialMod("Base"))
        XCTAssertTrue(FactorioConstants.isOfficialMod("space-age"))
        XCTAssertTrue(FactorioConstants.isOfficialMod("quality"))
        XCTAssertTrue(FactorioConstants.isOfficialMod("elevated-rails"))
        XCTAssertTrue(FactorioConstants.isOfficialMod("recycler"))

        XCTAssertFalse(FactorioConstants.isOfficialMod("Krastorio2"))
        XCTAssertFalse(FactorioConstants.isOfficialMod("space-exploration"))
        XCTAssertFalse(FactorioConstants.isOfficialMod("flib"))
    }

    func testVirtualBuiltins() {
        XCTAssertTrue(FactorioConstants.isVirtualBuiltin("base"))
        XCTAssertTrue(FactorioConstants.isVirtualBuiltin("core"))
        XCTAssertTrue(FactorioConstants.isVirtualBuiltin("space-age"))

        XCTAssertFalse(FactorioConstants.isVirtualBuiltin("alien-biomes"))
    }

    func testOfficialExpansionsCount() {
        XCTAssertEqual(FactorioConstants.officialExpansions.count, 4)
        let names = FactorioConstants.officialExpansions.map(\.name)
        XCTAssertTrue(names.contains("space-age"))
        XCTAssertTrue(names.contains("quality"))
        XCTAssertTrue(names.contains("elevated-rails"))
        XCTAssertTrue(names.contains("recycler"))
    }
}
