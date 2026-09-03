import XCTest
@testable import FactorioModManagerMac

final class ModListManagerTests: XCTestCase {
    var tempDirectory: URL!
    var manager: ModListManager!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("FMM_Test_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        manager = ModListManager(modsDirectory: tempDirectory)
    }

    override func tearDown() {
        if let temp = tempDirectory {
            try? FileManager.default.removeItem(at: temp)
        }
        super.tearDown()
    }

    func testParseModNameAndVersion() {
        // Zip file with version
        let zipURL = URL(fileURLWithPath: "/path/to/space-exploration_0.6.120.zip")
        let zipParsed = ModListManager.parseModNameAndVersion(from: zipURL, isDirectory: false)
        XCTAssertEqual(zipParsed.name, "space-exploration")
        XCTAssertEqual(zipParsed.version, "0.6.120")

        // Directory with version
        let dirURL = URL(fileURLWithPath: "/path/to/Krastorio2_1.3.24")
        let dirParsed = ModListManager.parseModNameAndVersion(from: dirURL, isDirectory: true)
        XCTAssertEqual(dirParsed.name, "Krastorio2")
        XCTAssertEqual(dirParsed.version, "1.3.24")

        // Directory without version
        let unversionedDir = URL(fileURLWithPath: "/path/to/my-custom-mod")
        let unversionedParsed = ModListManager.parseModNameAndVersion(from: unversionedDir, isDirectory: true)
        XCTAssertEqual(unversionedParsed.name, "my-custom-mod")
        XCTAssertNil(unversionedParsed.version)
    }

    func testBatchRemoveMods() throws {
        // Setup initial mod-list.json
        let initialStates: [String: Bool] = [
            "base": true,
            "mod-a": true,
            "mod-b": false,
            "mod-c": true
        ]
        try manager.writeModListJson(initialStates)

        // Create dummy mod files
        let modAFile = tempDirectory.appendingPathComponent("mod-a_1.0.0.zip")
        let modBFile = tempDirectory.appendingPathComponent("mod-b_2.0.0.zip")
        let modCFile = tempDirectory.appendingPathComponent("mod-c_3.0.0.zip")
        try "dummy A".write(to: modAFile, atomically: true, encoding: .utf8)
        try "dummy B".write(to: modBFile, atomically: true, encoding: .utf8)
        try "dummy C".write(to: modCFile, atomically: true, encoding: .utf8)

        // Batch remove mod-a and mod-b
        let removed = manager.removeMods(["mod-a", "mod-b"], deleteFiles: true)
        XCTAssertEqual(removed, 2)

        // Verify files are deleted
        XCTAssertFalse(FileManager.default.fileExists(atPath: modAFile.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: modBFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: modCFile.path))

        // Verify mod-list.json states updated
        let updatedStates = manager.readModListJson()
        XCTAssertNil(updatedStates["mod-a"])
        XCTAssertNil(updatedStates["mod-b"])
        XCTAssertEqual(updatedStates["mod-c"], true)
        XCTAssertEqual(updatedStates["base"], true)
    }

    func testSaveProfileWithKnownVersions() throws {
        let states: [String: Bool] = [
            "base": true,
            "my-mod": true
        ]
        try manager.writeModListJson(states)

        let profileURL = try manager.saveProfile(
            name: "Speedrun Profile",
            states: states,
            knownVersions: ["my-mod": "1.4.2"]
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: profileURL.path))

        let profiles = manager.listProfiles()
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles.first?.name, "Speedrun Profile")
        XCTAssertEqual(profiles.first?.mods["my-mod"], "1.4.2")
    }
}
