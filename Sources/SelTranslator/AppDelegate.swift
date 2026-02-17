import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let languageStore = TranslationLanguageStore()
    private let hotKeyStore = HotKeyStore()
    private let accessibilityService = AccessibilitySelectionService()
    private let clipboardService = ClipboardService()
    private let overlayController = OverlayController()
    private let translationService = TranslationService()

    private var statusBarController: StatusBarController?
    private var hotKeyManager: GlobalHotKeyManager?
    private var settingsWindowController: SettingsWindowController?
    private var modelOnboardingWindowController: TranslationModelOnboardingWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController(
            languageStore: languageStore,
            currentHotKey: { [weak self] in
                self?.hotKeyStore.hotKey ?? .default
            },
            onOpenSettings: { [weak self] in
                self?.openSettings()
            },
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

        applyHotKey(hotKeyStore.hotKey)

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

        let target = languageStore.selectedLanguage.localeLanguage
        do {
            let selection = try accessibilityService.captureSelection()
            Diagnostics.info(
                "Selection captured. editable=\(selection.isEditable) chars=\(selection.selectedText.count)"
            )
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
        } catch let selectionError as SelectionServiceError {
            Diagnostics.info(
                "AX selection capture failed (\(selectionError.localizedDescription)); trying clipboard fallback."
            )

            do {
                if try await translateFromClipboardFallback(targetLanguage: target) {
                    return
                }
            } catch {
                Diagnostics.error("Clipboard fallback failed: \(Diagnostics.describe(error))")
                handleTranslationError(error)
                return
            }

            handleTranslationError(selectionError)
        } catch {
            handleTranslationError(error)
        }
    }

    private func translateFromClipboardFallback(targetLanguage: Locale.Language) async throws -> Bool {
        guard let copiedText = await clipboardService.captureSelectedTextByCopyShortcut() else {
            Diagnostics.info("Clipboard fallback could not capture text.")
            return false
        }
        Diagnostics.info("Clipboard fallback captured chars=\(copiedText.count)")

        let translated = try await translationService.translate(
            copiedText,
            targetLanguage: targetLanguage
        )
        Diagnostics.info("Clipboard fallback translation completed. translatedChars=\(translated.count)")

        let copied = clipboardService.copy(text: translated)
        Diagnostics.info("Clipboard fallback write result: \(copied)")
        if copied {
            overlayController.show("Translated and copied to clipboard.", kind: .success)
        } else {
            overlayController.show("Translation done, but clipboard write failed.", kind: .error)
        }

        return true
    }

    private func handleTranslationError(_ error: Error) {
        Diagnostics.error("Translation failed: \(Diagnostics.describe(error))")
        if case let .languageModelsMissing(source, target, sourceLanguage, targetLanguage) = error as? TranslationServiceError {
            openModelOnboarding(
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                sourceDisplayName: source,
                targetDisplayName: target
            )
            overlayController.show(
                "Models are required for \(source) -> \(target).",
                kind: .error
            )
        } else {
            overlayController.show(error.localizedDescription, kind: .error)
        }
    }

    private func applyHotKey(_ hotKey: HotKeyConfiguration) {
        do {
            try hotKeyManager?.register(hotKey: hotKey)
            statusBarController?.refresh()
            Diagnostics.info("Hotkey registered: \(hotKey.displayString)")
        } catch {
            Diagnostics.error("Hotkey registration failed: \(Diagnostics.describe(error))")
            overlayController.show(
                "Unable to register hotkey: \(hotKey.displayString).",
                kind: .error
            )
        }
    }

    private func openSettings() {
        settingsWindowController = SettingsWindowController(
            languageStore: languageStore,
            hotKeyStore: hotKeyStore,
            onHotKeyApplied: { [weak self] hotKey in
                self?.applyHotKey(hotKey)
            },
            onSettingsChanged: { [weak self] in
                self?.statusBarController?.refresh()
            }
        )
        settingsWindowController?.show()
    }

    private func openModelOnboarding(
        sourceLanguage: Locale.Language,
        targetLanguage: Locale.Language,
        sourceDisplayName: String,
        targetDisplayName: String
    ) {
        modelOnboardingWindowController = TranslationModelOnboardingWindowController(
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            sourceDisplayName: sourceDisplayName,
            targetDisplayName: targetDisplayName,
            onReady: { [weak self] in
                self?.overlayController.show("Models ready. Retry translation.", kind: .success)
            }
        )
        modelOnboardingWindowController?.show()
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
