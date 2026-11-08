import Foundation
import Testing
@testable import FactorioModManagerMac

@Suite(.tags(.fast), .timeLimit(.minutes(1)))
struct ZipArchiveReaderTests {
    @Test
    func readsInfoJsonFromStoredArchive() throws {
        let json = Data(#"{"name": "Squeak Through", "version": "1.8.2"}"#.utf8)
        let zip = try ZipFixture(entries: [("Squeak Through_1.8.2/info.json", json)], deflate: false).write(to: FkMods().outside("stored.zip"))
        #expect(ZipArchiveReader.readInfoJson(from: zip)?.version == "1.8.2", "uncompressed entries are read as is")
    }

    @Test
    func readsInfoJsonFromDeflatedArchive() throws {
        let title = "Космос ✓ \"Space\" 🚀"
        let json = try JSONEncoder().encode(LocalModInfo(name: "space", version: "0.6.140", title: title))
        let icon = Data((0..<4096).map { _ in UInt8.random(in: 0...255) })
        let zip = try ZipFixture(entries: [("space_0.6.140/thumbnail.png", icon), ("space_0.6.140/info.json", json)], deflate: true).write(to: FkMods().outside("deflated.zip"))
        #expect(ZipArchiveReader.readInfoJson(from: zip)?.title == title, "deflated entries are decompressed")
    }

    @Test
    func picksModInfoJsonOverLookalikeFile() throws {
        let entries = [("mod_1.0.0/locale/extra-info.json", Data("not json at all".utf8)), ("mod_1.0.0/info.json", Data(#"{"name": "mod"}"#.utf8))]
        let zip = try ZipFixture(entries: entries, deflate: false).write(to: FkMods().outside("lookalike.zip"))
        #expect(ZipArchiveReader.readInfoJson(from: zip)?.name == "mod", "'extra-info.json' is not the mod's info.json")
    }

    @Test
    func recognizesArchiveByHeader() throws {
        let zip = try ZipFixture(entries: [("a/info.json", Data("{}".utf8))], deflate: true).write(to: FkMods().outside("valid.zip"))
        #expect(ZipArchiveReader.isValidZipArchive(at: zip), "a real archive is accepted")
    }

    @Test
    func rejectsPlainTextAsArchive() throws {
        let file = try FkMods().file("fake_1.0.0.zip", Data("<html>404 Not Found</html> padding padding".utf8))
        #expect(!ZipArchiveReader.isValidZipArchive(at: file), "an HTML error page is not an archive")
    }

    @Test
    func readsNothingFromPlainText() throws {
        let file = try FkMods().file("text_1.0.0.zip", Data("Not a zip file content, just text".utf8))
        #expect(ZipArchiveReader.readInfoJson(from: file) == nil, "text has no info.json")
    }

    @Test
    func rejectsMissingFileAsArchive() throws {
        #expect(!ZipArchiveReader.isValidZipArchive(at: try FkMods().outside("missing \(UUID()).zip")), "nothing is there")
    }

    @Test
    func readsNothingFromMissingFile() throws {
        #expect(ZipArchiveReader.readInfoJson(from: try FkMods().outside("missing \(UUID()).zip")) == nil, "nothing is there")
    }

    @Test
    func readsNothingFromTruncatedArchive() throws {
        let full = ZipFixture(entries: [("m_1.0.0/info.json", Data(#"{"name": "m"}"#.utf8))], deflate: true).data()
        let file = try FkMods().file("cut_1.0.0.zip", full.prefix(full.count - 9))
        #expect(ZipArchiveReader.readInfoJson(from: file) == nil, "an interrupted download has no readable metadata")
    }

    @Test
    func survivesRandomGarbageInsideArchiveStructure() throws {
        let mods = try FkMods()
        let parsed = try (0..<300).compactMap { _ in
            ZipArchiveReader.readInfoJson(from: try mods.file("garbage.zip", ZipGarbage(length: Int.random(in: 128...2048)).data()))
        }
        #expect(parsed.isEmpty, "random bytes never decode as metadata; a crash leaves garbage.zip behind for analysis")
    }
}
