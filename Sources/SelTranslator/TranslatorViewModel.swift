import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class TranslatorViewModel {
    var sourceText: String = ""
    var translatedText: String = ""
    var selectedSourceLanguageID: String
    var selectedTargetLanguageID: String
    var detectedSourceLabel: String?
    var errorMessage: String?
    var isTranslating = false
    var isPresented = false
    var focusToken = UUID()

    private let languageStore: TranslationLanguageStore
    private let translationService: TranslationService
    private var translationTask: Task<Void, Never>?
    private var translationGeneration = 0
    private var restorableDraft: DraftSnapshot?
    private var selectionSeed: String?

    init(languageStore: TranslationLanguageStore, translationService: TranslationService) {
        self.languageStore = languageStore
        self.translationService = translationService
        self.selectedSourceLanguageID = languageStore.defaultSourceLanguageID
        self.selectedTargetLanguageID = languageStore.defaultTargetLanguageID
    }

    var availableLanguages: [TranslationLanguage] {
        languageStore.availableLanguages
    }

    var canSwapLanguages: Bool {
        selectedSourceLanguageID != TranslationLanguage.autoDetectID
    }

    func reloadSettings() {
        guard sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        selectedSourceLanguageID = languageStore.defaultSourceLanguageID
        selectedTargetLanguageID = languageStore.defaultTargetLanguageID
    }

    func prepareForPresentation(prefillText: String?) {
        let normalizedPrefill = normalize(prefillText)

        if let draft = draftToRestore(for: normalizedPrefill) {
            apply(draft: draft)
        } else {
            startFresh(prefillText: normalizedPrefill)
        }

        isPresented = true
        focusToken = UUID()

        if translatedText.isEmpty, !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            scheduleTranslation(immediate: true)
        }
    }

    func prepareForDismiss(reason: TranslatorDismissReason) {
        translationTask?.cancel()
        translationTask = nil
        isTranslating = false
        isPresented = false

        switch reason {
        case .outsideClick:
            saveDraftIfNeeded()
        case .escape:
            restorableDraft = nil
        }
    }

    func sourceTextDidChange() {
        errorMessage = nil
        scheduleTranslation()
    }

    func sourceLanguageDidChange() {
        detectedSourceLabel = nil
        errorMessage = nil
        scheduleTranslation(immediate: true)
    }

    func targetLanguageDidChange() {
        errorMessage = nil
        scheduleTranslation(immediate: true)
    }

    func swapLanguages() {
        guard canSwapLanguages else { return }
        let previousSource = selectedSourceLanguageID
        selectedSourceLanguageID = selectedTargetLanguageID
        selectedTargetLanguageID = previousSource
        detectedSourceLabel = nil
        errorMessage = nil
        scheduleTranslation(immediate: true)
    }

    func clearSourceText() {
        sourceText = ""
        translatedText = ""
        detectedSourceLabel = nil
        errorMessage = nil
        translationTask?.cancel()
        translationTask = nil
        focusToken = UUID()
    }

    func copyTranslation() {
        guard !translatedText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(translatedText, forType: .string)
    }

    private func scheduleTranslation(immediate: Bool = false) {
        translationTask?.cancel()

        let trimmedSource = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSource.isEmpty else {
            translatedText = ""
            detectedSourceLabel = nil
            errorMessage = nil
            isTranslating = false
            return
        }

        translationGeneration += 1
        let generation = translationGeneration
        let sourceID = selectedSourceLanguageID
        let targetID = selectedTargetLanguageID
        let sourceText = self.sourceText
        let delay = immediate ? UInt64(0) : 320_000_000

        translationTask = Task { [weak self] in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            guard !Task.isCancelled else { return }
            await self?.runTranslation(
                generation: generation,
                sourceText: sourceText,
                sourceID: sourceID,
                targetID: targetID
            )
        }
    }

    private func runTranslation(
        generation: Int,
        sourceText: String,
        sourceID: String,
        targetID: String
    ) async {
        guard generation == translationGeneration else { return }
        guard let targetLanguage = languageStore.language(for: targetID) else { return }

        let sourceLanguage = sourceID == TranslationLanguage.autoDetectID ? nil : languageStore.language(for: sourceID)
        isTranslating = true
        errorMessage = nil

        do {
            let result = try await translationService.translate(
                sourceText,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
            guard generation == translationGeneration else { return }
            translatedText = result.translatedText
            detectedSourceLabel = sourceID == TranslationLanguage.autoDetectID ? result.sourceLanguageDisplayName : nil
            errorMessage = nil
        } catch {
            guard generation == translationGeneration else { return }
            translatedText = ""
            detectedSourceLabel = nil
            errorMessage = error.localizedDescription
            Diagnostics.error("Popup translation failed: \(Diagnostics.describe(error))")
        }

        isTranslating = false
    }

    private func startFresh(prefillText: String?) {
        selectedSourceLanguageID = languageStore.defaultSourceLanguageID
        selectedTargetLanguageID = languageStore.defaultTargetLanguageID
        sourceText = prefillText ?? ""
        translatedText = ""
        detectedSourceLabel = nil
        errorMessage = nil
        selectionSeed = prefillText
    }

    private func saveDraftIfNeeded() {
        guard !sourceText.isEmpty || !translatedText.isEmpty else {
            restorableDraft = nil
            return
        }

        restorableDraft = DraftSnapshot(
            sourceText: sourceText,
            translatedText: translatedText,
            selectedSourceLanguageID: selectedSourceLanguageID,
            selectedTargetLanguageID: selectedTargetLanguageID,
            detectedSourceLabel: detectedSourceLabel,
            errorMessage: errorMessage,
            selectionSeed: selectionSeed,
            savedAt: Date()
        )
    }

    private func draftToRestore(for _: String?) -> DraftSnapshot? {
        guard let draft = restorableDraft else {
            return nil
        }

        let age = Date().timeIntervalSince(draft.savedAt)
        guard age <= Double(languageStore.draftRestoreTimeout.rawValue) else {
            restorableDraft = nil
            return nil
        }

        return draft
    }

    private func apply(draft: DraftSnapshot) {
        selectedSourceLanguageID = draft.selectedSourceLanguageID
        selectedTargetLanguageID = draft.selectedTargetLanguageID
        sourceText = draft.sourceText
        translatedText = draft.translatedText
        detectedSourceLabel = draft.detectedSourceLabel
        errorMessage = draft.errorMessage
        selectionSeed = draft.selectionSeed
    }

    private func normalize(_ text: String?) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct DraftSnapshot {
    let sourceText: String
    let translatedText: String
    let selectedSourceLanguageID: String
    let selectedTargetLanguageID: String
    let detectedSourceLabel: String?
    let errorMessage: String?
    let selectionSeed: String?
    let savedAt: Date
}

enum TranslatorDismissReason {
    case outsideClick
    case escape
}
