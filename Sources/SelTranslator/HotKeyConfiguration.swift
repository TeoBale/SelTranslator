import Carbon
import Foundation

struct HotKeyOption: Identifiable, Hashable {
    let keyCode: UInt32
    let label: String

    var id: UInt32 { keyCode }
}

struct HotKeyConfiguration: Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let `default` = HotKeyConfiguration(
        keyCode: UInt32(kVK_ANSI_T),
        modifiers: UInt32(controlKey | optionKey | cmdKey)
    )

    static let keyOptions: [HotKeyOption] = [
        .init(keyCode: UInt32(kVK_ANSI_A), label: "A"),
        .init(keyCode: UInt32(kVK_ANSI_B), label: "B"),
        .init(keyCode: UInt32(kVK_ANSI_C), label: "C"),
        .init(keyCode: UInt32(kVK_ANSI_D), label: "D"),
        .init(keyCode: UInt32(kVK_ANSI_E), label: "E"),
        .init(keyCode: UInt32(kVK_ANSI_F), label: "F"),
        .init(keyCode: UInt32(kVK_ANSI_G), label: "G"),
        .init(keyCode: UInt32(kVK_ANSI_H), label: "H"),
        .init(keyCode: UInt32(kVK_ANSI_I), label: "I"),
        .init(keyCode: UInt32(kVK_ANSI_J), label: "J"),
        .init(keyCode: UInt32(kVK_ANSI_K), label: "K"),
        .init(keyCode: UInt32(kVK_ANSI_L), label: "L"),
        .init(keyCode: UInt32(kVK_ANSI_M), label: "M"),
        .init(keyCode: UInt32(kVK_ANSI_N), label: "N"),
        .init(keyCode: UInt32(kVK_ANSI_O), label: "O"),
        .init(keyCode: UInt32(kVK_ANSI_P), label: "P"),
        .init(keyCode: UInt32(kVK_ANSI_Q), label: "Q"),
        .init(keyCode: UInt32(kVK_ANSI_R), label: "R"),
        .init(keyCode: UInt32(kVK_ANSI_S), label: "S"),
        .init(keyCode: UInt32(kVK_ANSI_T), label: "T"),
        .init(keyCode: UInt32(kVK_ANSI_U), label: "U"),
        .init(keyCode: UInt32(kVK_ANSI_V), label: "V"),
        .init(keyCode: UInt32(kVK_ANSI_W), label: "W"),
        .init(keyCode: UInt32(kVK_ANSI_X), label: "X"),
        .init(keyCode: UInt32(kVK_ANSI_Y), label: "Y"),
        .init(keyCode: UInt32(kVK_ANSI_Z), label: "Z"),
        .init(keyCode: UInt32(kVK_ANSI_0), label: "0"),
        .init(keyCode: UInt32(kVK_ANSI_1), label: "1"),
        .init(keyCode: UInt32(kVK_ANSI_2), label: "2"),
        .init(keyCode: UInt32(kVK_ANSI_3), label: "3"),
        .init(keyCode: UInt32(kVK_ANSI_4), label: "4"),
        .init(keyCode: UInt32(kVK_ANSI_5), label: "5"),
        .init(keyCode: UInt32(kVK_ANSI_6), label: "6"),
        .init(keyCode: UInt32(kVK_ANSI_7), label: "7"),
        .init(keyCode: UInt32(kVK_ANSI_8), label: "8"),
        .init(keyCode: UInt32(kVK_ANSI_9), label: "9")
    ]

    var isCommandEnabled: Bool {
        modifiers & UInt32(cmdKey) != 0
    }

    var isOptionEnabled: Bool {
        modifiers & UInt32(optionKey) != 0
    }

    var isControlEnabled: Bool {
        modifiers & UInt32(controlKey) != 0
    }

    var isShiftEnabled: Bool {
        modifiers & UInt32(shiftKey) != 0
    }

    func with(command: Bool, option: Bool, control: Bool, shift: Bool) -> HotKeyConfiguration {
        var newModifiers: UInt32 = 0
        if command { newModifiers |= UInt32(cmdKey) }
        if option { newModifiers |= UInt32(optionKey) }
        if control { newModifiers |= UInt32(controlKey) }
        if shift { newModifiers |= UInt32(shiftKey) }
        return HotKeyConfiguration(keyCode: keyCode, modifiers: newModifiers)
    }

    var displayString: String {
        var parts: [String] = []
        if isControlEnabled { parts.append("Control") }
        if isOptionEnabled { parts.append("Option") }
        if isShiftEnabled { parts.append("Shift") }
        if isCommandEnabled { parts.append("Command") }
        let keyLabel = HotKeyConfiguration.keyOptions.first(where: { $0.keyCode == keyCode })?.label ?? "KeyCode\(keyCode)"
        parts.append(keyLabel)
        return parts.joined(separator: "+")
    }
}
