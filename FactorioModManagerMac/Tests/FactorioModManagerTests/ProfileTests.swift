import XCTest
@testable import FactorioModManagerMac

final class ProfileTests: XCTestCase {
    var tempDir: URL!
    var mgr: ModListManager!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        mgr = ModListManager(modsDirectory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testProfileEncodingAndDecoding() throws {
        let profile = Profile(
            name: "Space Age Run",
            factorioVersion: "2.0.32",
            mods: ["space-age": "2.0.32", "flib": "0.15.0"],
            allStates: ["base": true, "space-age": true, "flib": true, "pycoalprocessing": false]
        )

        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(Profile.self, from: data)

        XCTAssertEqual(decoded.name, "Space Age Run")
        XCTAssertEqual(decoded.factorioVersion, "2.0.32")
        XCTAssertEqual(decoded.mods["space-age"], "2.0.32")
        XCTAssertEqual(decoded.allStates?["pycoalprocessing"], false)
        XCTAssertTrue(decoded.extractActiveMods().contains("space-age"))
        XCTAssertFalse(decoded.extractActiveMods().contains("pycoalprocessing"))
    }

    func testSaveAndLoadProfile() throws {
        let initialStates: [String: Bool] = [
            "base": true,
            "space-age": true,
            "quality": true,
            "unused-mod": false
        ]

        let url = try mgr.saveProfile(name: "Test Setup", states: initialStates)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        let profiles = mgr.listProfiles()
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles.first?.name, "Test Setup")

        let (success, activated, missing) = mgr.loadProfile(name: "Test Setup")
        XCTAssertTrue(success)
        XCTAssertTrue(activated.contains("space-age") || missing.contains("space-age"))

        let diskStates = mgr.readModListJson()
        XCTAssertEqual(diskStates["base"], true)
        XCTAssertEqual(diskStates["space-age"], true)
        XCTAssertEqual(diskStates["unused-mod"], false)
    }

    func testDeleteProfile() throws {
        _ = try mgr.saveProfile(name: "To Delete", states: ["base": true])
        XCTAssertEqual(mgr.listProfiles().count, 1)

        let deleted = mgr.deleteProfile(name: "To Delete")
        XCTAssertTrue(deleted)
        XCTAssertEqual(mgr.listProfiles().count, 0)
    }
}
