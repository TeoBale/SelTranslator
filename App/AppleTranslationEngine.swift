import Foundation
import NaturalLanguage
import Translation
import TranslationCore

/// Fresh installed-pair sessions form the baseline. No model-readiness success is cached.
@MainActor
final class AppleTranslationEngine: TranslationEngine {
    func translate(text: String, source: String?, target: String, requestID: UUID) async throws -> TranslationOutput {
        try Task.checkCancellation()
        let detected: String
        if let source { detected = source }
        else {
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(text)
            let candidates = recognizer.languageHypotheses(withMaximum: 2).sorted { $0.value > $1.value }
            guard let best = candidates.first, best.value >= 0.65,
                  candidates.count < 2 || best.value - candidates[1].value >= 0.20 else { throw TranslationIssue.uncertainSource }
            detected = best.key.rawValue
        }
        Diagnostics.shared.mark(requestID, "source_detected", length: text.utf16.count)
        let from = Locale.Language(identifier: detected)
        let to = Locale.Language(identifier: target)
        // maximalIdentifier retains script distinctions (e.g. zh-Hans vs zh-Hant).
        if from.maximalIdentifier == to.maximalIdentifier {
            return TranslationOutput(text: text, source: target, target: target)
        }
        let pair = LanguagePair(source: detected, target: target)
        let availability = LanguageAvailability()
        let status = await availability.status(from: from, to: to)
        try Task.checkCancellation()
        Diagnostics.shared.mark(requestID, "availability_checked", length: text.utf16.count)
        switch status {
        case .unsupported: throw TranslationIssue.unsupportedPair(pair)
        case .supported: throw TranslationIssue.missingModels(pair)
        case .installed: break
        @unknown default: throw TranslationIssue.failed
        }
        let session = TranslationSession(installedSource: from, target: to)
        // Task-local ownership: the SDK session is not Sendable. Never share it across requests.
        defer { session.cancel() }
        do {
            try Task.checkCancellation()
            try await session.prepareTranslation()
            try Task.checkCancellation()
            Diagnostics.shared.mark(requestID, "session_prepared", length: text.utf16.count)
            let response = try await session.translate(text)
            try Task.checkCancellation()
            Diagnostics.shared.mark(requestID, "translation_completed", length: text.utf16.count)
            return TranslationOutput(text: response.targetText, source: detected, target: target)
        } catch {
            if Task.isCancelled { session.cancel(); throw CancellationError() }
            switch error {
            case TranslationError.alreadyCancelled: throw TranslationIssue.cancelled
            case TranslationError.notInstalled: throw TranslationIssue.missingModels(pair)
            case TranslationError.unableToIdentifyLanguage: throw TranslationIssue.uncertainSource
            case TranslationError.nothingToTranslate: throw TranslationIssue.emptyInput
            case TranslationError.unsupportedSourceLanguage, TranslationError.unsupportedTargetLanguage, TranslationError.unsupportedLanguagePairing:
                throw TranslationIssue.unsupportedPair(pair)
            default: throw TranslationIssue.failed
            }
        }
    }
}
