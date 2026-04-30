// Bridges the core translations types into the main executable module via a small alias layer.
// This allows the existing SelTranslator executable code to reference core types
// without scattering module imports across files.

#if canImport(SelTranslatorCore)
import SelTranslatorCore

// Public aliases for the rest of the executable to use
typealias TranslationLanguage = SelTranslatorCore.TranslationLanguage
typealias TranslationLanguageStore = SelTranslatorCore.TranslationLanguageStore
#endif
