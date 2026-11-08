import AppKit
import Foundation
import Testing
@testable import FactorioModManagerMac

@Suite(.tags(.fast), .timeLimit(.minutes(1)))
struct KeyCodeHelperTests {
    @Test(arguments: [
        (UInt16(0x26), Character("j")),
        (0x28, "k"),
        (0x07, "x"),
        (0x00, "a"),
        (0x03, "f"),
        (0x22, "i"),
        (0x2E, "m"),
        (0x2D, "n")
    ] as [(UInt16, Character)])
    func mapsPhysicalKeyToLatinLetter(code: UInt16, letter: Character) {
        #expect(KeyCodeHelper.latinCharacter(for: code) == letter, "key \(code) is '\(letter)' on ANSI QWERTY")
    }

    @Test
    func givesNoLetterForSpace() {
        #expect(KeyCodeHelper.latinCharacter(for: KeyCodeHelper.kVK_Space) == nil, "space is not a letter")
    }

    @Test
    func treatsDownArrowAsDown() {
        #expect(KeyCodeHelper.isDown(FkKeyEvent(code: KeyCodeHelper.kVK_DownArrow, typed: "", modifiers: []).event()), "arrow down moves down")
    }

    @Test
    func doesNotTreatDownArrowAsUp() {
        #expect(!KeyCodeHelper.isUp(FkKeyEvent(code: KeyCodeHelper.kVK_DownArrow, typed: "", modifiers: []).event()), "arrow down never moves up")
    }

    @Test
    func treatsRussianOAsDown() {
        #expect(KeyCodeHelper.isDown(FkKeyEvent(code: KeyCodeHelper.kVK_ANSI_J, typed: "о", modifiers: []).event()), "physical J on ЙЦУКЕН")
    }

    @Test
    func treatsRussianLAsUp() {
        #expect(KeyCodeHelper.isUp(FkKeyEvent(code: KeyCodeHelper.kVK_ANSI_K, typed: "л", modifiers: []).event()), "physical K on ЙЦУКЕН")
    }

    @Test
    func togglesSelectionWithRussianCh() {
        #expect(KeyCodeHelper.isSelectToggle(FkKeyEvent(code: KeyCodeHelper.kVK_ANSI_X, typed: "ч", modifiers: []).event()), "physical X")
    }

    @Test
    func searchesWithCommandAndRussianA() {
        #expect(KeyCodeHelper.isSearch(FkKeyEvent(code: KeyCodeHelper.kVK_ANSI_F, typed: "а", modifiers: [.command]).event()), "Cmd+F on ЙЦУКЕН")
    }

    @Test
    func searchesWithBareSlash() {
        #expect(KeyCodeHelper.isSearch(FkKeyEvent(code: KeyCodeHelper.kVK_ANSI_Slash, typed: ".", modifiers: []).event()), "'/' opens search")
    }

    @Test
    func selectsAllOnlyWithCommand() {
        #expect(!KeyCodeHelper.isSelectAll(FkKeyEvent(code: KeyCodeHelper.kVK_ANSI_A, typed: "ф", modifiers: []).event()), "bare A types")
    }
}
