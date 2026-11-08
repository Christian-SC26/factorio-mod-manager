import Foundation
import Testing
@testable import FactorioModManagerMac

@Suite(.tags(.fast), .timeLimit(.minutes(1)))
struct ModListManagerTests {
    @Test(arguments: [
        ("space-exploration_0.6.120.zip", false, "space-exploration", "0.6.120"),
        ("Krastorio2_1.3.24", true, "Krastorio2", "1.3.24"),
        ("Big_Mod_Pack_10.2.33.zip", false, "Big_Mod_Pack", "10.2.33"),
        ("Squeak Through_1.8.2.ZIP", false, "Squeak Through", "1.8.2")
    ])
    func splitsEntryIntoModNameAndVersion(entry: String, isDirectory: Bool, name: String, version: String) {
        let parsed = ModListManager.parseModNameAndVersion(from: URL(fileURLWithPath: "/моды/\(entry)"), isDirectory: isDirectory)
        #expect(parsed.name == name && parsed.version == version, "'\(entry)' is \(name) \(version)")
    }

    @Test
    func leavesVersionEmptyForUnversionedFolder() {
        let parsed = ModListManager.parseModNameAndVersion(from: URL(fileURLWithPath: "/path/my-custom-mod"), isDirectory: true)
        #expect(parsed.version == nil, "a development folder has no version in its name")
    }

    @Test
    func treatsMissingModListAsBaseOnly() throws {
        #expect(try FkMods().manager().readModListJson() == ["base": true], "a fresh install runs only the base game")
    }

    @Test
    func keepsBaseEnabledEvenWhenAskedToDisableIt() throws {
        let manager = try FkMods().manager()
        try manager.writeModListJson(["base": false, "Squeak Through": true])
        #expect(manager.readModListJson()["base"] == true, "Factorio refuses to start without base")
    }

    @Test
    func enablesInstalledModsMissingFromStates() throws {
        let mods = try FkMods().folder("bob_lib-2", "0.18.5")
        try mods.manager().writeModListJson(["base": true])
        #expect(mods.manager().readModListJson()["bob_lib-2"] == true, "every installed mod gets an explicit state")
    }

    @Test
    func writesBaseAsFirstEntry() throws {
        let manager = try FkMods().manager()
        try manager.writeModListJson(["aaa-first-alphabetically": true, "space-age": false])
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: manager.modListJsonURL)) as? [String: [[String: Any]]]
        #expect(json?["mods"]?.first?["name"] as? String == "base", "base leads mod-list.json like Factorio writes it")
    }

    @Test
    func deletesFilesOfRemovedMods() throws {
        let mods = try FkMods().folder("mod-a", "1.0.0").folder("mod-b", "2.0.0").folder("mod-c", "3.0.0")
        _ = mods.manager().removeMods(["mod-a", "mod-b"], deleteFiles: true)
        #expect(mods.manager().scanInstalledModNames() == ["mod-c"], "only the requested mods disappear")
    }

    @Test
    func countsEveryDeletedVersion() throws {
        let mods = try FkMods().folder("mod-a", "1.0.0").folder("mod-a", "1.1.0").folder("mod-b", "1.0.0")
        #expect(mods.manager().removeMods(["mod-a"], deleteFiles: true) == 2, "both copies of mod-a are removed")
    }

    @Test
    func forgetsStateOfRemovedMods() throws {
        let manager = try FkMods().manager()
        try manager.writeModListJson(["base": true, "mod-a": true, "mod-c": false])
        _ = manager.removeMods(["mod-a"], deleteFiles: false)
        #expect(manager.readModListJson()["mod-a"] == nil, "a removed mod leaves no trace in mod-list.json")
    }

    @Test
    func keepsFilesWhenRemovingOnlyFromList() throws {
        let mods = try FkMods().folder("kept files", "4.0.0")
        _ = mods.manager().removeMods(["kept files"], deleteFiles: false)
        #expect(mods.exists("kept files_4.0.0"), "deleteFiles: false must not touch the disk")
    }

    @Test
    func disablesUnknownModOnToggle() throws {
        #expect(try FkMods().manager().toggleMod("never-seen") == false, "an unlisted mod counts as enabled, so toggling disables it")
    }

    @Test
    func refusesToDisableBase() throws {
        let manager = try FkMods().manager()
        manager.disableMods(["base", "Squeak Through"])
        #expect(manager.readModListJson()["base"] == true, "base can never be turned off")
    }

    @Test
    func listsNewestInstalledVersionFirst() throws {
        let mods = try FkMods().folder("x", "1.9.0").folder("x", "1.10.0").folder("x", "1.2.0")
        #expect(mods.manager().scanInstalledMods()["x"]?.first?.version.raw == "1.10.0", "1.10 is newer than 1.9")
    }

    @Test
    func prefersNameFromInfoJsonOverFolderName() throws {
        let mods = try FkMods().info("renamed-folder", name: "real-name", version: "2.0.0", title: "Real", modified: Date())
        #expect(mods.manager().scanInstalledMods()["real-name"] != nil, "info.json, not the folder name, says which mod this is")
    }

    @Test
    func skipsPartialDownloads() throws {
        let mods = try FkMods()
        try mods.file("half-done_1.0.0.zip.part", Data("PK".utf8))
        #expect(mods.manager().scanInstalledMods().isEmpty, "an unfinished download is not a mod")
    }

    @Test
    func readsMetadataOfEachInstallationSeparately() throws {
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        let first = try FkMods().info("same-mod_1.0.0", name: "same-mod", version: "1.0.0", title: "Первый", modified: stamp)
        let second = try FkMods().info("same-mod_1.0.0", name: "same-mod", version: "1.0.0", title: "Second ✓", modified: stamp)
        _ = first.manager().scanInstalledMods()
        #expect(second.manager().scanInstalledMods()["same-mod"]?.first?.displayTitle == "Second ✓", "a cache must not mix folders")
    }

    @Test
    func detectsFactorioVersionFromGameLog() throws {
        let mods = try FkMods().log("   0.000 2026-11-08 12:00:00; Factorio 2.0.28 (build 80000, mac-arm64, steam)\n")
        #expect(mods.manager().detectInstalledFactorioVersion() == "2.0.28", "the log names the running game version")
    }

    @Test
    func detectsFactorioVersionOfEachInstallationSeparately() throws {
        let first = try FkMods().log("Factorio 1.1.110 (build 12345, mac-arm64)\n")
        let second = try FkMods().log("Factorio 2.0.42 (build 80001, mac-arm64)\n")
        _ = first.manager().detectInstalledFactorioVersion()
        #expect(second.manager().detectInstalledFactorioVersion() == "2.0.42", "switching mods folders must re-detect the game")
    }

    @Test
    func storesKnownVersionInProfile() throws {
        let manager = try FkMods().manager()
        _ = try manager.saveProfile(name: "Speedrun Profile", states: ["base": true, "my-mod": true], knownVersions: ["my-mod": "1.4.2"])
        #expect(manager.listProfiles().first?.mods["my-mod"] == "1.4.2", "the profile pins the version the user had")
    }

    @Test
    func rejectsBlankProfileName() throws {
        let manager = try FkMods().manager()
        #expect(throws: FMMError.emptyProfileName, "a profile needs a name") {
            try manager.saveProfile(name: " \n\t", states: ["base": true], knownVersions: [:])
        }
    }

    @Test
    func keepsProfileWithSlashesInsideProfilesFolder() throws {
        let manager = try FkMods().manager()
        let saved = try manager.saveProfile(name: "../../Rail/World", states: ["base": true], knownVersions: [:])
        #expect(saved.deletingLastPathComponent().standardizedFileURL == manager.profilesDirectory.standardizedFileURL, "no path escape")
    }

    @Test
    func listsProfileUnderItsUnicodeName() throws {
        let name = "Космос & Rails 🚂 \"v2\""
        let manager = try FkMods().manager()
        _ = try manager.saveProfile(name: name, states: ["base": true], knownVersions: [:])
        #expect(manager.listProfiles().map(\.name) == [name], "the profile keeps the name the user typed")
    }

    @Test
    func restoresSavedStatesOnLoad() throws {
        let manager = try FkMods().manager()
        _ = try manager.saveProfile(name: "Test Setup", states: ["base": true, "space-age": true, "unused-mod": false], knownVersions: [:])
        _ = manager.loadProfile(name: "Test Setup")
        #expect(manager.readModListJson()["unused-mod"] == false, "a mod saved as disabled comes back disabled")
    }

    @Test
    func disablesInstalledModsAbsentFromProfile() throws {
        let mods = try FkMods().folder("stray-mod", "1.0.0")
        _ = try mods.manager().saveProfile(name: "Lean", states: ["base": true], knownVersions: [:])
        _ = mods.manager().loadProfile(name: "Lean")
        #expect(mods.manager().readModListJson()["stray-mod"] == false, "a profile is the complete list of enabled mods")
    }

    @Test
    func reportsModsMissingOnDisk() throws {
        let manager = try FkMods().manager()
        _ = try manager.saveProfile(name: "Ghosts", states: ["base": true, "ghost-mod": true], knownVersions: [:])
        #expect(manager.loadProfile(name: "Ghosts").missing == ["ghost-mod"], "the user must learn what to download")
    }

    @Test
    func failsToLoadUnknownProfile() throws {
        #expect(try FkMods().manager().loadProfile(name: "Нет такого").success == false, "nothing to load")
    }

    @Test
    func deletesSavedProfile() throws {
        let manager = try FkMods().manager()
        _ = try manager.saveProfile(name: "To Delete", states: ["base": true], knownVersions: [:])
        _ = manager.deleteProfile(name: "To Delete", filename: nil)
        #expect(manager.listProfiles().isEmpty, "the deleted profile is gone")
    }

    @Test
    func keepsAllProfilesWhenDeletingBlankName() throws {
        let manager = try FkMods().manager()
        _ = try manager.saveProfile(name: "Rail World 🚂", states: ["base": true], knownVersions: [:])
        _ = manager.deleteProfile(name: " \t ", filename: nil)
        #expect(manager.listProfiles().count == 1, "a blank name must not wipe the profiles folder")
    }

    @Test
    func keepsModsWhenDeletingProfileNamedDotDot() throws {
        let mods = try FkMods().folder("precious-mod", "3.1.4")
        _ = mods.manager().deleteProfile(name: "..", filename: nil)
        #expect(mods.exists("precious-mod_3.1.4"), "deleting a profile must never reach outside the profiles folder")
    }

    @Test
    func exportsOnlyEnabledMods() throws {
        let mods = try FkMods()
        try mods.manager().writeModListJson(["base": true, "on-mod": true, "off-mod": false])
        #expect(try mods.manager().exportModpack(to: mods.outside("pack.json"), knownVersions: [:]) == 1, "disabled mods stay out")
    }

    @Test
    func roundTripsModpackThroughJson() throws {
        let mods = try FkMods()
        try mods.manager().writeModListJson(["base": true, "bob_lib-2": true])
        _ = try mods.manager().exportModpack(to: mods.outside("pack.json"), knownVersions: ["bob_lib-2": "0.18.5"])
        #expect(try mods.manager().importModpack(from: mods.outside("pack.json")) == ["https://mods.factorio.com/mod/bob_lib-2"], "import reads export")
    }

    @Test
    func roundTripsModpackThroughText() throws {
        let mods = try FkMods()
        try mods.manager().writeModListJson(["base": true, "Squeak Through": true])
        _ = try mods.manager().exportModpack(to: mods.outside("pack.txt"), knownVersions: [:])
        #expect(try mods.manager().importModpack(from: mods.outside("pack.txt")) == ["https://mods.factorio.com/mod/Squeak Through"], "one link per line")
    }

    @Test
    func skipsCommentsAndBlankLinesInTextModpack() throws {
        let mods = try FkMods()
        try Data("# заголовок\n\n  flib@0.15.0  \r\n\t\n".utf8).write(to: mods.outside("list.txt"))
        #expect(try mods.manager().importModpack(from: mods.outside("list.txt")) == ["flib@0.15.0"], "only real entries count")
    }

    @Test
    func skipsBuiltinsInJsonModpack() throws {
        let mods = try FkMods()
        try Data(#"["base", "space-age", "Krastorio2"]"#.utf8).write(to: mods.outside("list.json"))
        #expect(try mods.manager().importModpack(from: mods.outside("list.json")) == ["Krastorio2"], "built-ins are never downloaded")
    }

    @Test
    func failsToImportMissingFile() throws {
        let mods = try FkMods()
        #expect(throws: FMMError.self, "a missing file is an error") {
            try mods.manager().importModpack(from: mods.outside("nowhere.json"))
        }
    }
}
