import AppKit
import Foundation

/// Drives the in-app update of FMM itself: check GitHub, download, verify, swap the bundle, relaunch.
@MainActor
public final class AppUpdateManager: ObservableObject {
    public static let shared = AppUpdateManager()

    public enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case downloading
        case installing
        case failed(String)
    }

    private static let autoCheckKey = "app_update_auto_check"

    /// Newer release than the running one, once a check has found it.
    @Published public private(set) var available: AppRelease?
    @Published public private(set) var status: Status = .idle
    @Published public var checkAutomatically: Bool {
        didSet { UserDefaults.standard.set(checkAutomatically, forKey: Self.autoCheckKey) }
    }

    public let currentVersion: AppVersion?
    private let bundleURL: URL
    private let updater: AppUpdater

    private init() {
        let bundle = Bundle.main
        currentVersion = (bundle.infoDictionary?["CFBundleShortVersionString"] as? String).flatMap(AppVersion.init)
        bundleURL = bundle.bundleURL
        updater = AppUpdater(
            bundleIdentifier: bundle.bundleIdentifier ?? "com.christian.FactorioModManager",
            requiredTeam: AppUpdater.runningTeam()
        )
        checkAutomatically = UserDefaults.standard.object(forKey: Self.autoCheckKey) as? Bool ?? true
    }

    /// Localization key of the reason this copy cannot update itself, or `nil`.
    public var installBlocker: String? {
        AppUpdater.installBlocker(for: bundleURL)
    }

    public var isBusy: Bool {
        [.checking, .downloading, .installing].contains(status)
    }

    /// Quiet check at startup: only a found update is shown, errors are not.
    public func checkAtLaunch() {
        guard checkAutomatically, currentVersion != nil else { return }
        Task { await check(quietly: true) }
    }

    public func check(quietly: Bool = false) async {
        guard !isBusy else { return }
        status = .checking
        do {
            let latest = try await updater.latestRelease()
            if let currentVersion, latest.version <= currentVersion {
                available = nil
                status = .upToDate
            } else {
                available = latest
                status = .idle
            }
        } catch {
            status = quietly ? .idle : .failed(error.localizedDescription)
        }
    }

    /// Downloads the found release, verifies it and relaunches into it.
    public func install() async {
        guard let release = available, !isBusy else { return }
        if let blocker = installBlocker {
            status = .failed(loc(blocker))
            return
        }
        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("FMM-Update-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
            status = .downloading
            let archive = try await updater.download(release, into: staging)
            status = .installing
            let updater = self.updater
            let app = try await Task.detached { try updater.stage(archive: archive, into: staging) }.value
            try AppUpdater.replaceAfterExit(
                pid: ProcessInfo.processInfo.processIdentifier,
                target: bundleURL,
                staged: app,
                cleanup: staging
            )
            NSApp.terminate(nil)
        } catch {
            try? FileManager.default.removeItem(at: staging)
            status = .failed(error.localizedDescription)
        }
    }
}
