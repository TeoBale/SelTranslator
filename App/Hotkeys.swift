import AppKit
import Carbon
import Observation
import TranslationCore

struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var keyLabel: String
    var command: Bool
    var option: Bool
    var control: Bool
    var shift: Bool

    init(function: Int) {
        self.init(keyCode: Self.functionCodes[function - 1], keyLabel: "F\(function)",
                  command: true, option: true, control: false, shift: false)
    }

    init(keyCode: UInt32, keyLabel: String, command: Bool, option: Bool, control: Bool, shift: Bool) {
        self.keyCode = keyCode; self.keyLabel = keyLabel
        self.command = command; self.option = option; self.control = control; self.shift = shift
    }

    init?(event: NSEvent) {
        // Modifier-only presses do not complete a recording.
        guard event.type == .keyDown, !Self.modifierCodes.contains(event.keyCode) else { return nil }
        let flags = event.modifierFlags
        self.init(keyCode: UInt32(event.keyCode), keyLabel: Self.label(for: event),
                  command: flags.contains(.command), option: flags.contains(.option),
                  control: flags.contains(.control), shift: flags.contains(.shift))
    }

    var modifiers: UInt32 {
        UInt32((command ? cmdKey : 0) | (option ? optionKey : 0) | (control ? controlKey : 0) | (shift ? shiftKey : 0))
    }
    var label: String { "\(control ? "⌃" : "")\(option ? "⌥" : "")\(shift ? "⇧" : "")\(command ? "⌘" : "")\(keyLabel)" }
    static let functionCodes: [UInt32] = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90]
    static let modifierCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]

    private static func label(for event: NSEvent) -> String {
        if let index = functionCodes.firstIndex(of: UInt32(event.keyCode)) { return "F\(index + 1)" }
        let special: [UInt16: String] = [36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋", 71: "Clear", 76: "⌤", 114: "Help", 115: "↖", 116: "⇞", 117: "⌦", 119: "↘", 121: "⇟", 123: "←", 124: "→", 125: "↓", 126: "↑"]
        if let label = special[event.keyCode] { return label }
        // Translate the physical key using the active layout without Ctrl/Option/Shift,
        // which can otherwise turn letters into control characters or alternate symbols.
        let source = TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue()
        if let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) {
            let data = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue()
            let layout = UnsafeRawPointer(CFDataGetBytePtr(data)).assumingMemoryBound(to: UCKeyboardLayout.self)
            var deadKey: UInt32 = 0
            var length = 0
            var characters = [UniChar](repeating: 0, count: 8)
            let status = UCKeyTranslate(layout, event.keyCode, UInt16(kUCKeyActionDown), 0,
                                        UInt32(LMGetKbdType()), OptionBits(1 << kUCKeyTranslateNoDeadKeysBit),
                                        &deadKey, characters.count, &length, &characters)
            if status == noErr, length > 0 {
                return String(utf16CodeUnits: characters, count: length).uppercased()
            }
        }
        let text = event.charactersIgnoringModifiers ?? ""
        if !text.isEmpty, !text.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) {
            return text.uppercased()
        }
        return "Key \(event.keyCode)"
    }

    private enum CodingKeys: String, CodingKey { case keyCode, keyLabel, function, command, option, control, shift }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        if let code = try values.decodeIfPresent(UInt32.self, forKey: .keyCode) {
            keyCode = code
            keyLabel = try values.decode(String.self, forKey: .keyLabel)
        } else {
            // Preserve shortcuts saved by the previous function-key editor.
            let function = try values.decode(Int.self, forKey: .function)
            guard (1...12).contains(function) else {
                throw DecodingError.dataCorruptedError(forKey: .function, in: values, debugDescription: "Invalid function key")
            }
            keyCode = Self.functionCodes[function - 1]; keyLabel = "F\(function)"
        }
        command = try values.decode(Bool.self, forKey: .command)
        option = try values.decode(Bool.self, forKey: .option)
        control = try values.decode(Bool.self, forKey: .control)
        shift = try values.decode(Bool.self, forKey: .shift)
    }
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(keyCode, forKey: .keyCode); try values.encode(keyLabel, forKey: .keyLabel)
        try values.encode(command, forKey: .command); try values.encode(option, forKey: .option)
        try values.encode(control, forKey: .control); try values.encode(shift, forKey: .shift)
    }
}

@MainActor @Observable
final class Hotkeys {
    static weak var shared: Hotkeys?
    private var transactions: [Int: ShortcutTransaction<Shortcut, EventHotKeyRef>] = [:]
    private var eventCommands: [UInt32: Int] = [:]
    private var nextID: UInt32 = 1
    private var handler: EventHandlerRef?
    var shortcuts: [Int: Shortcut] = [:]
    var error: String?
    var onCommand: ((Int) -> Void)?
    @ObservationIgnored var onRecordedShortcut: ((Shortcut) -> Void)?

    init() {
        Self.shared = self
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            guard let event else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard result == noErr else { return result }
            let value = id.id
            Task { @MainActor in
                guard let owner = Hotkeys.shared, let command = owner.eventCommands[value] else { return }
                if let record = owner.onRecordedShortcut, let shortcut = owner.shortcuts[command] {
                    record(shortcut)
                } else {
                    owner.onCommand?(command)
                }
            }
            return noErr
        }, 1, &spec, nil, &handler)
        guard status == noErr else { error = "Could not install the global shortcut handler. Restart the app to try again."; return }
        for command in 0...2 {
            let key = "shortcut.\(command)"
            if let data = UserDefaults.standard.data(forKey: key), let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data) {
                set(shortcut, for: command)
            } else if command == 0 && !UserDefaults.standard.bool(forKey: "shortcut.disabled.0") {
                set(Shortcut(function: 6), for: command)
            }
        }
    }

    func set(_ shortcut: Shortcut?, for command: Int) {
        error = nil
        guard shortcuts[command] != shortcut else { return }
        if let shortcut, shortcut.keyCode > 127 || Shortcut.modifierCodes.contains(UInt16(shortcut.keyCode)) {
            error = "Press a key, optionally with modifiers."; return
        }
        if let shortcut, shortcuts.contains(where: { $0.key != command && $0.value.keyCode == shortcut.keyCode && $0.value.modifiers == shortcut.modifiers }) {
            error = "\(shortcut.label) is already assigned to another translation command. The previous shortcut remains active."
            return
        }
        let transaction = transactions[command] ?? ShortcutTransaction<Shortcut, EventHotKeyRef>()
        transactions[command] = transaction
        let newID = nextID
        nextID += 1
        do {
            try transaction.change(to: shortcut, register: { value in
                var ref: EventHotKeyRef?
                let status = RegisterEventHotKey(value.keyCode, value.modifiers, EventHotKeyID(signature: 0x5354524E, id: newID), GetApplicationEventTarget(), 0, &ref)
                guard status == noErr, let ref else { throw RegistrationFailure(status: status) }
                return ref
            }, remove: { ref in
                let status = UnregisterEventHotKey(ref)
                guard status == noErr else { throw RemovalFailure(status: status) }
            }, persist: { value in
                eventCommands = eventCommands.filter { $0.value != command }
                if value != nil { eventCommands[newID] = command }
                shortcuts[command] = value
                UserDefaults.standard.set(value.flatMap { try? JSONEncoder().encode($0) }, forKey: "shortcut.\(command)")
                UserDefaults.standard.set(value == nil, forKey: "shortcut.disabled.\(command)")
            })
        } catch let failure as RegistrationFailure {
            error = "\(shortcut?.label ?? "Shortcut") could not be registered (status \(failure.status)). It may be in use by another app. The previous shortcut remains active."
        } catch ShortcutTransactionError.rollbackFailed {
            error = "The shortcut change and cleanup failed. The previous configuration is preserved; restart the app before editing shortcuts again."
        } catch {
            self.error = "The previous shortcut could not be removed. Its configuration has been preserved."
        }
    }
}

private struct RegistrationFailure: Error { let status: OSStatus }
private struct RemovalFailure: Error { let status: OSStatus }
