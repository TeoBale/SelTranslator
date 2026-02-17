import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    private let languageStore: TranslationLanguageStore
    private let hotKeyStore: HotKeyStore
    private let onHotKeyApplied: (HotKeyConfiguration) -> Void
    private let onSettingsChanged: () -> Void

    init(
        languageStore: TranslationLanguageStore,
        hotKeyStore: HotKeyStore,
        onHotKeyApplied: @escaping (HotKeyConfiguration) -> Void,
        onSettingsChanged: @escaping () -> Void
    ) {
        self.languageStore = languageStore
        self.hotKeyStore = hotKeyStore
        self.onHotKeyApplied = onHotKeyApplied
        self.onSettingsChanged = onSettingsChanged

        let contentView = SettingsView(
            languages: languageStore.availableLanguages,
            selectedLanguageID: languageStore.selectedLanguage.id,
            hotKey: hotKeyStore.hotKey,
            onLanguageChanged: { [weak languageStore] languageID in
                guard
                    let languageStore,
                    let language = languageStore.availableLanguages.first(where: { $0.id == languageID })
                else { return }
                languageStore.selectedLanguage = language
                onSettingsChanged()
            },
            onHotKeyChanged: { [weak hotKeyStore] hotKey in
                hotKeyStore?.hotKey = hotKey
                onHotKeyApplied(hotKey)
                onSettingsChanged()
            },
            onResetDefaults: { [weak languageStore, weak hotKeyStore] in
                languageStore?.selectedLanguage = .fallback
                hotKeyStore?.hotKey = .default
                onHotKeyApplied(.default)
                onSettingsChanged()
            }
        )

        let hostingController = NSHostingController(rootView: contentView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "SelTranslator Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.level = .normal
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
