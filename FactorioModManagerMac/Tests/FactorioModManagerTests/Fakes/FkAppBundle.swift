import Foundation

/// A tiny `FMM.app` in a fresh temporary folder, optionally ad-hoc signed and zipped like a release.
struct FkAppBundle {
    struct Failed: Error {}

    let folder: URL

    init(identifier: String, signed: Bool) throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("FkApp-\(UUID().uuidString)", isDirectory: true)
        let contents = folder.appendingPathComponent("FMM.app/Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents.appendingPathComponent("MacOS"), withIntermediateDirectories: true)
        let info: NSDictionary = [
            "CFBundleIdentifier": identifier,
            "CFBundleExecutable": "FMM",
            "CFBundlePackageType": "APPL",
        ]
        try info.write(to: contents.appendingPathComponent("Info.plist"))
        try FileManager.default.copyItem(atPath: "/usr/bin/true", toPath: contents.appendingPathComponent("MacOS/FMM").path)
        if signed {
            try Self.run("/usr/bin/codesign", ["--force", "--sign", "-", app.path])
        }
    }

    var app: URL {
        folder.appendingPathComponent("FMM.app")
    }

    /// Zips the bundle the way the release does and returns the archive.
    func archive() throws -> URL {
        let zip = folder.appendingPathComponent("FMM-macOS.zip")
        try Self.run("/usr/bin/ditto", ["-c", "-k", "--keepParent", app.path, zip.path])
        return zip
    }

    /// A fresh empty folder to stage into.
    func staging() throws -> URL {
        let dir = folder.appendingPathComponent("staging-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func remove() {
        try? FileManager.default.removeItem(at: folder)
    }

    private static func run(_ tool: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw Failed() }
    }
}
