import Foundation
import NaturalLanguage
import Translation

enum TranslationServiceError: LocalizedError {
    case emptyInput
    case unableToIdentifyLanguage
    case unsupportedSystem
    case unsupportedLanguagePair(source: String, target: String)
    case languageModelsMissing(
        source: String,
        target: String,
        sourceLanguage: Locale.Language,
        targetLanguage: Locale.Language
    )

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "No text selected."
        case .unableToIdentifyLanguage:
            return "Unable to identify source language."
        case .unsupportedSystem:
            return "Translation requires a newer macOS version."
        case .unsupportedLanguagePair(let source, let target):
            return "Unsupported translation pair: \(source) -> \(target)."
        case .languageModelsMissing(let source, let target, _, _):
            return "Missing Apple translation models for \(source) -> \(target). Install in System Settings > General > Language & Region > Translation Languages."
        }
    }
}

actor TranslationService {
    func translate(_ text: String, targetLanguage: Locale.Language) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TranslationServiceError.emptyInput
        }

        let sourceLanguage = try detectSourceLanguage(in: trimmed)
        if sourceLanguage == targetLanguage {
            return trimmed
        }

        if #available(macOS 26.0, *) {
            let availability = LanguageAvailability()
            let status = await availability.status(from: sourceLanguage, to: targetLanguage)
            switch status {
            case .installed:
                break
            case .supported:
                throw TranslationServiceError.languageModelsMissing(
                    source: localizedLanguageName(for: sourceLanguage),
                    target: localizedLanguageName(for: targetLanguage),
                    sourceLanguage: sourceLanguage,
                    targetLanguage: targetLanguage
                )
            case .unsupported:
                throw TranslationServiceError.unsupportedLanguagePair(
                    source: localizedLanguageName(for: sourceLanguage),
                    target: localizedLanguageName(for: targetLanguage)
                )
            @unknown default:
                break
            }

            let session = TranslationSession(
                installedSource: sourceLanguage,
                target: targetLanguage
            )

            do {
                try await session.prepareTranslation()
                let response = try await session.translate(trimmed)
                return response.targetText
            } catch let translationError as TranslationError {
                switch translationError {
                case .notInstalled:
                    throw TranslationServiceError.languageModelsMissing(
                        source: localizedLanguageName(for: sourceLanguage),
                        target: localizedLanguageName(for: targetLanguage),
                        sourceLanguage: sourceLanguage,
                        targetLanguage: targetLanguage
                    )
                default:
                    throw translationError
                }
            }
        } else {
            throw TranslationServiceError.unsupportedSystem
        }
    }

    private func detectSourceLanguage(in text: String) throws -> Locale.Language {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage else {
            throw TranslationServiceError.unableToIdentifyLanguage
        }
        return Locale.Language(identifier: language.rawValue)
    }

    private func localizedLanguageName(for language: Locale.Language) -> String {
        let identifier = language.minimalIdentifier
        return Locale.current.localizedString(forIdentifier: identifier) ?? identifier
    }
}
