import Compression
import Foundation

/// Builds a real ZIP archive in memory, with entries either stored or deflated.
struct ZipFixture {
    let entries: [(name: String, content: Data)]
    let deflate: Bool

    func data() -> Data {
        var body = Data()
        var central = Data()
        for entry in entries {
            let packed = deflate ? Self.deflated(entry.content) : entry.content
            let name = Data(entry.name.utf8)
            let crc = Self.crc32(entry.content)
            let offset = UInt32(body.count)
            let method: UInt16 = deflate ? 8 : 0
            body += le32(0x0403_4b50) + le16(20) + le16(0) + le16(method) + le16(0) + le16(0)
            body += le32(crc) + le32(UInt32(packed.count)) + le32(UInt32(entry.content.count))
            body += le16(UInt16(name.count)) + le16(0) + name + packed
            central += le32(0x0201_4b50) + le16(20) + le16(20) + le16(0) + le16(method) + le16(0) + le16(0)
            central += le32(crc) + le32(UInt32(packed.count)) + le32(UInt32(entry.content.count))
            central += le16(UInt16(name.count)) + le16(0) + le16(0) + le16(0) + le16(0) + le32(0) + le32(offset)
            central += name
        }
        let count = UInt16(entries.count)
        let end = le32(0x0605_4b50) + le16(0) + le16(0) + le16(count) + le16(count)
            + le32(UInt32(central.count)) + le32(UInt32(body.count)) + le16(0)
        return body + central + end
    }

    func write(to url: URL) throws -> URL {
        try data().write(to: url)
        return url
    }

    private static func deflated(_ data: Data) -> Data {
        var out = Data(count: data.count + 1024)
        let written = out.withUnsafeMutableBytes { dst in
            data.withUnsafeBytes { src in
                compression_encode_buffer(
                    dst.bindMemory(to: UInt8.self).baseAddress!,
                    dst.count,
                    src.bindMemory(to: UInt8.self).baseAddress!,
                    src.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        return out.prefix(written)
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc >> 1) ^ (0xEDB8_8320 & (0 &- (crc & 1)))
            }
        }
        return ~crc
    }
}

/// Random bytes shaped like the tail of a ZIP archive: a valid end-of-central-directory record
/// pointing at a central directory header filled with garbage.
struct ZipGarbage {
    let length: Int

    func data() -> Data {
        var bytes = (0..<length).map { _ in UInt8.random(in: 0...255) }
        let directory = Int.random(in: 0..<(length - 80))
        bytes.replaceSubrange(directory..<(directory + 4), with: [0x50, 0x4B, 0x01, 0x02])
        let end = length - 22
        bytes.replaceSubrange(end..<(end + 4), with: [0x50, 0x4B, 0x05, 0x06])
        bytes.replaceSubrange((end + 12)..<(end + 16), with: [UInt8](le32(UInt32(end - directory))))
        bytes.replaceSubrange((end + 16)..<(end + 20), with: [UInt8](le32(UInt32(directory))))
        return Data(bytes)
    }
}

private func le16(_ value: UInt16) -> Data {
    Data([UInt8(value & 0xFF), UInt8(value >> 8)])
}

private func le32(_ value: UInt32) -> Data {
    Data([UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF), UInt8((value >> 16) & 0xFF), UInt8(value >> 24)])
}
