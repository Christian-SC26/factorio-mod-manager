import Foundation
import Security

/// Release version such as `v2.2.0` or `2.2`; tags with a suffix (`2.3.0-beta`) are not releases.
public struct AppVersion: Comparable, CustomStringConvertible, Sendable {
    public let parts: [Int]

    public init?(_ raw: String) {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("v") || text.hasPrefix("V") {
            text.removeFirst()
        }
        var numbers: [Int] = []
        for piece in text.split(separator: ".", omittingEmptySubsequences: false) {
            guard let number = Int(piece), number >= 0 else { return nil }
            numbers.append(number)
        }
        guard !numbers.isEmpty else { return nil }
        parts = numbers
    }

    public var description: String {
        parts.map(String.init).joined(separator: ".")
    }

    private func padded(to count: Int) -> [Int] {
        parts + Array(repeating: 0, count: max(0, count - parts.count))
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.parts.count, rhs.parts.count)
        return lhs.padded(to: count) == rhs.padded(to: count)
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.parts.count, rhs.parts.count)
        return lhs.padded(to: count).lexicographicallyPrecedes(rhs.padded(to: count))
    }
}

/// A published GitHub release of FMM.
public struct AppRelease: Equatable, Sendable {
    public let version: AppVersion
    public let notes: String
    public let pageURL: URL
    public let downloadURL: URL

    /// Reads the answer of `GET /repos/{owner}/{repo}/releases/latest`.
    public static func parse(_ data: Data, assetName: String) throws -> AppRelease {
        struct Asset: Decodable {
            let name: String
            let browser_download_url: URL
        }
        struct Payload: Decodable {
            let tag_name: String
            let body: String?
            let html_url: URL
            let assets: [Asset]
        }
        let payload: Payload
        do {
            payload = try JSONDecoder().decode(Payload.self, from: data)
        } catch {
            throw AppUpdateError.badResponse
        }
        guard let version = AppVersion(payload.tag_name) else {
            throw AppUpdateError.badResponse
        }
        guard let asset = payload.assets.first(where: { $0.name == assetName }) else {
            throw AppUpdateError.noAsset
        }
        return AppRelease(
            version: version,
            notes: payload.body ?? "",
            pageURL: payload.html_url,
            downloadURL: asset.browser_download_url
        )
    }
}

public enum AppUpdateError: LocalizedError, Equatable {
    case badResponse
    case server(Int)
    case noAsset
    case unpackFailed
    case notAnApp
    case wrongApp
    case badSignature
    case wrongTeam

    public var errorDescription: String? {
        switch self {
        case .badResponse: return loc("app_update_error_response")
        case .server(let status): return loc("app_update_error_server", status)
        case .noAsset: return loc("app_update_error_no_asset")
        case .unpackFailed: return loc("app_update_error_unpack")
        case .notAnApp: return loc("app_update_error_not_app")
        case .wrongApp: return loc("app_update_error_wrong_app")
        case .badSignature: return loc("app_update_error_signature")
        case .wrongTeam: return loc("app_update_error_team")
        }
    }
}

/// Finds, downloads and verifies new FMM releases, then swaps the app bundle once FMM quits.
public struct AppUpdater: Sendable {
    public static let latestReleaseURL = URL(string: "https://api.github.com/repos/Christian-SC26/factorio-mod-manager/releases/latest")!
    public static let assetName = "FMM-macOS.zip"

    public let latestURL: URL
    public let assetName: String
    public let bundleIdentifier: String
    /// Team ID the new build must be signed with; `nil` accepts any valid signature (ad-hoc builds from source).
    public let requiredTeam: String?

    public init(
        latestURL: URL = AppUpdater.latestReleaseURL,
        assetName: String = AppUpdater.assetName,
        bundleIdentifier: String,
        requiredTeam: String?
    ) {
        self.latestURL = latestURL
        self.assetName = assetName
        self.bundleIdentifier = bundleIdentifier
        self.requiredTeam = requiredTeam
    }

    public func latestRelease() async throws -> AppRelease {
        var request = URLRequest(url: latestURL, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("FMM-Updater", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.requireSuccess(response)
        return try AppRelease.parse(data, assetName: assetName)
    }

    /// Downloads the release archive into `directory` and returns its location.
    public func download(_ release: AppRelease, into directory: URL) async throws -> URL {
        var request = URLRequest(url: release.downloadURL, timeoutInterval: 120)
        request.setValue("FMM-Updater", forHTTPHeaderField: "User-Agent")
        let (temporary, response) = try await URLSession.shared.download(for: request)
        try Self.requireSuccess(response)
        let archive = directory.appendingPathComponent(assetName)
        try? FileManager.default.removeItem(at: archive)
        try FileManager.default.moveItem(at: temporary, to: archive)
        return archive
    }

    /// Unpacks the archive into `directory` and returns the app inside once its identity and signature check out.
    public func stage(archive: URL, into directory: URL) throws -> URL {
        let unpacked = directory.appendingPathComponent("unpacked", isDirectory: true)
        try? FileManager.default.removeItem(at: unpacked)
        try FileManager.default.createDirectory(at: unpacked, withIntermediateDirectories: true)
        guard Self.run("/usr/bin/ditto", ["-x", "-k", archive.path, unpacked.path]) else {
            throw AppUpdateError.unpackFailed
        }
        let entries = (try? FileManager.default.contentsOfDirectory(at: unpacked, includingPropertiesForKeys: nil)) ?? []
        guard let app = entries.first(where: { $0.pathExtension == "app" }) else {
            throw AppUpdateError.notAnApp
        }
        let info = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist"))
        guard info?["CFBundleIdentifier"] as? String == bundleIdentifier else {
            throw AppUpdateError.wrongApp
        }
        let team = try Self.verifiedTeam(of: app)
        if let requiredTeam, team != requiredTeam {
            throw AppUpdateError.wrongTeam
        }
        return app
    }

    /// Team ID of a bundle whose signature is intact; `nil` for an ad-hoc signature.
    public static func verifiedTeam(of bundle: URL) throws -> String? {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(bundle as CFURL, [], &code) == errSecSuccess, let code else {
            throw AppUpdateError.badSignature
        }
        let strict = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode)
        guard SecStaticCodeCheckValidity(code, strict, nil) == errSecSuccess else {
            throw AppUpdateError.badSignature
        }
        return signingTeam(of: code)
    }

    /// Team ID the running copy of FMM is signed with, if any.
    public static func runningTeam() -> String? {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(Bundle.main.bundleURL as CFURL, [], &code) == errSecSuccess, let code else {
            return nil
        }
        return signingTeam(of: code)
    }

    private static func signingTeam(of code: SecStaticCode) -> String? {
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess else {
            return nil
        }
        return (info as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String
    }

    /// Localization key explaining why the bundle at `bundle` cannot replace itself, or `nil` when it can.
    public static func installBlocker(for bundle: URL) -> String? {
        guard bundle.pathExtension == "app" else {
            return "app_update_blocked_dev"
        }
        if bundle.path.contains("/AppTranslocation/") {
            return "app_update_blocked_translocated"
        }
        let parent = bundle.deletingLastPathComponent().path
        guard FileManager.default.isWritableFile(atPath: parent), FileManager.default.isWritableFile(atPath: bundle.path) else {
            return "app_update_blocked_readonly"
        }
        return nil
    }

    /// Starts a helper that waits for process `pid` to exit, puts `staged` in place of `target`
    /// (restoring the old copy if that fails), deletes `cleanup` and opens the app again.
    public static func replaceAfterExit(pid: Int32, target: URL, staged: URL, cleanup: URL) throws {
        let script = """
        pid="$1"; target="$2"; staged="$3"; cleanup="$4"; backup="$target.fmm-previous"
        while kill -0 "$pid" 2>/dev/null; do sleep 0.3; done
        rm -rf "$backup"
        if mv "$target" "$backup"; then
            if ditto "$staged" "$target"; then
                rm -rf "$backup"
            else
                rm -rf "$target"
                mv "$backup" "$target"
            fi
        fi
        rm -rf "$cleanup"
        open "$target"
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, "fmm-update", String(pid), target.path, staged.path, cleanup.path]
        try process.run()
    }

    private static func requireSuccess(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw AppUpdateError.badResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw AppUpdateError.server(http.statusCode)
        }
    }

    private static func run(_ tool: String, _ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return false
        }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
