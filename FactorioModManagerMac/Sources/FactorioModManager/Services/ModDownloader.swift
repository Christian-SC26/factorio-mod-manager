import Foundation

public struct DownloadProgress: Identifiable, Sendable {
    public var id: String { modName }
    public let modName: String
    public let version: String
    public var bytesDownloaded: Int64
    public var totalBytes: Int64
    public var speedBytesPerSec: Double
    public var fractionCompleted: Double
    public var isCompleted: Bool
    public var error: String?

    public init(
        modName: String,
        version: String,
        bytesDownloaded: Int64 = 0,
        totalBytes: Int64 = 0,
        speedBytesPerSec: Double = 0,
        fractionCompleted: Double = 0,
        isCompleted: Bool = false,
        error: String? = nil
    ) {
        self.modName = modName
        self.version = version
        self.bytesDownloaded = bytesDownloaded
        self.totalBytes = totalBytes
        self.speedBytesPerSec = speedBytesPerSec
        self.fractionCompleted = fractionCompleted
        self.isCompleted = isCompleted
        self.error = error
    }
}

public protocol ModDownloading: Actor {
    func downloadAll(
        mods: [ResolvedMod],
        onProgress: @escaping @Sendable (DownloadProgress) -> Void
    ) async -> [DownloadProgress]

    func downloadSingle(
        mod: ResolvedMod,
        onProgress: @escaping @Sendable (DownloadProgress) -> Void
    ) async -> DownloadProgress
}

public actor ModDownloader: ModDownloading {
    private let modListMgr: ModListManager
    private let cleanOld: Bool
    private let autoEnable: Bool

    public init(
        modListMgr: ModListManager,
        cleanOld: Bool = true,
        autoEnable: Bool = true
    ) {
        self.modListMgr = modListMgr
        self.cleanOld = cleanOld
        self.autoEnable = autoEnable
    }

    /// Download a list of resolved mods sequentially with live progress updates
    public func downloadAll(
        mods: [ResolvedMod],
        onProgress: @escaping @Sendable (DownloadProgress) -> Void
    ) async -> [DownloadProgress] {
        var results: [DownloadProgress] = []
        var successfulNames: [String] = []

        for mod in mods {
            let res = await downloadSingle(mod: mod, onProgress: onProgress)
            results.append(res)
            if res.isCompleted && res.error == nil {
                successfulNames.append(mod.name)
            }
        }

        if autoEnable && !successfulNames.isEmpty {
            modListMgr.enableMods(successfulNames)
        }

        return results
    }

    /// Download a single mod archive with chunk streaming, speed calculation, integrity verification, and cleanup
    public func downloadSingle(
        mod: ResolvedMod,
        onProgress: @escaping @Sendable (DownloadProgress) -> Void
    ) async -> DownloadProgress {
        let destDir = modListMgr.modsDirectory
        try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        let fileName = mod.release.fileName.isEmpty ? "\(mod.name)_\(mod.release.version.raw).zip" : mod.release.fileName
        let targetFileURL = destDir.appendingPathComponent(fileName)
        let partFileURL = destDir.appendingPathComponent("\(fileName).part")

        guard let url = URL(string: mod.release.downloadUrl) else {
            let errProgress = DownloadProgress(
                modName: mod.name,
                version: mod.release.version.raw,
                isCompleted: true,
                error: FMMError.invalidDownloadURL(url: mod.release.downloadUrl).localizedDescription
            )
            onProgress(errProgress)
            return errProgress
        }

        var progress = DownloadProgress(
            modName: mod.name,
            version: mod.release.version.raw,
            bytesDownloaded: 0,
            totalBytes: 0,
            speedBytesPerSec: 0,
            fractionCompleted: 0,
            isCompleted: false
        )
        onProgress(progress)

        let maxRetries = 3
        var lastError: Error? = nil

        for attempt in 1...maxRetries {
            do {
                var request = URLRequest(url: url, timeoutInterval: 30)
                request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

                let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
                guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                    let code = (response as? HTTPURLResponse)?.statusCode ?? 500
                    throw FMMError.httpError(statusCode: code, message: nil)
                }

                let expectedLength = response.expectedContentLength
                progress.totalBytes = max(0, expectedLength)

                _ = try? FileManager.default.removeItem(at: partFileURL)
                FileManager.default.createFile(atPath: partFileURL.path, contents: nil)
                guard let fileHandle = try? FileHandle(forWritingTo: partFileURL) else {
                    throw FMMError.destinationFileCreationFailed(path: partFileURL.path)
                }

                let startTime = Date()
                var lastProgressUpdate = Date()
                var buffer = [UInt8]()
                buffer.reserveCapacity(64 * 1024)

                for try await byte in asyncBytes {
                    buffer.append(byte)
                    if buffer.count >= 64 * 1024 {
                        let chunk = Data(buffer)
                        try fileHandle.write(contentsOf: chunk)
                        progress.bytesDownloaded += Int64(buffer.count)
                        buffer.removeAll(keepingCapacity: true)

                        let now = Date()
                        if now.timeIntervalSince(lastProgressUpdate) >= 0.1 {
                            lastProgressUpdate = now
                            let elapsed = max(0.001, now.timeIntervalSince(startTime))
                            progress.speedBytesPerSec = Double(progress.bytesDownloaded) / elapsed
                            if progress.totalBytes > 0 {
                                progress.fractionCompleted = min(1.0, Double(progress.bytesDownloaded) / Double(progress.totalBytes))
                            }
                            onProgress(progress)
                        }
                    }
                }

                if !buffer.isEmpty {
                    let chunk = Data(buffer)
                    try fileHandle.write(contentsOf: chunk)
                    progress.bytesDownloaded += Int64(buffer.count)
                }
                try fileHandle.close()

                // Final progress calculation
                let totalElapsed = max(0.001, Date().timeIntervalSince(startTime))
                progress.speedBytesPerSec = Double(progress.bytesDownloaded) / totalElapsed
                progress.fractionCompleted = 1.0

                // Validate zip integrity using ZipArchiveReader
                if !ZipArchiveReader.isValidZipArchive(at: partFileURL) {
                    _ = try? FileManager.default.removeItem(at: partFileURL)
                    throw FMMError.invalidZipArchive(filename: fileName)
                }

                // Move part to final
                _ = try? FileManager.default.removeItem(at: targetFileURL)
                try FileManager.default.moveItem(at: partFileURL, to: targetFileURL)

                // Clean old versions of this mod if cleanOld is enabled
                if cleanOld {
                    cleanOlderVersions(modName: mod.name, keepingFile: targetFileURL, in: destDir)
                }

                progress.isCompleted = true
                progress.error = nil
                onProgress(progress)
                return progress

            } catch {
                lastError = error
                _ = try? FileManager.default.removeItem(at: partFileURL)
                if attempt < maxRetries {
                    try? await Task.sleep(nanoseconds: UInt64(attempt * 1_000_000_000))
                }
            }
        }

        progress.isCompleted = true
        progress.error = lastError?.localizedDescription ?? "Download failed"
        onProgress(progress)
        return progress
    }

    private func cleanOlderVersions(modName: String, keepingFile: URL, in directory: URL) {
        guard !FactorioConstants.isOfficialMod(modName) else { return }
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return
        }

        let zipRegex = RegexHelper.zipFilename
        let dirRegex = RegexHelper.dirModName
        let targetLower = modName.lowercased()

        for item in items where item.standardizedFileURL != keepingFile.standardizedFileURL {
            let filename = item.lastPathComponent
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

            if isDir {
                let range = NSRange(location: 0, length: filename.utf16.count)
                if let match = dirRegex.firstMatch(in: filename, options: [], range: range),
                   let nRange = Range(match.range(at: 1), in: filename) {
                    let name = String(filename[nRange])
                    if name.lowercased() == targetLower {
                        _ = try? FileManager.default.removeItem(at: item)
                    }
                } else if filename.lowercased() == targetLower {
                    _ = try? FileManager.default.removeItem(at: item)
                }
            } else if item.pathExtension.lowercased() == "zip" {
                let range = NSRange(location: 0, length: filename.utf16.count)
                if let match = zipRegex.firstMatch(in: filename, options: [], range: range),
                   let nRange = Range(match.range(at: 1), in: filename) {
                    let name = String(filename[nRange])
                    if name.lowercased() == targetLower {
                        _ = try? FileManager.default.removeItem(at: item)
                    }
                }
            }
        }
    }
}
