import Foundation
import SwiftUI
@preconcurrency import Translation

struct TranslationModelOnboardingView: View {
    enum OnboardingProgress {
        case idle
        case preparing
        case ready
        case failed(String)
    }

    let sourceLanguage: Locale.Language
    let targetLanguage: Locale.Language
    let sourceDisplayName: String
    let targetDisplayName: String
    let onReady: () -> Void

    @State private var progress: OnboardingProgress = .idle
    @State private var configuration: TranslationSession.Configuration?

    init(
        sourceLanguage: Locale.Language,
        targetLanguage: Locale.Language,
        sourceDisplayName: String,
        targetDisplayName: String,
        onReady: @escaping () -> Void
    ) {
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.sourceDisplayName = sourceDisplayName
        self.targetDisplayName = targetDisplayName
        self.onReady = onReady
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Install Translation Models")
                .font(.system(size: 18, weight: .semibold))

            Text("Required: \(sourceDisplayName) -> \(targetDisplayName)")
                .font(.system(size: 13))

            Text("Click download to let macOS request and install the language models needed by SelTranslator.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            statusView

            HStack {
                Spacer()
                Button("Download Models") {
                    progress = .preparing
                    configuration = nil
                    DispatchQueue.main.async {
                        configuration = TranslationSession.Configuration(
                            source: sourceLanguage,
                            target: targetLanguage
                        )
                    }
                }
                .disabled(isWorking)
            }
        }
        .padding(18)
        .frame(width: 460, height: 220)
        .translationTask(configuration) { @MainActor session in
            do {
                try await session.prepareTranslation()
                progress = .ready
                configuration = nil
                onReady()
            } catch {
                progress = .failed(error.localizedDescription)
                configuration = nil
            }
        }
    }

    private var isWorking: Bool {
        if case .preparing = progress {
            return true
        }
        return false
    }

    @ViewBuilder
    private var statusView: some View {
        switch progress {
        case .idle:
            Text("Status: waiting")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        case .preparing:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Requesting download and preparing translation...")
                    .font(.system(size: 12))
            }
        case .ready:
            Text("Models are ready. Retry translation.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.green)
        case .failed(let message):
            Text("Failed: \(message)")
                .font(.system(size: 12))
                .foregroundStyle(.red)
        }
    }
}
