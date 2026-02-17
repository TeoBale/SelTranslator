import Foundation

final class HotKeyStore {
    private enum Keys {
        static let keyCode = "hotkey_key_code"
        static let modifiers = "hotkey_modifiers"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hotKey: HotKeyConfiguration {
        get {
            guard
                defaults.object(forKey: Keys.keyCode) != nil,
                defaults.object(forKey: Keys.modifiers) != nil
            else {
                return .default
            }
            let keyCode = UInt32(defaults.integer(forKey: Keys.keyCode))
            let modifiers = UInt32(defaults.integer(forKey: Keys.modifiers))
            return HotKeyConfiguration(keyCode: keyCode, modifiers: modifiers)
        }
        set {
            defaults.set(Int(newValue.keyCode), forKey: Keys.keyCode)
            defaults.set(Int(newValue.modifiers), forKey: Keys.modifiers)
        }
    }
}
