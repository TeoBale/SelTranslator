import AppKit
import Carbon
import SwiftUI

struct SettingsView: View {
    let languages: [TranslationLanguage]
    let selectedLanguageID: String
    let hotKey: HotKeyConfiguration
    let onLanguageChanged: (String) -> Void
    let onHotKeyChanged: (HotKeyConfiguration) -> Void
    let onResetDefaults: () -> Void

    @State private var localLanguageID: String
    @State private var localHotKey: HotKeyConfiguration
    @State private var isRecordingHotKey = false
    @State private var recorderMessage: String?
    @State private var keyEventMonitor: Any?

    init(
        languages: [TranslationLanguage],
        selectedLanguageID: String,
        hotKey: HotKeyConfiguration,
        onLanguageChanged: @escaping (String) -> Void,
        onHotKeyChanged: @escaping (HotKeyConfiguration) -> Void,
        onResetDefaults: @escaping () -> Void
    ) {
        self.languages = languages
        self.selectedLanguageID = selectedLanguageID
        self.hotKey = hotKey
        self.onLanguageChanged = onLanguageChanged
        self.onHotKeyChanged = onHotKeyChanged
        self.onResetDefaults = onResetDefaults

        _localLanguageID = State(initialValue: selectedLanguageID)
        _localHotKey = State(initialValue: hotKey)
    }

    private var shortcutSummary: String {
        isRecordingHotKey ? "Press shortcut" : hotKeyDisplayString
    }

    private var hotKeyDisplayString: String {
        var tokens: [String] = []
        if localHotKey.isControlEnabled { tokens.append("⌃") }
        if localHotKey.isOptionEnabled { tokens.append("⌥") }
        if localHotKey.isShiftEnabled { tokens.append("⇧") }
        if localHotKey.isCommandEnabled { tokens.append("⌘") }
        tokens.append(HotKeyConfiguration.keyOptions.first { $0.keyCode == localHotKey.keyCode }?.label ?? "Key")
        return tokens.joined()
    }

    var body: some View {
        VStack(spacing: 12) {
            Form {
                Section("Translation") {
                    LabeledContent("Target Language") {
                        Picker("Target Language", selection: $localLanguageID) {
                            ForEach(languages, id: \.id) { language in
                                Text(language.displayName).tag(language.id)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 240, alignment: .trailing)
                        .onChange(of: localLanguageID) { _, newValue in
                            onLanguageChanged(newValue)
                        }
                    }
                }

                Section("Keyboard") {
                    LabeledContent("Global Shortcut") {
                        Button {
                            recorderMessage = nil
                            isRecordingHotKey = true
                        } label: {
                            Text(shortcutSummary)
                                .font(.system(.body, design: .monospaced))
                                .frame(minWidth: 118)
                        }
                        .controlSize(.regular)
                        .help("Click, then press a shortcut such as ⌃⌥⌘T.")
                    }

                    if let recorderMessage {
                        Text(recorderMessage)
                            .font(.footnote)
                            .foregroundStyle(recorderMessage.hasPrefix("Use") ? .red : .secondary)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Restore Defaults") {
                    resetDefaults()
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(20)
        .frame(width: 560, height: 300)
        .onChange(of: isRecordingHotKey) { _, isRecording in
            updateKeyEventMonitor(isRecording: isRecording)
        }
        .onDisappear {
            updateKeyEventMonitor(isRecording: false)
        }
    }

    private func resetDefaults() {
        localLanguageID = TranslationLanguage.fallback.id
        localHotKey = .default
        recorderMessage = nil
        isRecordingHotKey = false
        onResetDefaults()
    }

    private func updateKeyEventMonitor(isRecording: Bool) {
        if let keyEventMonitor {
            NSEvent.removeMonitor(keyEventMonitor)
            self.keyEventMonitor = nil
        }

        guard isRecording else {
            return
        }

        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            recordHotKey(from: event)
            return nil
        }
    }

    private func recordHotKey(from event: NSEvent) {
        if Int(event.keyCode) == kVK_Escape {
            recorderMessage = nil
            isRecordingHotKey = false
            return
        }

        let recordedHotKey = HotKeyConfiguration(
            keyCode: UInt32(event.keyCode),
            modifiers: carbonModifiers(from: event.modifierFlags)
        )

        guard recordedHotKey.isValidGlobalShortcut else {
            recorderMessage = "Use A-Z or 0-9 with at least one modifier."
            NSSound.beep()
            return
        }

        localHotKey = recordedHotKey
        recorderMessage = nil
        isRecordingHotKey = false
        onHotKeyChanged(recordedHotKey)
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        return modifiers
    }
}
