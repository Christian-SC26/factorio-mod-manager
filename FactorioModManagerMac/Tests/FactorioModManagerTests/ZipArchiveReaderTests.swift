import XCTest
@testable import FactorioModManagerMac

final class ZipArchiveReaderTests: XCTestCase {
    func testNonExistentFileReturnsFalse() {
        let fakeURL = URL(fileURLWithPath: "/tmp/non_existent_\(UUID().uuidString).zip")
        XCTAssertFalse(ZipArchiveReader.isValidZipArchive(at: fakeURL))
        XCTAssertNil(ZipArchiveReader.readInfoJson(from: fakeURL))
    }

    func testInvalidFileReturnsFalse() throws {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try "Not a zip file content".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        XCTAssertFalse(ZipArchiveReader.isValidZipArchive(at: tempFile))
        XCTAssertNil(ZipArchiveReader.readInfoJson(from: tempFile))
    }
}
