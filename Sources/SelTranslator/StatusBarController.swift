import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let languageStore: TranslationLanguageStore
    private let onOpenTranslationSettings: () -> Void
    private let onOpenAccessibilitySettings: () -> Void
    private let onQuit: () -> Void
    private let statusItem: NSStatusItem

    init(
        languageStore: TranslationLanguageStore,
        onOpenTranslationSettings: @escaping () -> Void,
        onOpenAccessibilitySettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.languageStore = languageStore
        self.onOpenTranslationSettings = onOpenTranslationSettings
        self.onOpenAccessibilitySettings = onOpenAccessibilitySettings
        self.onQuit = onQuit
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
    }

    func install() {
        if let button = statusItem.button {
            button.title = "SelTr"
        }
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let current = NSMenuItem(
            title: "Target: \(languageStore.selectedLanguage.displayName)",
            action: nil,
            keyEquivalent: ""
        )
        current.isEnabled = false
        menu.addItem(current)

        let languagesItem = NSMenuItem(title: "Target Language", action: nil, keyEquivalent: "")
        let languageSubmenu = NSMenu(title: "Target Language")
        for language in languageStore.availableLanguages {
            let item = NSMenuItem(
                title: language.displayName,
                action: #selector(selectLanguage(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = language.id
            item.state = language.id == languageStore.selectedLanguage.id ? .on : .off
            languageSubmenu.addItem(item)
        }
        languagesItem.submenu = languageSubmenu
        menu.addItem(languagesItem)

        let hotkeyItem = NSMenuItem(title: "Hotkey: Control+Option+Command+T", action: nil, keyEquivalent: "")
        hotkeyItem.isEnabled = false
        menu.addItem(hotkeyItem)

        menu.addItem(.separator())

        let openTranslationSettingsItem = NSMenuItem(
            title: "Open Translation Settings",
            action: #selector(openTranslationSettings),
            keyEquivalent: ""
        )
        openTranslationSettingsItem.target = self
        menu.addItem(openTranslationSettingsItem)

        let accessibilityItem = NSMenuItem(
            title: "Open Accessibility Settings",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit SelTranslator", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc
    private func selectLanguage(_ sender: NSMenuItem) {
        guard
            let languageID = sender.representedObject as? String,
            let language = languageStore.availableLanguages.first(where: { $0.id == languageID })
        else {
            return
        }
        languageStore.selectedLanguage = language
        rebuildMenu()
    }

    @objc
    private func openTranslationSettings() {
        onOpenTranslationSettings()
    }

    @objc
    private func openAccessibilitySettings() {
        onOpenAccessibilitySettings()
    }

    @objc
    private func quit() {
        onQuit()
    }
}
