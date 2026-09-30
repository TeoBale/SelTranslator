import AppKit
import ApplicationServices
import Observation
import SwiftUI
import Translation
import TranslationCore

@MainActor final class SystemClipboard: ClipboardAccess {
    func readText() -> String? { NSPasteboard.general.string(forType: .string) }
    func writeText(_ text: String) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string) }
}

struct LanguageChoice: Identifiable, Hashable, Sendable {
    let id: String
    var name: String { Locale.current.localizedString(forIdentifier: id) ?? id }
}

@MainActor @Observable
final class AppModel {
    let workflow: WorkflowCoordinator
    let hotkeys = Hotkeys()
    var languages: [LanguageChoice] = []
    var target: String { didSet { UserDefaults.standard.set(target, forKey: "target") } }
    var source: String { didSet { UserDefaults.standard.set(source, forKey: "source") } }
    var accessibilityGranted = AXIsProcessTrusted()
    var setupPair: LanguagePair?
    var setupMessage = "Choose a source and target language, then prepare the models. Downloads may require internet access. Translation runs on device."
    var setupGeneration = UUID()
    var setupConfiguration: TranslationSession.Configuration?
    var setupReady = false
    var setupRunning = false
    var onStateChange: ((WorkflowState) -> Void)?
    var openSettings: (() -> Void)?
    var openSetup: (() -> Void)?

    init() {
        target = UserDefaults.standard.string(forKey: "target") ?? "en"
        source = UserDefaults.standard.string(forKey: "source") ?? ""
        workflow = WorkflowCoordinator(selection: AXSelectionAccess(), engine: AppleTranslationEngine(), clipboard: SystemClipboard())
        hotkeys.onCommand = { [weak self] command in self?.run(command == 1 ? .replace : command == 2 ? .clipboard : .selection) }
        workflow.onMilestone = { id, event in
            if event == "shortcut_received" { Diagnostics.shared.begin(id) }
            else { Diagnostics.shared.mark(id, event) }
        }
        workflow.onStateChange = { [weak self] state in
            if case let .translating(request) = state { Diagnostics.shared.mark(request.id, "input_ready", length: request.text.utf16.count) }
            self?.onStateChange?(state)
        }
        Task {
            let available = await supportedLanguageIdentifiers()
            languages = available.map { LanguageChoice(id: $0) }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    func run(_ mode: DeliveryMode) { workflow.start(mode: mode, source: source.isEmpty ? nil : source, target: target) }
    func refreshPermission() { accessibilityGranted = AXIsProcessTrusted() }
    func requestPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        accessibilityGranted = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    func prepare(_ pair: LanguagePair) {
        setupConfiguration = nil
        setupReady = false
        setupRunning = false
        setupPair = pair
        setupGeneration = UUID()
        setupReady = pair.source == pair.target
        setupMessage = setupReady ? "Source and target are the same language. No translation models are needed." : "Ready to prepare this language pair."
        openSetup?()
    }
    func prepareCurrent() {
        guard !source.isEmpty else { setupPair = nil; setupConfiguration = nil; setupGeneration = UUID(); setupReady = false; setupRunning = false; setupMessage = "Choose an explicit source language in Settings before preparing a pair."; openSetup?(); return }
        prepare(.init(source: source, target: target))
    }
}

// Factory is nonisolated: the SwiftUI-provided, non-Sendable session stays local to
// its async action. Only the MainActor model reference crosses isolation boundaries.
nonisolated func modelPreparationAction(model: AppModel, generation: UUID) -> (TranslationSession) async -> Void {
    return { session in
        let outcome: String
        var ready = false
        do {
            try Task.checkCancellation()
            try await session.prepareTranslation()
            try Task.checkCancellation()
            ready = true
            outcome = "Models are ready now. Availability will be checked again on each request."
        } catch {
            outcome = Task.isCancelled ? "Model setup cancelled. You can try again." : "Model setup did not complete. Check your internet connection and available disk space, then try again."
        }
        await model.finishSetup(generation: generation, ready: ready, message: outcome)
    }
}
extension AppModel {
    func finishSetup(generation: UUID, ready: Bool, message: String) {
        guard generation == setupGeneration else { return }
        setupReady = ready; setupRunning = false; setupMessage = message
        setupConfiguration = nil
    }
}

nonisolated func supportedLanguageIdentifiers() async -> [String] {
    let availability = LanguageAvailability()
    return await availability.supportedLanguages.map(\.minimalIdentifier)
}
