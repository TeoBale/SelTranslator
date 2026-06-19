import Foundation
import NaturalLanguage
@preconcurrency import Translation

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
    private enum Keys {
        static let confirmedInstalledPairs = "confirmed_installed_pairs"
    }

    private let defaults: UserDefaults
    private var confirmedInstalledPairs: Set<String>

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedPairs = defaults.array(forKey: Keys.confirmedInstalledPairs) as? [String] ?? []
        self.confirmedInstalledPairs = Set(storedPairs)
    }

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
            let initialStatus = await availability.status(from: sourceLanguage, to: targetLanguage)
            Diagnostics.info(
                "Translation availability status=\(describe(initialStatus)) from=\(sourceLanguage.minimalIdentifier) to=\(targetLanguage.minimalIdentifier)"
            )

            switch initialStatus {
            case .installed, .supported:
                break
            case .unsupported:
                throw TranslationServiceError.unsupportedLanguagePair(
                    source: localizedLanguageName(for: sourceLanguage),
                    target: localizedLanguageName(for: targetLanguage)
                )
            @unknown default:
                break
            }

            do {
                let translated = try await translateUsingSessionWithRetry(
                    text: trimmed,
                    sourceLanguage: sourceLanguage,
                    targetLanguage: targetLanguage
                )
                rememberInstalledPair(sourceLanguage, targetLanguage)
                return translated
            } catch let error {
                // On macOS CI (and newer translations frameworks) notInstalled may not exist.
                // Just rethrow to let outer handlers deal with the generic failure.
                throw error
            }
        } else {
            throw TranslationServiceError.unsupportedSystem
        }
    }

    @available(macOS 26.0, *)
    private func translateUsingSession(
        text: String,
        sourceLanguage: Locale.Language,
        targetLanguage: Locale.Language
    ) async throws -> String {
        let session = TranslationSession(
            installedSource: sourceLanguage,
            target: targetLanguage
        )
        try await session.prepareTranslation()
        let response = try await session.translate(text)
        return response.targetText
    }

    @available(macOS 26.0, *)
    private func translateUsingSessionWithRetry(
        text: String,
        sourceLanguage: Locale.Language,
        targetLanguage: Locale.Language,
        maxAttempts: Int = 3
    ) async throws -> String {
        var attempt = 1
        while true {
            do {
                return try await translateUsingSession(
                    text: text,
                    sourceLanguage: sourceLanguage,
                    targetLanguage: targetLanguage
                )
        } catch let error {
            // If TranslationError provides specific cases in some environments, we would handle them there.
            // Otherwise, propagate the error to fail gracefully.
            throw error
        }
        }
    }

    @available(macOS 26.0, *)
    private func recoverFromNotInstalled(
        text: String,
        sourceLanguage: Locale.Language,
        targetLanguage: Locale.Language
    ) async throws -> String {
        let availability = LanguageAvailability()
        let refreshedStatus = await availability.status(from: sourceLanguage, to: targetLanguage)
        Diagnostics.info(
            "Translation returned notInstalled; refreshed availability status=\(describe(refreshedStatus)) from=\(sourceLanguage.minimalIdentifier) to=\(targetLanguage.minimalIdentifier)"
        )

        let normalizedSource = normalize(sourceLanguage)
        let normalizedTarget = normalize(targetLanguage)
        let hasNormalizedVariant =
            normalizedSource.minimalIdentifier != sourceLanguage.minimalIdentifier ||
            normalizedTarget.minimalIdentifier != targetLanguage.minimalIdentifier

        if let installedVariantPair = await findInstalledVariantPair(
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        ) {
            let (variantSource, variantTarget) = installedVariantPair
            Diagnostics.info(
                "Found installed variant pair from=\(variantSource.minimalIdentifier) to=\(variantTarget.minimalIdentifier)"
            )
            do {
                let translated = try await translateUsingSessionWithRetry(
                    text: text,
                    sourceLanguage: variantSource,
                    targetLanguage: variantTarget
                )
                rememberInstalledPair(sourceLanguage, targetLanguage)
                rememberInstalledPair(variantSource, variantTarget)
                return translated
            } catch {
                Diagnostics.error(
                    "Retry with installed variant pair failed: \(Diagnostics.describe(error))"
                )
            }
        }

        switch refreshedStatus {
        case .unsupported:
            throw TranslationServiceError.unsupportedLanguagePair(
                source: localizedLanguageName(for: sourceLanguage),
                target: localizedLanguageName(for: targetLanguage)
            )
        case .installed:
            var installedRetryError: Error?
            do {
                let translated = try await translateUsingSessionWithRetry(
                    text: text,
                    sourceLanguage: sourceLanguage,
                    targetLanguage: targetLanguage
                )
                rememberInstalledPair(sourceLanguage, targetLanguage)
                return translated
            } catch {
                installedRetryError = error
                Diagnostics.error(
                    "Retry with installedSource failed after installed status: \(Diagnostics.describe(error))"
                )
            }

            if hasNormalizedVariant {
                do {
                    Diagnostics.info(
                        "Retrying translation with normalized identifiers from=\(normalizedSource.minimalIdentifier) to=\(normalizedTarget.minimalIdentifier)"
                    )
                    let translated = try await translateUsingSessionWithRetry(
                        text: text,
                        sourceLanguage: normalizedSource,
                        targetLanguage: normalizedTarget
                    )
                    rememberInstalledPair(sourceLanguage, targetLanguage)
                    rememberInstalledPair(normalizedSource, normalizedTarget)
                    return translated
                } catch {
                    Diagnostics.error(
                        "Retry with normalized identifiers failed after installed status: \(Diagnostics.describe(error))"
                    )
                }
            }

            if let installedRetryError {
                throw installedRetryError
            }
            throw TranslationServiceError.languageModelsMissing(
                source: localizedLanguageName(for: sourceLanguage),
                target: localizedLanguageName(for: targetLanguage),
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
        case .supported:
            guard hasNormalizedVariant else {
                if isKnownInstalledPair(sourceLanguage, targetLanguage) {
                    Diagnostics.info(
                        "Suppressing languageModelsMissing for previously successful pair from=\(sourceLanguage.minimalIdentifier) to=\(targetLanguage.minimalIdentifier)"
                    )
                    throw TranslationServiceError.languageModelsMissing(
                        source: localizedLanguageName(for: sourceLanguage),
                        target: localizedLanguageName(for: targetLanguage),
                        sourceLanguage: sourceLanguage,
                        targetLanguage: targetLanguage
                    )
                }
                throw TranslationServiceError.languageModelsMissing(
                    source: localizedLanguageName(for: sourceLanguage),
                    target: localizedLanguageName(for: targetLanguage),
                    sourceLanguage: sourceLanguage,
                    targetLanguage: targetLanguage
                )
            }

            do {
                Diagnostics.info(
                    "Retrying translation with normalized identifiers from=\(normalizedSource.minimalIdentifier) to=\(normalizedTarget.minimalIdentifier)"
                )
                let translated = try await translateUsingSessionWithRetry(
                    text: text,
                    sourceLanguage: normalizedSource,
                    targetLanguage: normalizedTarget
                )
                rememberInstalledPair(sourceLanguage, targetLanguage)
                rememberInstalledPair(normalizedSource, normalizedTarget)
                return translated
            } catch {
                // Propagate error as a generic failure; specific TranslationError cases are not relied upon here.
                throw error
            }
        @unknown default:
            break
        }

        if isKnownInstalledPair(sourceLanguage, targetLanguage) {
            Diagnostics.info(
                "Suppressing fallback languageModelsMissing for previously successful pair from=\(sourceLanguage.minimalIdentifier) to=\(targetLanguage.minimalIdentifier)"
            )
            throw TranslationServiceError.languageModelsMissing(
                source: localizedLanguageName(for: sourceLanguage),
                target: localizedLanguageName(for: targetLanguage),
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
        }
        throw TranslationServiceError.languageModelsMissing(
            source: localizedLanguageName(for: sourceLanguage),
            target: localizedLanguageName(for: targetLanguage),
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )
    }

    @available(macOS 26.0, *)
    private func describe(_ status: LanguageAvailability.Status) -> String {
        switch status {
        case .installed:
            return "installed"
        case .supported:
            return "supported"
        case .unsupported:
            return "unsupported"
        @unknown default:
            return "unknown"
        }
    }

    private func normalize(_ language: Locale.Language) -> Locale.Language {
        Locale.Language(identifier: language.minimalIdentifier)
    }

    @available(macOS 26.0, *)
    private func findInstalledVariantPair(
        sourceLanguage: Locale.Language,
        targetLanguage: Locale.Language
    ) async -> (Locale.Language, Locale.Language)? {
        let availability = LanguageAvailability()
        let supportedLanguages = await availability.supportedLanguages
        let sourceCandidates = candidateLanguages(for: sourceLanguage, supportedLanguages: supportedLanguages)
        let targetCandidates = candidateLanguages(for: targetLanguage, supportedLanguages: supportedLanguages)

        for sourceCandidate in sourceCandidates {
            for targetCandidate in targetCandidates {
                let status = await availability.status(from: sourceCandidate, to: targetCandidate)
                if status == .installed {
                    return (sourceCandidate, targetCandidate)
                }
            }
        }

        return nil
    }

    private func candidateLanguages(
        for language: Locale.Language,
        supportedLanguages: [Locale.Language]
    ) -> [Locale.Language] {
        let normalized = normalize(language)
        let base = baseIdentifier(for: normalized)
        var seen = Set<String>()
        var candidates: [Locale.Language] = []

        func appendIfNeeded(_ candidate: Locale.Language) {
            let key = candidate.minimalIdentifier
            if seen.insert(key).inserted {
                candidates.append(candidate)
            }
        }

        appendIfNeeded(normalized)
        appendIfNeeded(language)

        for supported in supportedLanguages where baseIdentifier(for: supported) == base {
            appendIfNeeded(supported)
        }

        return candidates
    }

    private func baseIdentifier(for language: Locale.Language) -> String {
        language.minimalIdentifier.split(separator: "-").first.map(String.init) ?? language.minimalIdentifier
    }

    private func rememberInstalledPair(_ sourceLanguage: Locale.Language, _ targetLanguage: Locale.Language) {
        let directKey = pairKey(sourceLanguage, targetLanguage)
        let normalizedKey = pairKey(normalize(sourceLanguage), normalize(targetLanguage))
        let insertedDirect = confirmedInstalledPairs.insert(directKey).inserted
        let insertedNormalized = confirmedInstalledPairs.insert(normalizedKey).inserted
        if insertedDirect || insertedNormalized {
            defaults.set(Array(confirmedInstalledPairs).sorted(), forKey: Keys.confirmedInstalledPairs)
            Diagnostics.info("Remembered successful installed pair(s): \(directKey), \(normalizedKey)")
        }
    }

    private func isKnownInstalledPair(_ sourceLanguage: Locale.Language, _ targetLanguage: Locale.Language) -> Bool {
        let directKey = pairKey(sourceLanguage, targetLanguage)
        let normalizedKey = pairKey(normalize(sourceLanguage), normalize(targetLanguage))
        return confirmedInstalledPairs.contains(directKey) || confirmedInstalledPairs.contains(normalizedKey)
    }

    private func pairKey(_ sourceLanguage: Locale.Language, _ targetLanguage: Locale.Language) -> String {
        "\(sourceLanguage.minimalIdentifier)->\(targetLanguage.minimalIdentifier)"
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
