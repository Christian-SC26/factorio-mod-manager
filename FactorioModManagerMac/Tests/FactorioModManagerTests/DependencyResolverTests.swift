import XCTest
@testable import FactorioModManagerMac

private actor MockPortalClient: ModPortalClientProtocol {
    var mods: [String: ModInfo] = [:]

    init(mods: [String: ModInfo] = [:]) {
        self.mods = mods
    }

    func fetchModInfo(_ modName: String) async throws -> ModInfo {
        if let m = mods[modName] {
            return m
        }
        throw FMMError.modNotFound(name: modName)
    }

    func searchPortalMods(query: String, onlyV2: Bool, maxPages: Int) async throws -> [SearchModItem] {
        return []
    }

    func fetchAuthorMods(authorOrUrl: String) async throws -> (author: String, mods: [AuthorModItem]) {
        return ("", [])
    }

    func fetchPortalModpacks(targetFactorioBranch: String?) async throws -> [PortalModpackItem] {
        return []
    }
}

final class DependencyResolverTests: XCTestCase {
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

    func testTransitiveDependencyResolution() async {
        // modA requires modB >= 1.0.0
        // modB requires modC
        let releaseC = ReleaseInfo(version: FactorioVersion("1.0.0"), dependencies: [], downloadUrl: "https://example.com/c.zip")
        let modC = ModInfo(name: "modC", title: "Mod C", releases: [releaseC])

        let depB_to_C = Dependency.parse("modC")!
        let releaseB = ReleaseInfo(version: FactorioVersion("1.0.0"), dependencies: [depB_to_C], downloadUrl: "https://example.com/b.zip")
        let modB = ModInfo(name: "modB", title: "Mod B", releases: [releaseB])

        let depA_to_B = Dependency.parse("modB >= 1.0.0")!
        let releaseA = ReleaseInfo(version: FactorioVersion("1.0.0"), dependencies: [depA_to_B], downloadUrl: "https://example.com/a.zip")
        let modA = ModInfo(name: "modA", title: "Mod A", releases: [releaseA])

        let mockClient = MockPortalClient(mods: ["modA": modA, "modB": modB, "modC": modC])
        let resolver = DependencyResolver(client: mockClient, modListMgr: mgr)

        let result = await resolver.resolve(targets: ["modA"])

        XCTAssertEqual(result.modsToDownload.count, 3)
        let downloadedNames = Set(result.modsToDownload.map { $0.name })
        XCTAssertTrue(downloadedNames.contains("modA"))
        XCTAssertTrue(downloadedNames.contains("modB"))
        XCTAssertTrue(downloadedNames.contains("modC"))
        XCTAssertTrue(result.conflicts.isEmpty)
    }

    func testConflictDetection() async {
        // modA conflicts with modB (! modB)
        let conflictDep = Dependency.parse("! modB")!
        let releaseA = ReleaseInfo(version: FactorioVersion("1.0.0"), dependencies: [conflictDep], downloadUrl: "https://example.com/a.zip")
        let modA = ModInfo(name: "modA", title: "Mod A", releases: [releaseA])

        let releaseB = ReleaseInfo(version: FactorioVersion("1.0.0"), dependencies: [], downloadUrl: "https://example.com/b.zip")
        let modB = ModInfo(name: "modB", title: "Mod B", releases: [releaseB])

        let mockClient = MockPortalClient(mods: ["modA": modA, "modB": modB])
        let resolver = DependencyResolver(client: mockClient, modListMgr: mgr)

        let result = await resolver.resolve(targets: ["modA", "modB"])

        XCTAssertFalse(result.conflicts.isEmpty)
        XCTAssertEqual(result.conflicts.first?.modA, "modA")
        XCTAssertEqual(result.conflicts.first?.modB, "modB")
    }
}
