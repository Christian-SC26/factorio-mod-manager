import Foundation
import Testing
@testable import FactorioModManagerMac

@Suite(.tags(.deep), .timeLimit(.minutes(1)))
struct ModDownloaderTests {
    @Test
    func reportsBrokenDownloadLink() async throws {
        let downloader = ModDownloader(modListMgr: try FkMods().manager(), cleanOld: true, autoEnable: true)
        let progress = await downloader.downloadSingle(mod: FkPortal.resolved("bob_lib-2", "1.0.0", url: ""), onProgress: { _ in })
        #expect(progress.error != nil, "an empty link cannot be downloaded")
    }

    @Test
    func storesDownloadedArchiveInModsFolder() async throws {
        let mods = try FkMods()
        let server = try await FkHttpServer(status: 200, body: ZipFixture(entries: [("Squeak Through_1.8.2/info.json", Data("{}".utf8))], deflate: true).data())
        defer { server.close() }
        let downloader = ModDownloader(modListMgr: mods.manager(), cleanOld: true, autoEnable: false)
        _ = await downloader.downloadSingle(mod: FkPortal.resolved("Squeak Through", "1.8.2", url: server.url.absoluteString), onProgress: { _ in })
        #expect(mods.exists("Squeak Through_1.8.2.zip"), "the archive lands in the mods folder under its release name")
    }

    @Test
    func removesOlderVersionAfterDownload() async throws {
        let mods = try FkMods()
        try mods.file("Squeak Through_1.7.0.zip", ZipFixture(entries: [("old/info.json", Data("{}".utf8))], deflate: false).data())
        let server = try await FkHttpServer(status: 200, body: ZipFixture(entries: [("new/info.json", Data("{}".utf8))], deflate: true).data())
        defer { server.close() }
        _ = await ModDownloader(modListMgr: mods.manager(), cleanOld: true, autoEnable: false).downloadSingle(mod: FkPortal.resolved("Squeak Through", "1.8.2", url: server.url.absoluteString), onProgress: { _ in })
        #expect(!mods.exists("Squeak Through_1.7.0.zip"), "Factorio refuses to load two versions of one mod")
    }

    @Test
    func enablesDownloadedModsInModList() async throws {
        let mods = try FkMods()
        try mods.manager().writeModListJson(["base": true, "flib": false])
        let server = try await FkHttpServer(status: 200, body: ZipFixture(entries: [("flib/info.json", Data("{}".utf8))], deflate: false).data())
        defer { server.close() }
        _ = await ModDownloader(modListMgr: mods.manager(), cleanOld: true, autoEnable: true).downloadAll(mods: [FkPortal.resolved("flib", "0.16.1", url: server.url.absoluteString)], onProgress: { _ in })
        #expect(mods.manager().readModListJson()["flib"] == true, "a freshly installed mod is switched on")
    }

    @Test
    func rejectsPayloadThatIsNotArchive() async throws {
        let mods = try FkMods()
        let server = try await FkHttpServer(status: 200, body: Data("<html><body>Лимит запросов исчерпан</body></html>".utf8))
        defer { server.close() }
        let progress = await ModDownloader(modListMgr: mods.manager(), cleanOld: true, autoEnable: false).downloadSingle(mod: FkPortal.resolved("flib", "0.16.1", url: server.url.absoluteString), onProgress: { _ in })
        #expect(progress.error != nil, "an HTML page must never be saved as a mod")
    }

    @Test
    func reportsServerError() async throws {
        let mods = try FkMods()
        let server = try await FkHttpServer(status: 404, body: Data("missing".utf8))
        defer { server.close() }
        let progress = await ModDownloader(modListMgr: mods.manager(), cleanOld: true, autoEnable: false).downloadSingle(mod: FkPortal.resolved("flib", "0.16.1", url: server.url.absoluteString), onProgress: { _ in })
        #expect(progress.error != nil, "a 404 is a failed download")
    }
}
