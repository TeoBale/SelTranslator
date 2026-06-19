#if canImport(XCTest)
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

    func testSelectedLanguageFallsBackWhenNoAvailableLanguages() {
        // When there are no available languages, ensure we still fall back to default
        let defaults = UserDefaults(suiteName: "SelTranslatorCoreTests-Defaults-NoAvailable")!
        defaults.removePersistentDomain(forName: "SelTranslatorCoreTests-Defaults-NoAvailable")
        let store = TranslationLanguageStore(availableLanguages: [], defaults: defaults)

        XCTAssertEqual(store.selectedLanguage, TranslationLanguage.fallback)
    }
}
extension TranslationLanguageStoreTests {
    static var allTests = [
        ("testSelectedLanguageFallsBackWhenNotStored", testSelectedLanguageFallsBackWhenNotStored),
        ("testSelectedLanguageReadsExistingMatch", testSelectedLanguageReadsExistingMatch),
        ("testSelectedLanguageFallsBackWhenStoredNotInAvailable", testSelectedLanguageFallsBackWhenStoredNotInAvailable),
        ("testSelectedLanguageFallsBackWhenNoAvailableLanguages", testSelectedLanguageFallsBackWhenNoAvailableLanguages),
    ]
}
#else
// XCTest not available in this environment; tests are skipped.
#endif
