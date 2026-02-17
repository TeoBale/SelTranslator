import SwiftUI

struct SettingsView: View {
    let languages: [TranslationLanguage]
    let selectedLanguageID: String
    let hotKey: HotKeyConfiguration
    let onLanguageChanged: (String) -> Void
    let onHotKeyChanged: (HotKeyConfiguration) -> Void
    let onResetDefaults: () -> Void

    @State private var localLanguageID: String
    @State private var localKeyCode: UInt32
    @State private var useCommand: Bool
    @State private var useOption: Bool
    @State private var useControl: Bool
    @State private var useShift: Bool

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
        _localKeyCode = State(initialValue: hotKey.keyCode)
        _useCommand = State(initialValue: hotKey.isCommandEnabled)
        _useOption = State(initialValue: hotKey.isOptionEnabled)
        _useControl = State(initialValue: hotKey.isControlEnabled)
        _useShift = State(initialValue: hotKey.isShiftEnabled)
    }

    private var currentHotKey: HotKeyConfiguration {
        HotKeyConfiguration(keyCode: localKeyCode, modifiers: 0)
            .with(command: useCommand, option: useOption, control: useControl, shift: useShift)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SelTranslator Settings")
                .font(.system(size: 18, weight: .semibold))

            GroupBox("Translation") {
                Picker("Target Language", selection: $localLanguageID) {
                    ForEach(languages, id: \.id) { language in
                        Text(language.displayName).tag(language.id)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: localLanguageID) { _, newValue in
                    onLanguageChanged(newValue)
                }
            }

            GroupBox("Global Hotkey") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Key", selection: $localKeyCode) {
                        ForEach(HotKeyConfiguration.keyOptions) { option in
                            Text(option.label).tag(option.keyCode)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: localKeyCode) { _, _ in
                        applyHotKey()
                    }

                    HStack(spacing: 12) {
                        Toggle("Control", isOn: $useControl)
                        Toggle("Option", isOn: $useOption)
                        Toggle("Shift", isOn: $useShift)
                        Toggle("Command", isOn: $useCommand)
                    }
                    .toggleStyle(.checkbox)
                    .onChange(of: useControl) { _, _ in applyHotKey() }
                    .onChange(of: useOption) { _, _ in applyHotKey() }
                    .onChange(of: useShift) { _, _ in applyHotKey() }
                    .onChange(of: useCommand) { _, _ in applyHotKey() }

                    Text("Current shortcut: \(currentHotKey.displayString)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Spacer()
                Button("Reset Defaults") {
                    localLanguageID = TranslationLanguage.fallback.id
                    localKeyCode = HotKeyConfiguration.default.keyCode
                    useControl = HotKeyConfiguration.default.isControlEnabled
                    useOption = HotKeyConfiguration.default.isOptionEnabled
                    useShift = HotKeyConfiguration.default.isShiftEnabled
                    useCommand = HotKeyConfiguration.default.isCommandEnabled
                    onResetDefaults()
                }
            }
        }
        .padding(18)
        .frame(width: 460, height: 280)
    }

    private func applyHotKey() {
        let hotKey = currentHotKey
        onHotKeyChanged(hotKey)
    }
}
