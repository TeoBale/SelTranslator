import AppKit
import SwiftUI

@MainActor
final class TranslationModelOnboardingWindowController: NSWindowController {
    init(
        sourceLanguage: Locale.Language,
        targetLanguage: Locale.Language,
        sourceDisplayName: String,
        targetDisplayName: String,
        onReady: @escaping () -> Void
    ) {
        let view = TranslationModelOnboardingView(
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            sourceDisplayName: sourceDisplayName,
            targetDisplayName: targetDisplayName,
            onReady: onReady
        )

        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Translation Setup"
        window.styleMask = NSWindow.StyleMask(arrayLiteral: .titled, .closable, .miniaturizable)
        window.level = NSWindow.Level.normal
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window else { return }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
