import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let languageStore = TranslationLanguageStore()
    private let accessibilityService = AccessibilitySelectionService()
    private let clipboardService = ClipboardService()
    private let overlayController = OverlayController()
    private let translationService = TranslationService()

    private var statusBarController: StatusBarController?
    private var hotKeyManager: GlobalHotKeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController(
            languageStore: languageStore,
            onOpenTranslationSettings: { [weak self] in
                self?.openTranslationSettings()
            },
            onOpenAccessibilitySettings: { [weak self] in
                self?.openAccessibilitySettings()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
        statusBarController?.install()

        hotKeyManager = GlobalHotKeyManager { [weak self] in
            guard let self else { return }
            Task {
                await self.handleTranslationTrigger()
            }
        }

        do {
            try hotKeyManager?.register()
        } catch {
            Diagnostics.error("Hotkey registration failed: \(Diagnostics.describe(error))")
            overlayController.show(
                "Unable to register hotkey.",
                kind: .error
            )
        }

        if !accessibilityService.hasPermission(prompt: false) {
            _ = accessibilityService.hasPermission(prompt: true)
            overlayController.show(
                "Enable Accessibility access to use selection translation.",
                kind: .error
            )
        }
    }

    private func handleTranslationTrigger() async {
        Diagnostics.info("Hotkey pressed; starting translation.")
        guard accessibilityService.hasPermission(prompt: true) else {
            overlayController.show(
                "Accessibility permission is required.",
                kind: .error
            )
            return
        }

        do {
            let selection = try accessibilityService.captureSelection()
            Diagnostics.info(
                "Selection captured. editable=\(selection.isEditable) chars=\(selection.selectedText.count)"
            )
            let target = languageStore.selectedLanguage.localeLanguage
            let translated = try await translationService.translate(
                selection.selectedText,
                targetLanguage: target
            )
            Diagnostics.info("Translation completed. translatedChars=\(translated.count)")

            let copied = clipboardService.copy(text: translated)
            Diagnostics.info("Clipboard write result: \(copied)")

            if selection.isEditable && accessibilityService.replaceSelectedText(in: selection, with: translated) {
                overlayController.show("Translated and replaced.", kind: .success)
                return
            }

            if copied {
                overlayController.show("Translated and copied to clipboard.", kind: .success)
            } else {
                overlayController.show("Translation done, but clipboard write failed.", kind: .error)
            }
        } catch {
            Diagnostics.error("Translation failed: \(Diagnostics.describe(error))")
            overlayController.show(error.localizedDescription, kind: .error)
        }
    }

    private func openTranslationSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.Localization-Settings.extension",
            "x-apple.systempreferences:com.apple.Localization-Settings.extension?Language"
        ]
        for raw in urls {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) {
                return
            }
        }

        if let settingsURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.systempreferences") {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: settingsURL, configuration: config) { _, _ in }
            overlayController.show(
                "Open: General > Language & Region > Translation Languages",
                kind: .error
            )
        }
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
            return
        }
        _ = NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefPane"))
    }
}
