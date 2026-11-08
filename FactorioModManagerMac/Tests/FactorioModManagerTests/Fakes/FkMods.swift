import Foundation
@testable import FactorioModManagerMac

/// A real Factorio data folder on disk, created fresh for every test inside `.build/angry-tmp`.
/// The path deliberately contains spaces, Cyrillic and an emoji, and stays on disk after the run
/// so that a failed test can be inspected.
struct FkMods {
    let dir: URL

    init(file: String = #filePath) throws {
        let package = URL(fileURLWithPath: file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let home = package.appendingPathComponent(
            ".build/angry-tmp/Фабрика модов 🦔 \(UUID().uuidString)/factorio data",
            isDirectory: true
        )
        try? FileManager.default.removeItem(at: home)
        self.dir = home.appendingPathComponent("mods", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    func manager() -> ModListManager {
        ModListManager(modsDirectory: dir)
    }

    @discardableResult
    func folder(_ name: String, _ version: String) throws -> FkMods {
        try FileManager.default.createDirectory(
            at: dir.appendingPathComponent("\(name)_\(version)", isDirectory: true),
            withIntermediateDirectories: true
        )
        return self
    }

    @discardableResult
    func info(_ folder: String, name: String, version: String, title: String, modified: Date) throws -> FkMods {
        let target = dir.appendingPathComponent(folder, isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let json = try JSONEncoder().encode(LocalModInfo(name: name, version: version, title: title))
        try json.write(to: target.appendingPathComponent("info.json"))
        try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: target.path)
        return self
    }

    @discardableResult
    func file(_ name: String, _ content: Data) throws -> URL {
        let target = dir.appendingPathComponent(name)
        try content.write(to: target)
        return target
    }

    @discardableResult
    func log(_ text: String) throws -> FkMods {
        try Data(text.utf8).write(to: dir.deletingLastPathComponent().appendingPathComponent("factorio-current.log"))
        return self
    }

    func outside(_ name: String) -> URL {
        dir.deletingLastPathComponent().appendingPathComponent(name)
    }

    func exists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: dir.appendingPathComponent(name).path)
    }
}
