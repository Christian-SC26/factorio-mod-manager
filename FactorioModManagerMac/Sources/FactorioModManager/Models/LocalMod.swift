import Foundation
import Compression

public struct LocalModInfo: Codable, Hashable, Sendable {
    public let name: String?
    public let version: String?
    public let title: String?
    public let author: String?
    public let description: String?
    public let factorio_version: String?
    public let dependencies: [String]?

    public init(
        name: String? = nil,
        version: String? = nil,
        title: String? = nil,
        author: String? = nil,
        description: String? = nil,
        factorio_version: String? = nil,
        dependencies: [String]? = nil
    ) {
        self.name = name
        self.version = version
        self.title = title
        self.author = author
        self.description = description
        self.factorio_version = factorio_version
        self.dependencies = dependencies
    }
}

public struct LocalMod: Identifiable, Hashable, Sendable {
    public var id: String { "\(name)_\(version.raw)_\(fileURL.path)" }
    public let name: String
    public let version: FactorioVersion
    public let fileURL: URL
    public let isDirectory: Bool
    public var enabled: Bool
    public let fileSize: Int64
    public let modificationDate: Date?
    public var info: LocalModInfo?

    public init(
        name: String,
        version: FactorioVersion,
        fileURL: URL,
        isDirectory: Bool,
        enabled: Bool = true,
        fileSize: Int64 = 0,
        modificationDate: Date? = nil,
        info: LocalModInfo? = nil
    ) {
        self.name = name
        self.version = version
        self.fileURL = fileURL
        self.isDirectory = isDirectory
        self.enabled = enabled
        self.fileSize = fileSize
        self.modificationDate = modificationDate
        self.info = info
    }

    public static func == (lhs: LocalMod, rhs: LocalMod) -> Bool {
        lhs.id == rhs.id && lhs.enabled == rhs.enabled && lhs.info?.title == rhs.info?.title
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(enabled)
    }

    public var displayTitle: String {
        if let t = info?.title?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            let upper = t.uppercased()
            // Ignore localization placeholders like [MOD DISPLAY NAME] or __mod-name__
            if !upper.contains("MOD DISPLAY NAME") && !t.hasPrefix("__") && !upper.contains("LOCALE") && t != "[mod-name]" {
                return t
            }
        }
        return Self.cleanHumanTitle(from: name)
    }

    public var title: String {
        displayTitle
    }

    public static func cleanHumanTitle(from rawName: String) -> String {
        var result = rawName
        result = result.replacingOccurrences(of: "_", with: " ")
        result = result.replacingOccurrences(of: "-", with: " ")
        
        let words = result.components(separatedBy: " ").filter { !$0.isEmpty }
        let capitalized = words.map { word -> String in
            let lower = word.lowercased()
            if ["se", "cr", "rpg", "t4", "gui", "hud", "ui", "hd", "2d", "3d"].contains(lower) {
                return lower.uppercased()
            }
            if word.count <= 2 { return word.uppercased() }
            return word.prefix(1).uppercased() + word.dropFirst()
        }
        return capitalized.joined(separator: " ")
    }

    public var author: String {
        let a = info?.author?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return a.isEmpty ? "—" : a
    }

    public var primaryAuthor: String {
        let a = author
        guard !a.isEmpty, a != "—" else { return "" }
        var clean = a.components(separatedBy: ",")[0]
        if let parenRange = clean.range(of: "(") {
            clean = String(clean[..<parenRange.lowerBound])
        }
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var authorPortalURL: URL? {
        let username = primaryAuthor
        guard !username.isEmpty, username != "—" else { return nil }
        let encoded = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        return URL(string: "https://mods.factorio.com/user/\(encoded)")
    }

    public var summary: String {
        info?.description ?? ""
    }

    public var factorioVersion: String {
        info?.factorio_version ?? "2.1"
    }

    public var formattedDate: String {
        guard let d = modificationDate else { return "—" }
        return Self.dateFormatter.string(from: d)
    }

    public var dateSortKey: Date {
        modificationDate ?? Date.distantPast
    }

    public var enabledSortKey: Int {
        enabled ? 1 : 0
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()

    public func getDependencies() -> [Dependency] {
        guard let rawDeps = info?.dependencies else { return [] }
        return rawDeps.compactMap { Dependency.parse($0) }
    }

    public static func loadInfoJson(from url: URL, isDirectory: Bool) -> LocalModInfo? {
        if isDirectory {
            let infoPath = url.appendingPathComponent("info.json")
            guard FileManager.default.fileExists(atPath: infoPath.path),
                  let data = try? Data(contentsOf: infoPath) else { return nil }
            return try? JSONDecoder().decode(LocalModInfo.self, from: data)
        } else if url.pathExtension.lowercased() == "zip" {
            return readInfoJsonFromZipInPureSwift(url: url)
        }
        return nil
    }

    /// Pure Swift in-memory ZIP parser for info.json (zero external subprocesses, ultra fast)
    public static func readInfoJsonFromZipInPureSwift(url: URL) -> LocalModInfo? {
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? fileHandle.close() }

        guard let fileSize = try? fileHandle.seekToEnd(), fileSize > 22 else { return nil }

        // Read up to last 65KB to locate End of Central Directory (EOCD)
        let readLen = min(fileSize, 65557)
        let startOffset = fileSize - readLen
        guard let _ = try? fileHandle.seek(toOffset: startOffset),
              let tailData = try? fileHandle.read(upToCount: Int(readLen)) else { return nil }

        // Find EOCD signature: 0x06054b50 (PK\x05\x06)
        var eocdOffsetInTail: Int? = nil
        let eocdSig: [UInt8] = [0x50, 0x4b, 0x05, 0x06]
        let tailBytes = [UInt8](tailData)

        for i in stride(from: tailBytes.count - 22, through: 0, by: -1) {
            if tailBytes[i] == eocdSig[0] &&
               tailBytes[i+1] == eocdSig[1] &&
               tailBytes[i+2] == eocdSig[2] &&
               tailBytes[i+3] == eocdSig[3] {
                eocdOffsetInTail = i
                break
            }
        }

        guard let eocdPos = eocdOffsetInTail, eocdPos + 20 <= tailBytes.count else { return nil }

        // Read Central Directory Offset and Size from EOCD
        let cdSize = UInt32(tailBytes[eocdPos + 12]) |
                     (UInt32(tailBytes[eocdPos + 13]) << 8) |
                     (UInt32(tailBytes[eocdPos + 14]) << 16) |
                     (UInt32(tailBytes[eocdPos + 15]) << 24)

        let cdOffset = UInt32(tailBytes[eocdPos + 16]) |
                       (UInt32(tailBytes[eocdPos + 17]) << 8) |
                       (UInt32(tailBytes[eocdPos + 18]) << 16) |
                       (UInt32(tailBytes[eocdPos + 19]) << 24)

        guard cdOffset < fileSize, let _ = try? fileHandle.seek(toOffset: UInt64(cdOffset)),
              let cdData = try? fileHandle.read(upToCount: Int(cdSize)) else { return nil }

        let cdBytes = [UInt8](cdData)
        var cursor = 0
        let cdHeaderSig: [UInt8] = [0x50, 0x4b, 0x01, 0x02]

        while cursor + 46 <= cdBytes.count {
            if cdBytes[cursor] != cdHeaderSig[0] ||
               cdBytes[cursor+1] != cdHeaderSig[1] ||
               cdBytes[cursor+2] != cdHeaderSig[2] ||
               cdBytes[cursor+3] != cdHeaderSig[3] {
                break
            }

            let compressionMethod = UInt16(cdBytes[cursor + 10]) | (UInt16(cdBytes[cursor + 11]) << 8)
            let compressedSize = UInt32(cdBytes[cursor + 20]) |
                                 (UInt32(cdBytes[cursor + 21]) << 8) |
                                 (UInt32(cdBytes[cursor + 22]) << 16) |
                                 (UInt32(cdBytes[cursor + 23]) << 24)
            let uncompressedSize = UInt32(cdBytes[cursor + 24]) |
                                   (UInt32(cdBytes[cursor + 25]) << 8) |
                                   (UInt32(cdBytes[cursor + 26]) << 16) |
                                   (UInt32(cdBytes[cursor + 27]) << 24)
            let filenameLen = Int(UInt16(cdBytes[cursor + 28]) | (UInt16(cdBytes[cursor + 29]) << 8))
            let extraLen = Int(UInt16(cdBytes[cursor + 30]) | (UInt16(cdBytes[cursor + 31]) << 8))
            let commentLen = Int(UInt16(cdBytes[cursor + 32]) | (UInt16(cdBytes[cursor + 33]) << 8))
            let localHeaderOffset = UInt32(cdBytes[cursor + 42]) |
                                    (UInt32(cdBytes[cursor + 43]) << 8) |
                                    (UInt32(cdBytes[cursor + 44]) << 16) |
                                    (UInt32(cdBytes[cursor + 45]) << 24)

            let fnStart = cursor + 46
            if fnStart + filenameLen <= cdBytes.count {
                let fnData = Data(cdBytes[fnStart..<(fnStart + filenameLen)])
                if let filename = String(data: fnData, encoding: .utf8), filename.hasSuffix("info.json") {
                    // Extract info.json
                    if let rawJsonData = extractLocalFile(
                        fileHandle: fileHandle,
                        localHeaderOffset: UInt64(localHeaderOffset),
                        compressionMethod: compressionMethod,
                        compressedSize: Int(compressedSize),
                        uncompressedSize: Int(uncompressedSize)
                    ) {
                        return try? JSONDecoder().decode(LocalModInfo.self, from: rawJsonData)
                    }
                }
            }

            cursor += 46 + filenameLen + extraLen + commentLen
        }

        return nil
    }

    private static func extractLocalFile(
        fileHandle: FileHandle,
        localHeaderOffset: UInt64,
        compressionMethod: UInt16,
        compressedSize: Int,
        uncompressedSize: Int
    ) -> Data? {
        guard let _ = try? fileHandle.seek(toOffset: localHeaderOffset),
              let headerData = try? fileHandle.read(upToCount: 30) else { return nil }

        let headerBytes = [UInt8](headerData)
        guard headerBytes.count >= 30,
              headerBytes[0] == 0x50, headerBytes[1] == 0x4b, headerBytes[2] == 0x03, headerBytes[3] == 0x04 else {
            return nil
        }

        let fnLen = Int(UInt16(headerBytes[26]) | (UInt16(headerBytes[27]) << 8))
        let extraLen = Int(UInt16(headerBytes[28]) | (UInt16(headerBytes[29]) << 8))
        let dataOffset = localHeaderOffset + 30 + UInt64(fnLen) + UInt64(extraLen)

        guard let _ = try? fileHandle.seek(toOffset: dataOffset),
              let payload = try? fileHandle.read(upToCount: compressedSize) else { return nil }

        if compressionMethod == 0 { // Stored (uncompressed)
            return payload
        } else if compressionMethod == 8 { // Deflate
            return decompressRawDeflate(payload, uncompressedSize: uncompressedSize)
        }

        return nil
    }

    private static func decompressRawDeflate(_ compressedData: Data, uncompressedSize: Int) -> Data? {
        var uncompressedData = Data(count: max(uncompressedSize, 1024))
        let decompressedCount = compressedData.withUnsafeBytes { rawIn -> Int in
            guard let inBase = rawIn.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
            return uncompressedData.withUnsafeMutableBytes { rawOut -> Int in
                guard let outBase = rawOut.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                return compression_decode_buffer(
                    outBase,
                    rawOut.count,
                    inBase,
                    rawIn.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        if decompressedCount > 0 {
            uncompressedData.count = decompressedCount
            return uncompressedData
        }
        return nil
    }
}
