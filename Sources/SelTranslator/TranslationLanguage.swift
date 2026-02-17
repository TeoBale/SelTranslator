import Foundation

struct TranslationLanguage: Equatable, Hashable {
    let id: String
    let displayName: String

    var localeLanguage: Locale.Language {
        Locale.Language(identifier: id)
    }
}

extension TranslationLanguage {
    static let all: [TranslationLanguage] = [
        .init(id: "ar", displayName: "Arabic"),
        .init(id: "zh-Hans", displayName: "Chinese (Simplified)"),
        .init(id: "zh-Hant", displayName: "Chinese (Traditional)"),
        .init(id: "nl", displayName: "Dutch"),
        .init(id: "en", displayName: "English"),
        .init(id: "fr", displayName: "French"),
        .init(id: "de", displayName: "German"),
        .init(id: "hi", displayName: "Hindi"),
        .init(id: "id", displayName: "Indonesian"),
        .init(id: "it", displayName: "Italian"),
        .init(id: "ja", displayName: "Japanese"),
        .init(id: "ko", displayName: "Korean"),
        .init(id: "pl", displayName: "Polish"),
        .init(id: "pt", displayName: "Portuguese"),
        .init(id: "ru", displayName: "Russian"),
        .init(id: "es", displayName: "Spanish"),
        .init(id: "th", displayName: "Thai"),
        .init(id: "tr", displayName: "Turkish"),
        .init(id: "uk", displayName: "Ukrainian"),
        .init(id: "vi", displayName: "Vietnamese")
    ]

    static let fallback = TranslationLanguage(id: "en", displayName: "English")
}
