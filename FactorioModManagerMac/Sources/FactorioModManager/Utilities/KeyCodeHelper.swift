import AppKit
import Foundation

/// Centralized helper for keyboard layout-independent navigation.
/// Maps physical ANSI key codes so shortcuts (j/k, x, Space, Cmd+A, Cmd+F, etc.)
/// work identically on Russian, German, French, Greek, Hebrew, and English layouts.
public enum KeyCodeHelper {
    // Physical ANSI key codes (Carbon / macOS Virtual Key Codes)
    public static let kVK_ANSI_A: UInt16 = 0x00 // 0
    public static let kVK_ANSI_S: UInt16 = 0x01 // 1
    public static let kVK_ANSI_D: UInt16 = 0x02 // 2
    public static let kVK_ANSI_F: UInt16 = 0x03 // 3
    public static let kVK_ANSI_H: UInt16 = 0x04 // 4
    public static let kVK_ANSI_G: UInt16 = 0x05 // 5
    public static let kVK_ANSI_Z: UInt16 = 0x06 // 6
    public static let kVK_ANSI_X: UInt16 = 0x07 // 7
    public static let kVK_ANSI_C: UInt16 = 0x08 // 8
    public static let kVK_ANSI_V: UInt16 = 0x09 // 9
    public static let kVK_ANSI_B: UInt16 = 0x0B // 11
    public static let kVK_ANSI_Q: UInt16 = 0x0C // 12
    public static let kVK_ANSI_W: UInt16 = 0x0D // 13
    public static let kVK_ANSI_E: UInt16 = 0x0E // 14
    public static let kVK_ANSI_R: UInt16 = 0x0F // 15
    public static let kVK_ANSI_Y: UInt16 = 0x10 // 16
    public static let kVK_ANSI_T: UInt16 = 0x11 // 17
    public static let kVK_ANSI_O: UInt16 = 0x1F // 31
    public static let kVK_ANSI_U: UInt16 = 0x20 // 32
    public static let kVK_ANSI_I: UInt16 = 0x22 // 34
    public static let kVK_ANSI_P: UInt16 = 0x23 // 35
    public static let kVK_ANSI_L: UInt16 = 0x25 // 37
    public static let kVK_ANSI_J: UInt16 = 0x26 // 38
    public static let kVK_ANSI_K: UInt16 = 0x28 // 40
    public static let kVK_ANSI_Slash: UInt16 = 0x2C // 44

    public static let kVK_Return: UInt16 = 0x24 // 36
    public static let kVK_Tab: UInt16 = 0x30 // 48
    public static let kVK_Space: UInt16 = 0x31 // 49
    public static let kVK_Delete: UInt16 = 0x33 // 51
    public static let kVK_Escape: UInt16 = 0x35 // 53
    public static let kVK_ForwardDelete: UInt16 = 0x75 // 117
    public static let kVK_LeftArrow: UInt16 = 0x7B // 123
    public static let kVK_RightArrow: UInt16 = 0x7C // 124
    public static let kVK_DownArrow: UInt16 = 0x7D // 125
    public static let kVK_UpArrow: UInt16 = 0x7E // 126

    /// Returns the standard QWERTY latin character for the physical key position
    public static func latinCharacter(for keyCode: UInt16) -> Character? {
        switch keyCode {
        case kVK_ANSI_A: return "a"
        case kVK_ANSI_B: return "b"
        case kVK_ANSI_C: return "c"
        case kVK_ANSI_D: return "d"
        case kVK_ANSI_E: return "e"
        case kVK_ANSI_F: return "f"
        case kVK_ANSI_G: return "g"
        case kVK_ANSI_H: return "h"
        case kVK_ANSI_I: return "i"
        case kVK_ANSI_J: return "j"
        case kVK_ANSI_K: return "k"
        case kVK_ANSI_L: return "l"
        case kVK_ANSI_O: return "o"
        case kVK_ANSI_P: return "p"
        case kVK_ANSI_Q: return "q"
        case kVK_ANSI_R: return "r"
        case kVK_ANSI_S: return "s"
        case kVK_ANSI_T: return "t"
        case kVK_ANSI_U: return "u"
        case kVK_ANSI_V: return "v"
        case kVK_ANSI_W: return "w"
        case kVK_ANSI_X: return "x"
        case kVK_ANSI_Y: return "y"
        case kVK_ANSI_Z: return "z"
        default: return nil
        }
    }

    /// Check if the physical key or the typed character matches targetChar
    public static func isKey(_ event: NSEvent, _ targetChar: Character) -> Bool {
        if let latin = latinCharacter(for: event.keyCode), latin == targetChar {
            return true
        }
        let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""
        return chars == String(targetChar)
    }

    /// Down arrow or physical 'j'
    public static func isDown(_ event: NSEvent) -> Bool {
        event.keyCode == kVK_DownArrow || isKey(event, "j")
    }

    /// Up arrow or physical 'k'
    public static func isUp(_ event: NSEvent) -> Bool {
        event.keyCode == kVK_UpArrow || isKey(event, "k")
    }

    /// Selection toggle with physical 'x'
    public static func isSelectToggle(_ event: NSEvent) -> Bool {
        isKey(event, "x")
    }

    /// Action / Details with physical 'i' or Return
    public static func isDetails(_ event: NSEvent) -> Bool {
        isKey(event, "i") || event.keyCode == kVK_Return
    }

    /// Space key
    public static func isSpace(_ event: NSEvent) -> Bool {
        event.keyCode == kVK_Space
    }

    /// Escape key
    public static func isEscape(_ event: NSEvent) -> Bool {
        event.keyCode == kVK_Escape
    }

    /// Select all with Cmd+A
    public static func isSelectAll(_ event: NSEvent) -> Bool {
        event.modifierFlags.contains(.command) && isKey(event, "a")
    }

    /// Slash key or Cmd+F for search
    public static func isSearch(_ event: NSEvent) -> Bool {
        let isCmd = event.modifierFlags.contains(.command)
        if isCmd && isKey(event, "f") {
            return true
        }
        if !isCmd && event.keyCode == kVK_ANSI_Slash {
            return true
        }
        return false
    }
}
