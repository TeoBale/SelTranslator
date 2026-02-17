import Foundation

final class TranslationLanguageStore {
    private enum Keys {
        static let targetLanguageID = "target_language_id"
    }

    let availableLanguages: [TranslationLanguage]
    private let defaults: UserDefaults

    init(
        availableLanguages: [TranslationLanguage] = TranslationLanguage.all,
        defaults: UserDefaults = .standard
    ) {
        self.availableLanguages = availableLanguages
        self.defaults = defaults
    }

    var selectedLanguage: TranslationLanguage {
        get {
            guard
                let storedID = defaults.string(forKey: Keys.targetLanguageID),
                let language = availableLanguages.first(where: { $0.id == storedID })
            else {
                return TranslationLanguage.fallback
            }
            return language
        }
        set {
            defaults.set(newValue.id, forKey: Keys.targetLanguageID)
        }
    }
}
