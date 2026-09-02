import XCTest
@testable import FactorioModManagerMac

final class RegexHelperTests: XCTestCase {
    func testZipFilenamePattern() {
        let regex = RegexHelper.zipFilename
        let fn = "space-exploration_0.6.140.zip"
        let range = NSRange(location: 0, length: fn.utf16.count)
        guard let match = regex.firstMatch(in: fn, options: [], range: range) else {
            XCTFail("Should match zip filename")
            return
        }

        if let r1 = Range(match.range(at: 1), in: fn),
           let r2 = Range(match.range(at: 2), in: fn) {
            XCTAssertEqual(String(fn[r1]), "space-exploration")
            XCTAssertEqual(String(fn[r2]), "0.6.140")
        } else {
            XCTFail("Groups not found")
        }
    }

    func testDirModPattern() {
        let regex = RegexHelper.dirModName
        let dir = "Krastorio2_1.3.24"
        let range = NSRange(location: 0, length: dir.utf16.count)
        guard let match = regex.firstMatch(in: dir, options: [], range: range) else {
            XCTFail("Should match directory mod name")
            return
        }

        if let r1 = Range(match.range(at: 1), in: dir),
           let r2 = Range(match.range(at: 2), in: dir) {
            XCTAssertEqual(String(dir[r1]), "Krastorio2")
            XCTAssertEqual(String(dir[r2]), "1.3.24")
        } else {
            XCTFail("Groups not found")
        }
    }

    func testFirstCapturedGroupHelper() {
        let text = #"<h2 class="title"><a href="/mod/test-mod">My Test Mod</a></h2>"#
        let captured = RegexHelper.firstCapturedGroup(in: text, regex: RegexHelper.portalCardLink)
        XCTAssertEqual(captured, "test-mod")
    }
}
