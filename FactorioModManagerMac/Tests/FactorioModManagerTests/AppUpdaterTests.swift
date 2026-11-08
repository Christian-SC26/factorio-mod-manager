import Foundation
import Testing
@testable import FactorioModManagerMac

@Suite(.tags(.fast), .timeLimit(.minutes(1)))
struct AppVersionTests {
    @Test
    func comparesComponentsAsNumbers() {
        #expect(AppVersion("v2.10.0")! > AppVersion("2.9.7")!, "2.10 is newer than 2.9, not older")
    }

    @Test
    func treatsMissingPatchAsZero() {
        #expect(AppVersion("2.2")! == AppVersion("v2.2.0")!, "2.2 and v2.2.0 name one release")
    }

    @Test
    func rejectsPrereleaseTag() {
        #expect(AppVersion("v2.3.0-beta") == nil, "a suffixed tag is not offered as an update")
    }

    @Test
    func printsWithoutPrefix() {
        #expect(AppVersion("v3.0.1")!.description == "3.0.1", "the version shows without the tag's v")
    }
}

@Suite(.tags(.fast), .timeLimit(.minutes(1)))
struct AppReleaseTests {
    private static func payload(tag: String, asset: String) -> Data {
        Data("""
        {"tag_name": "\(tag)", "body": "Исправления 🦔", "html_url": "https://github.com/o/r/releases/tag/\(tag)",
         "assets": [{"name": "notes.txt", "browser_download_url": "https://example.com/notes.txt"},
                    {"name": "\(asset)", "browser_download_url": "https://example.com/\(asset)"}]}
        """.utf8)
    }

    @Test
    func picksArchiveAmongAssets() throws {
        let release = try AppRelease.parse(Self.payload(tag: "v9.4.1", asset: "FMM-macOS.zip"), assetName: "FMM-macOS.zip")
        #expect(release.downloadURL.lastPathComponent == "FMM-macOS.zip", "the app archive is downloaded, not another asset")
    }

    @Test
    func refusesReleaseWithoutArchive() {
        #expect(throws: AppUpdateError.noAsset, "a release without the app cannot be installed") {
            try AppRelease.parse(Self.payload(tag: "v9.4.1", asset: "Source.zip"), assetName: "FMM-macOS.zip")
        }
    }

    @Test
    func refusesUnreadableAnswer() {
        #expect(throws: AppUpdateError.badResponse, "an HTML error page is not a release") {
            try AppRelease.parse(Data("<html>rate limit</html>".utf8), assetName: "FMM-macOS.zip")
        }
    }

    @Test
    func blocksInstallOutsideAppBundle() {
        #expect(AppUpdater.installBlocker(for: URL(fileURLWithPath: "/tmp/build/debug")) == "app_update_blocked_dev", "swift run has no bundle to replace")
    }

    @Test
    func blocksInstallFromTranslocatedCopy() {
        let url = URL(fileURLWithPath: "/private/var/folders/x/AppTranslocation/ABC/d/FMM.app")
        #expect(AppUpdater.installBlocker(for: url) == "app_update_blocked_translocated", "a translocated copy is read-only")
    }
}

@Suite(.tags(.deep), .timeLimit(.minutes(1)))
struct AppUpdaterTests {
    private static let identifier = "com.example.fmm-\(UUID().uuidString)"

    @Test
    func readsLatestReleaseFromServer() async throws {
        let body = Data(#"{"tag_name":"v7.0.3","body":null,"html_url":"https://example.com/r","assets":[{"name":"FMM-macOS.zip","browser_download_url":"https://example.com/a.zip"}]}"#.utf8)
        let server = try await FkHttpServer(status: 200, body: body)
        defer { server.close() }
        let release = try await AppUpdater(latestURL: server.url, bundleIdentifier: Self.identifier, requiredTeam: nil).latestRelease()
        #expect(release.version == AppVersion("7.0.3")!, "the newest tag on GitHub is the offered version")
    }

    @Test
    func reportsServerErrorOnCheck() async throws {
        let server = try await FkHttpServer(status: 403, body: Data("rate limited".utf8))
        defer { server.close() }
        await #expect(throws: AppUpdateError.server(403), "a refused request is a failed check") {
            try await AppUpdater(latestURL: server.url, bundleIdentifier: Self.identifier, requiredTeam: nil).latestRelease()
        }
    }

    @Test
    func acceptsSignedBuildOfSameApp() throws {
        let fake = try FkAppBundle(identifier: Self.identifier, signed: true)
        defer { fake.remove() }
        let app = try AppUpdater(bundleIdentifier: Self.identifier, requiredTeam: nil).stage(archive: fake.archive(), into: fake.staging())
        #expect(app.lastPathComponent == "FMM.app", "the verified app is ready to swap in")
    }

    @Test
    func rejectsUnsignedBuild() throws {
        let fake = try FkAppBundle(identifier: Self.identifier, signed: false)
        defer { fake.remove() }
        #expect(throws: AppUpdateError.badSignature, "an unsigned app could have been tampered with") {
            try AppUpdater(bundleIdentifier: Self.identifier, requiredTeam: nil).stage(archive: fake.archive(), into: fake.staging())
        }
    }

    @Test
    func rejectsBuildFromAnotherTeam() throws {
        let fake = try FkAppBundle(identifier: Self.identifier, signed: true)
        defer { fake.remove() }
        #expect(throws: AppUpdateError.wrongTeam, "a notarized copy only accepts builds from its own developer") {
            try AppUpdater(bundleIdentifier: Self.identifier, requiredTeam: "DVJTWMLL8X").stage(archive: fake.archive(), into: fake.staging())
        }
    }

    @Test
    func rejectsDifferentApp() throws {
        let fake = try FkAppBundle(identifier: "com.example.other", signed: true)
        defer { fake.remove() }
        #expect(throws: AppUpdateError.wrongApp, "only FMM may replace FMM") {
            try AppUpdater(bundleIdentifier: Self.identifier, requiredTeam: nil).stage(archive: fake.archive(), into: fake.staging())
        }
    }

    @Test
    func rejectsArchiveWithoutApp() throws {
        let fake = try FkAppBundle(identifier: Self.identifier, signed: false)
        defer { fake.remove() }
        let zip = fake.folder.appendingPathComponent("plain.zip")
        try ZipFixture(entries: [("readme.txt", Data("нет приложения".utf8))], deflate: true).data().write(to: zip)
        #expect(throws: AppUpdateError.notAnApp, "an archive with no app inside cannot be installed") {
            try AppUpdater(bundleIdentifier: Self.identifier, requiredTeam: nil).stage(archive: zip, into: fake.staging())
        }
    }
}
