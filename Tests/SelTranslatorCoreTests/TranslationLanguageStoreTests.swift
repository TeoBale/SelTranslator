import XCTest
@testable import SelTranslatorCore

final class TranslationLanguageStoreTests: XCTestCase {
    func testSelectedLanguageFallsBackWhenNotStored() {
        let defaults = UserDefaults(suiteName: "SelTranslatorCoreTests-Defaults-NotStored")!
        defaults.removePersistentDomain(forName: "SelTranslatorCoreTests-Defaults-NotStored")
        let langEn = TranslationLanguage(id: "en", displayName: "English")
        let langFr = TranslationLanguage(id: "fr", displayName: "French")
        let store = TranslationLanguageStore(availableLanguages: [langEn, langFr], defaults: defaults)

        XCTAssertEqual(store.selectedLanguage, TranslationLanguage.fallback)
    }

    func testSelectedLanguageReadsExistingMatch() {
        let defaults = UserDefaults(suiteName: "SelTranslatorCoreTests-Defaults-ExistingMatch")!
        defaults.removePersistentDomain(forName: "SelTranslatorCoreTests-Defaults-ExistingMatch")
        let langEn = TranslationLanguage(id: "en", displayName: "English")
        let langFr = TranslationLanguage(id: "fr", displayName: "French")
        let store = TranslationLanguageStore(availableLanguages: [langEn, langFr], defaults: defaults)

        defaults.set("fr", forKey: "target_language_id")

        // The stored id matches an available language; should return that language.
        XCTAssertEqual(store.selectedLanguage, langFr)
    }

    func testSelectedLanguageFallsBackWhenStoredNotInAvailable() {
        let defaults = UserDefaults(suiteName: "SelTranslatorCoreTests-Defaults-FallbackOnMissing")!
        defaults.removePersistentDomain(forName: "SelTranslatorCoreTests-Defaults-FallbackOnMissing")
        let langEn = TranslationLanguage(id: "en", displayName: "English")
        let langFr = TranslationLanguage(id: "fr", displayName: "French")
        let store = TranslationLanguageStore(availableLanguages: [langEn, langFr], defaults: defaults)

        defaults.set("es", forKey: "target_language_id")

        // Stored id isn't in available languages; should fallback.
        XCTAssertEqual(store.selectedLanguage, TranslationLanguage.fallback)
    }
}

// Linux test discovery compatibility. Not strictly necessary in macOS but harmless.
extension TranslationLanguageStoreTests {
    static var allTests = [
        ("testSelectedLanguageFallsBackWhenNotStored", testSelectedLanguageFallsBackWhenNotStored),
        ("testSelectedLanguageReadsExistingMatch", testSelectedLanguageReadsExistingMatch),
        ("testSelectedLanguageFallsBackWhenStoredNotInAvailable", testSelectedLanguageFallsBackWhenStoredNotInAvailable),
    ]
}
