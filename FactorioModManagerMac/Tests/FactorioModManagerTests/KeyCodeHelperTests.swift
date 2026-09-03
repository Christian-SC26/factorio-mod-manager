import XCTest
import AppKit
@testable import FactorioModManagerMac

final class KeyCodeHelperTests: XCTestCase {
    func testLatinCharacterMapping() {
        XCTAssertEqual(KeyCodeHelper.latinCharacter(for: KeyCodeHelper.kVK_ANSI_J), "j")
        XCTAssertEqual(KeyCodeHelper.latinCharacter(for: KeyCodeHelper.kVK_ANSI_K), "k")
        XCTAssertEqual(KeyCodeHelper.latinCharacter(for: KeyCodeHelper.kVK_ANSI_X), "x")
        XCTAssertEqual(KeyCodeHelper.latinCharacter(for: KeyCodeHelper.kVK_ANSI_A), "a")
        XCTAssertEqual(KeyCodeHelper.latinCharacter(for: KeyCodeHelper.kVK_ANSI_F), "f")
        XCTAssertEqual(KeyCodeHelper.latinCharacter(for: KeyCodeHelper.kVK_ANSI_I), "i")
        XCTAssertNil(KeyCodeHelper.latinCharacter(for: KeyCodeHelper.kVK_Space))
    }

    func testIsDownAndIsUp() {
        // Arrow down
        let downArrowEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: KeyCodeHelper.kVK_DownArrow
        )!
        XCTAssertTrue(KeyCodeHelper.isDown(downArrowEvent))
        XCTAssertFalse(KeyCodeHelper.isUp(downArrowEvent))

        // Russian layout J key: produces 'о' but physical keyCode is 0x26
        let russianJEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "о",
            charactersIgnoringModifiers: "о",
            isARepeat: false,
            keyCode: KeyCodeHelper.kVK_ANSI_J
        )!
        XCTAssertTrue(KeyCodeHelper.isDown(russianJEvent))
        XCTAssertFalse(KeyCodeHelper.isUp(russianJEvent))

        // Russian layout K key: produces 'л' but physical keyCode is 0x28
        let russianKEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "л",
            charactersIgnoringModifiers: "л",
            isARepeat: false,
            keyCode: KeyCodeHelper.kVK_ANSI_K
        )!
        XCTAssertTrue(KeyCodeHelper.isUp(russianKEvent))
        XCTAssertFalse(KeyCodeHelper.isDown(russianKEvent))
    }

    func testIsSelectToggleWithRussianLayout() {
        // Russian layout X key: produces 'ч' but physical keyCode is 0x07
        let russianXEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "ч",
            charactersIgnoringModifiers: "ч",
            isARepeat: false,
            keyCode: KeyCodeHelper.kVK_ANSI_X
        )!
        XCTAssertTrue(KeyCodeHelper.isSelectToggle(russianXEvent))
    }
}
