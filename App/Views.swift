import SwiftUI
import Translation
import TranslationCore

struct LanguagePicker: View {
    let title: String
    @Binding var selection: String
    let languages: [LanguageChoice]
    var automatic = false
    var body: some View {
        Picker(title, selection: $selection) {
            if automatic { Text("Automatic detection").tag("") }
            if !selection.isEmpty && !languages.contains(where: { $0.id == selection }) {
                Text(Locale.current.localizedString(forIdentifier: selection) ?? selection).tag(selection)
            }
            ForEach(languages) { Text($0.name).tag($0.id) }
        }
    }
}

struct ResultView: View {
    @Bindable var model: AppModel
    @State private var correctedSource = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "character.bubble.fill").foregroundStyle(.tint)
                Text("SelectionTranslator").font(.headline)
                Spacer()
                Button("Settings", systemImage: "gearshape") { model.openSettings?() }.labelStyle(.iconOnly)
            }
            switch model.workflow.state {
            case .idle: Text("Select text in another app, then use Translate Selection.").foregroundStyle(.secondary)
            case .capturing: progress("Reading selection…")
            case .translating: progress("Translating on device…")
            case let .awaitingModelSetup(_, pair):
                Text("Language models needed").font(.title3.bold())
                Text("Prepare \(languageName(pair.source)) → \(languageName(pair.target)), then retry this selection.")
                Button("Set Up Models…") { model.prepare(pair) }.buttonStyle(.borderedProminent)
                correction
            case let .failed(_, message):
                ScrollView { Text(message).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }.frame(maxHeight: 170)
                correction
                Button("Accessibility Settings…") { model.openSettings?() }
            case let .showingResult(result):
                Text("\(languageName(result.translation.source)) → \(languageName(result.translation.target))")
                    .font(.subheadline).foregroundStyle(.secondary)
                ScrollView {
                    Text(result.translation.text).font(.body).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                }.frame(minHeight: 110, maxHeight: 300).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                if let message = result.replacementFailure {
                    Text(message).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    Button("Copy", systemImage: "doc.on.doc") { model.workflow.copyResult() }.buttonStyle(.borderedProminent)
                    if result.wasReplaced { Text("Replaced in source app").foregroundStyle(.secondary) }
                    Spacer()
                }
                correction
            }
        }.padding(20).frame(width: 440).frame(minHeight: 220)
    }
    private var correction: some View {
        VStack(alignment: .leading, spacing: 8) {
            LanguagePicker(title: "Correct source", selection: $correctedSource, languages: model.languages, automatic: true)
            Button("Translate Again") { model.workflow.retry(source: correctedSource.isEmpty ? nil : correctedSource, automaticSource: correctedSource.isEmpty) }
            Text("Retrying a replacement still requires the original selection and focus. You can always copy the result explicitly.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
    private func progress(_ title: String) -> some View {
        HStack { ProgressView().controlSize(.small); Text(title); Spacer(); Button("Cancel") { model.workflow.cancel() } }
    }
    private func languageName(_ code: String) -> String { Locale.current.localizedString(forIdentifier: code) ?? code }
}

struct SettingsView: View {
    @Bindable var model: AppModel
    var body: some View {
        Form {
            Section("Languages") {
                LanguagePicker(title: "Translate into", selection: $model.target, languages: model.languages)
                LanguagePicker(title: "Translate from", selection: $model.source, languages: model.languages, automatic: true)
                Text("Short or ambiguous text may require an explicit source. Language choices come from Apple Translation.").font(.caption).foregroundStyle(.secondary)
                Button("Model Readiness and Setup…") { model.prepareCurrent() }
            }
            Section("Global shortcuts") {
                ShortcutRow(title: "Translate Selection", command: 0, hotkeys: model.hotkeys)
                ShortcutRow(title: "Translate and Replace", command: 1, hotkeys: model.hotkeys)
                ShortcutRow(title: "Translate Clipboard", command: 2, hotkeys: model.hotkeys)
                Text("Click Record Shortcut, then press your key combination (for example, ⌃⇧J). Press Esc to cancel. Changes take effect immediately after successful registration.").font(.caption).foregroundStyle(.secondary)
                if let error = model.hotkeys.error { Text(error).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
            }
            Section("Accessibility") {
                Label(model.accessibilityGranted ? "Access granted" : "Access required for selection commands", systemImage: model.accessibilityGranted ? "checkmark.circle" : "lock")
                Text("Enable SelectionTranslator in System Settings → Privacy & Security → Accessibility. After moving or rebuilding the app, remove and re-add its entry if access fails. Clipboard translation does not require Accessibility.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack { Button("Open Accessibility Settings…") { model.requestPermission() }; Button("Refresh") { model.refreshPermission() } }
            }
            Section("Privacy and behavior") {
                Text("Translation stays on this Mac. Model downloads may use the network. No accounts, history, analytics, or cloud translation. Clipboard changes only when you choose Copy. Plain-text replacement may change formatting.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped).frame(width: 590, height: 650)
            .onAppear { model.refreshPermission() }
    }
}

struct ShortcutRow: View {
    let title: String
    let command: Int
    @Bindable var hotkeys: Hotkeys
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack { Text(title).fontWeight(.medium); Spacer(); Text(hotkeys.shortcuts[command]?.label ?? "Disabled").foregroundStyle(.secondary) }
            HStack {
                ShortcutRecorder(hotkeys: hotkeys, command: command, title: title)
                    .frame(width: 190, height: 28)
                Button("Disable") { hotkeys.set(nil, for: command) }.disabled(hotkeys.shortcuts[command] == nil)
            }
        }
    }
}

struct ModelSetupView: View {
    @Bindable var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("On-device language models").font(.title2.bold())
            if let pair = model.setupPair {
                Text("\(Locale.current.localizedString(forIdentifier: pair.source) ?? pair.source) → \(Locale.current.localizedString(forIdentifier: pair.target) ?? pair.target)")
                Button(model.setupRunning ? "Preparing…" : "Prepare Models") {
                    model.setupReady = false; model.setupRunning = true
                    model.setupMessage = "Checking models. Confirm Apple’s download prompt if shown."
                    model.setupConfiguration = .init(source: .init(identifier: pair.source), target: .init(identifier: pair.target))
                }.disabled(model.setupRunning || pair.source == pair.target)
            }
            ScrollView { Text(model.setupMessage).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }.frame(minHeight: 90)
            if model.setupRunning { ProgressView().controlSize(.small) }
            if model.setupReady { Button("Retry Retained Request") { model.workflow.retry() }.buttonStyle(.borderedProminent).disabled(model.workflow.activeRequestID == nil) }
            Text("Setup does not replace text. To retry a replacement, return to the original app and selection, then choose Retry Last Request from the menu bar. The current context will be validated again.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(24).frame(width: 440)
        .translationTask(model.setupConfiguration, action: modelPreparationAction(model: model, generation: model.setupGeneration))
    }
}
