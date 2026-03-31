import AppKit
import SwiftUI
import Observation

struct TranslatorPopupView: View {
    @Bindable var viewModel: TranslatorViewModel
    let onCopyAndClose: () -> Void
    @FocusState private var isEditorFocused: Bool

    private let columnSpacing: CGFloat = 12
    private let swapColumnWidth: CGFloat = 40
    private let sourceInset = EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
    private let pickerStatusHeight: CGFloat = 14

    init(viewModel: TranslatorViewModel, onCopyAndClose: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onCopyAndClose = onCopyAndClose
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThickMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.16), radius: 28, y: 16)

            VStack(alignment: .leading, spacing: 12) {
                utilityBar
                pickerRow
                contentRow
            }
            .padding(18)
        }
        .frame(width: 700, height: 338)
        .animation(.easeInOut(duration: 0.18), value: viewModel.isTranslating)
        .onAppear {
            requestEditorFocus()
        }
        .onChange(of: viewModel.focusToken) { _, _ in
            requestEditorFocus()
        }
        .onChange(of: viewModel.sourceText) { _, _ in
            viewModel.sourceTextDidChange()
        }
        .onChange(of: viewModel.selectedSourceLanguageID) { _, _ in
            viewModel.sourceLanguageDidChange()
        }
        .onChange(of: viewModel.selectedTargetLanguageID) { _, _ in
            viewModel.targetLanguageDidChange()
        }
        .background {
            shortcutBridge
        }
    }

    @ViewBuilder
    private var shortcutBridge: some View {
        Button("Copy And Close") {
            onCopyAndClose()
        }
        .keyboardShortcut("c", modifiers: [.command, .option])
        .disabled(viewModel.translatedText.isEmpty)
        .hidden()

        responderShortcut(
            title: "Cut",
            key: "x",
            modifiers: .command,
            action: #selector(NSText.cut(_:))
        )

        responderShortcut(
            title: "Copy",
            key: "c",
            modifiers: .command,
            action: #selector(NSText.copy(_:))
        )

        responderShortcut(
            title: "Paste",
            key: "v",
            modifiers: .command,
            action: #selector(NSText.paste(_:))
        )

        responderShortcut(
            title: "Select All",
            key: "a",
            modifiers: .command,
            action: #selector(NSText.selectAll(_:))
        )

        responderShortcut(
            title: "Undo",
            key: "z",
            modifiers: .command,
            action: Selector(("undo:"))
        )

        responderShortcut(
            title: "Redo",
            key: "z",
            modifiers: [.command, .shift],
            action: Selector(("redo:"))
        )
    }

    private func responderShortcut(
        title: String,
        key: KeyEquivalent,
        modifiers: EventModifiers,
        action: Selector
    ) -> some View {
        Button(title) {
            NSApp.sendAction(action, to: nil, from: nil)
        }
        .keyboardShortcut(key, modifiers: modifiers)
        .hidden()
    }

    private var utilityBar: some View {
        HStack(spacing: 10) {
            Text("Translate")
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            Spacer()

            Text("Esc closes")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            Button {
                viewModel.copyTranslation()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .background(
                Circle()
                    .fill(Color.white.opacity(0.08))
            )
            .disabled(viewModel.translatedText.isEmpty)
            .opacity(viewModel.translatedText.isEmpty ? 0.45 : 1)
        }
    }

    private var pickerRow: some View {
        HStack(alignment: .top, spacing: columnSpacing) {
            languagePickerCard(title: "From") {
                VStack(alignment: .leading, spacing: 4) {
                    Picker("From", selection: $viewModel.selectedSourceLanguageID) {
                        Text("Auto Detect").tag(TranslationLanguage.autoDetectID)
                        ForEach(viewModel.availableLanguages) { language in
                            Text(language.displayName).tag(language.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()

                    if let detectedSourceLabel = viewModel.detectedSourceLabel,
                       viewModel.selectedSourceLanguageID == TranslationLanguage.autoDetectID {
                        Text("Detected \(detectedSourceLabel)")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    } else {
                        Color.clear
                            .frame(height: pickerStatusHeight)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            Button {
                viewModel.swapLanguages()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .frame(width: swapColumnWidth)
            .disabled(!viewModel.canSwapLanguages)
            .opacity(viewModel.canSwapLanguages ? 1 : 0.4)
            .help("Swap source and target languages")

            languagePickerCard(title: "To") {
                VStack(alignment: .leading, spacing: 4) {
                    Picker("To", selection: $viewModel.selectedTargetLanguageID) {
                        ForEach(viewModel.availableLanguages) { language in
                            Text(language.displayName).tag(language.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()

                    Color.clear
                        .frame(height: pickerStatusHeight)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var contentRow: some View {
        HStack(alignment: .top, spacing: columnSpacing) {
            sourceEditor
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Color.clear
                .frame(width: swapColumnWidth)

            resultPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var sourceEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Source")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.black.opacity(0.10))

                TextEditor(text: $viewModel.sourceText)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .scrollContentBackground(.hidden)
                    .padding(sourceInset)
                    .focused($isEditorFocused)

                if viewModel.sourceText.isEmpty {
                    Text("Type or trigger the hotkey with text selected to prefill this field.")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(sourceInset)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var resultPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Translation")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Group {
                    if viewModel.isTranslating {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Translating…")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(.secondary)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else if let errorMessage = viewModel.errorMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Translation unavailable", systemImage: "exclamationmark.triangle")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                            Text(errorMessage)
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else if viewModel.translatedText.isEmpty {
                        Text("Your translation will appear here.")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    } else {
                        ScrollView {
                            Text(viewModel.translatedText)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func languagePickerCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    private func requestEditorFocus() {
        isEditorFocused = false
        DispatchQueue.main.async {
            isEditorFocused = true
        }
    }
}
