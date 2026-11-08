import Foundation
import Testing
@testable import FactorioModManagerMac

@Suite(.tags(.fast), .timeLimit(.minutes(1)))
struct LocalModTests {
    @Test(arguments: ["__mod-name__", "Mod Display Name", "[mod-name]", "  \n ", "locale.missing"])
    func replacesPlaceholderTitleWithReadableName(title: String) {
        let mod = LocalMod(
            name: "rail-signals_plus", version: FactorioVersion("1.0.0"), fileURL: URL(fileURLWithPath: "/m"),
            isDirectory: true, enabled: true, fileSize: 0, modificationDate: nil,
            info: LocalModInfo(name: "rail-signals_plus", title: title)
        )
        #expect(mod.displayTitle == "Rail Signals Plus", "'\(title)' is not a human title")
    }

    @Test
    func keepsRealTitle() {
        let title = "Космическая эра — Rails 🚂"
        let mod = LocalMod(
            name: "rails", version: FactorioVersion("1.0.0"), fileURL: URL(fileURLWithPath: "/m"),
            isDirectory: true, enabled: true, fileSize: 0, modificationDate: nil, info: LocalModInfo(title: title)
        )
        #expect(mod.displayTitle == title, "a real title is shown untouched")
    }

    @Test
    func stripsYearAndNotesFromAuthor() {
        let mod = LocalMod(
            name: "x", version: FactorioVersion("1.0.0"), fileURL: URL(fileURLWithPath: "/m"), isDirectory: true,
            enabled: true, fileSize: 0, modificationDate: nil, info: LocalModInfo(author: "Klonan, 2023 (Wube)")
        )
        #expect(mod.cleanAuthorName == "Klonan", "copyright years and notes are not part of the name")
    }

    @Test
    func takesFirstOfSeveralAuthors() {
        let mod = LocalMod(
            name: "x", version: FactorioVersion("1.0.0"), fileURL: URL(fileURLWithPath: "/m"), isDirectory: true,
            enabled: true, fileSize: 0, modificationDate: nil, info: LocalModInfo(author: " Earendel , notnotmelon, Zoë")
        )
        #expect(mod.primaryAuthor == "Earendel", "the first listed author owns the portal page")
    }

    @Test
    func marksMissingAuthorWithDash() {
        let mod = LocalMod(
            name: "x", version: FactorioVersion("1.0.0"), fileURL: URL(fileURLWithPath: "/m"), isDirectory: true,
            enabled: true, fileSize: 0, modificationDate: nil, info: LocalModInfo(author: " \t ")
        )
        #expect(mod.author == "—", "a blank author is shown as a dash")
    }

    @Test
    func givesNoPortalLinkWithoutAuthor() {
        let mod = LocalMod(
            name: "x", version: FactorioVersion("1.0.0"), fileURL: URL(fileURLWithPath: "/m"), isDirectory: true,
            enabled: true, fileSize: 0, modificationDate: nil, info: nil
        )
        #expect(mod.portalAuthorURL(portalOwner: nil) == nil, "there is no page for an unknown author")
    }

    @Test
    func buildsPortalLinkForUnicodeAuthor() {
        let mod = LocalMod(
            name: "x", version: FactorioVersion("1.0.0"), fileURL: URL(fileURLWithPath: "/m"), isDirectory: true,
            enabled: true, fileSize: 0, modificationDate: nil, info: LocalModInfo(author: "Zoë O'Brien 李")
        )
        #expect(mod.portalAuthorURL(portalOwner: nil) != nil, "non-ASCII author names must still produce a link")
    }

    @Test
    func keepsSlashedAuthorInsideOneLinkSegment() {
        let mod = LocalMod(
            name: "x", version: FactorioVersion("1.0.0"), fileURL: URL(fileURLWithPath: "/m"), isDirectory: true,
            enabled: true, fileSize: 0, modificationDate: nil, info: LocalModInfo(author: "Bob/Alice")
        )
        #expect(mod.portalAuthorURL(portalOwner: nil)?.pathComponents.count == 3, "a slash must not add a path level")
    }

    @Test
    func prefersPortalOwnerOverAuthor() {
        let owner = "real_owner-42"
        let mod = LocalMod(
            name: "x", version: FactorioVersion("1.0.0"), fileURL: URL(fileURLWithPath: "/m"), isDirectory: true,
            enabled: true, fileSize: 0, modificationDate: nil, info: LocalModInfo(author: "Someone Else")
        )
        #expect(mod.portalAuthorURL(portalOwner: owner)?.lastPathComponent == owner, "the portal knows the real owner")
    }

    @Test
    func skipsHiddenDependencies() {
        let mod = LocalMod(
            name: "x", version: FactorioVersion("1.0.0"), fileURL: URL(fileURLWithPath: "/m"), isDirectory: true,
            enabled: true, fileSize: 0, modificationDate: nil,
            info: LocalModInfo(dependencies: ["base >= 2.0", "(?) hidden", "~ order", "? opt"])
        )
        #expect(mod.getDependencies().map(\.name) == ["base", "opt"], "'(?)' and '~' are hints, not dependencies")
    }

    @Test
    func readsInfoJsonFromModFolder() throws {
        let title = "Тест ✓ \"quoted\""
        let mods = try FkMods().info("Squeak Through_1.8.2", name: "Squeak Through", version: "1.8.2", title: title, modified: Date())
        let folder = mods.dir.appendingPathComponent("Squeak Through_1.8.2", isDirectory: true)
        #expect(LocalMod.loadInfoJson(from: folder, isDirectory: true)?.title == title, "reads metadata of an unpacked mod")
    }

    @Test
    func ignoresFileThatIsNeitherFolderNorZip() throws {
        let file = try FkMods().file("readme_1.0.0.txt", Data(#"{"name":"readme"}"#.utf8))
        #expect(LocalMod.loadInfoJson(from: file, isDirectory: false) == nil, "only folders and zips are mods")
    }
}
