import AppKit

/// A synthetic key press: physical key code plus the character the current layout produced.
struct FkKeyEvent {
    let code: UInt16
    let typed: String
    let modifiers: NSEvent.ModifierFlags

    func event() -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: typed,
            charactersIgnoringModifiers: typed,
            isARepeat: false,
            keyCode: code
        )!
    }
}
