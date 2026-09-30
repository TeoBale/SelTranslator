import AppKit
import Carbon
import Foundation

@main
struct ShortcutFixtureCheck {
    @MainActor static func main() throws {
        func event(_ keyCode: UInt16, _ flags: NSEvent.ModifierFlags, characters: String) -> NSEvent {
            NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                             windowNumber: 0, context: nil, characters: characters,
                             charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode)!
        }
        let recorded = Shortcut(event: event(38, [.control, .shift], characters: "\u{a}"))!
        precondition(recorded.keyCode == 38)
        precondition(recorded.modifiers == UInt32(controlKey | shiftKey))
        precondition(!recorded.keyLabel.isEmpty && !recorded.keyLabel.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }))
        // Exact J label is layout dependent; Carbon always receives the actual pressed key.
        let encoded = try JSONEncoder().encode(recorded)
        let decoded = try JSONDecoder().decode(Shortcut.self, from: encoded)
        precondition(decoded == recorded)

        let legacy = Data(#"{"function":6,"command":true,"option":true,"control":false,"shift":false}"#.utf8)
        let restored = try JSONDecoder().decode(Shortcut.self, from: legacy)
        precondition(restored == Shortcut(function: 6))
        precondition(restored.label == "⌥⌘F6" && restored.keyCode == 97)
        let invalidLegacy = Data(#"{"function":99,"command":true,"option":true,"control":false,"shift":false}"#.utf8)
        do {
            _ = try JSONDecoder().decode(Shortcut.self, from: invalidLegacy)
            fatalError("Invalid legacy key must not silently map to another key")
        } catch DecodingError.dataCorrupted { }

        precondition(Shortcut(event: event(55, .command, characters: "")) == nil)
        precondition(Shortcut(event: event(48, [.control], characters: "\t"))?.label == "⌃⇥")
        precondition(Shortcut(event: event(123, [.command, .option], characters: ""))?.label == "⌥⌘←")
        precondition(Shortcut(event: event(111, [.shift], characters: ""))?.label == "⇧F12")
        precondition(Shortcut(event: event(53, [.control], characters: ""))?.label == "⌃⎋")
        precondition(Shortcut(event: event(49, [], characters: " "))?.label == "Space")
        print("Shortcut capture, modifiers, special keys, persistence, and legacy migration passed (captured \(recorded.label)).")
    }
}
