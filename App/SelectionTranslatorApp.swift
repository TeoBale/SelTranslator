import AppKit
import SwiftUI
import TranslationCore

@main
struct SelectionTranslatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var model: AppModel!
    private var status: NSStatusItem!
    private var resultWindow: NSPanel?
    private var settingsWindow: NSWindow?
    private var setupWindow: NSWindow?
    private var lastPresentedRequest: UUID?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        model = AppModel()
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.image = NSImage(systemSymbolName: "character.bubble", accessibilityDescription: "SelectionTranslator")
        let menu = NSMenu()
        add("Translate Selection", action: #selector(selection), to: menu)
        add("Translate and Replace", action: #selector(replace), to: menu)
        add("Translate Clipboard", action: #selector(clipboard), to: menu)
        menu.addItem(.separator())
        add("Retry Last Request", action: #selector(retry), to: menu)
        add("Show Last Result", action: #selector(showResult), to: menu)
        add("Cancel Translation", action: #selector(cancel), to: menu)
        add("Settings…", action: #selector(settings), to: menu)
        menu.addItem(.separator())
        add("Quit SelectionTranslator", action: #selector(quit), to: menu)
        status.menu = menu
        model.onStateChange = { [weak self] state in self?.render(state) }
        model.openSettings = { [weak self] in self?.settings() }
        model.openSetup = { [weak self] in self?.showSetup() }
        if !UserDefaults.standard.bool(forKey: "didWelcome") {
            UserDefaults.standard.set(true, forKey: "didWelcome")
            settings()
        }
    }
    private func add(_ title: String, action: Selector, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self; menu.addItem(item)
    }
    @objc private func selection() { model.run(.selection) }
    @objc private func replace() { model.run(.replace) }
    @objc private func clipboard() { model.run(.clipboard) }
    @objc private func retry() { model.workflow.retry() }
    @objc private func cancel() { model.workflow.cancel() }
    @objc private func quit() { NSApp.terminate(nil) }
    private func render(_ state: WorkflowState) {
        switch state {
        case .capturing, .translating:
            status.button?.title = " …"
            status.button?.toolTip = "Translating — use Cancel Translation to stop"
            if case let .capturing(id) = state {
                status.button?.displayIfNeeded()
                Diagnostics.shared.mark(id, "acknowledgement_submitted")
            }
        default:
            status.button?.title = ""
            status.button?.toolTip = "SelectionTranslator"
        }
        switch state {
        case let .showingResult(result):
            if !result.wasReplaced { showResult() }
        case .failed, .awaitingModelSetup: showResult()
        default: break
        }
    }
    @objc private func showResult() {
        if resultWindow == nil {
            let panel = NSPanel(contentRect: .init(x: 0, y: 0, width: 480, height: 400), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            panel.title = "Translation"
            panel.contentViewController = NSHostingController(rootView: ResultView(model: model))
            panel.isReleasedWhenClosed = false
            panel.center(); resultWindow = panel
        }
        NSApp.activate(ignoringOtherApps: true)
        resultWindow?.makeKeyAndOrderFront(nil)
        if let id = model.workflow.activeRequestID, lastPresentedRequest != id {
            lastPresentedRequest = id
            Diagnostics.shared.mark(id, "result_presented")
        }
    }
    @objc private func settings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
            window.title = "SelectionTranslator Settings"; window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false; window.center(); settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true); settingsWindow?.makeKeyAndOrderFront(nil)
    }
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === setupWindow else { return }
        model.setupGeneration = UUID()
        model.setupConfiguration = nil
        model.setupRunning = false
        // Removing the hosting view cancels its SwiftUI translation task even though
        // the reusable window itself remains allocated.
        window.contentViewController = nil
    }
    private func showSetup() {
        if setupWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: ModelSetupView(model: model).id(model.setupGeneration)))
            window.title = "Model Setup"; window.isReleasedWhenClosed = false; window.delegate = self
            window.center(); setupWindow = window
        } else { setupWindow?.contentViewController = NSHostingController(rootView: ModelSetupView(model: model).id(model.setupGeneration)) }
        NSApp.activate(ignoringOtherApps: true); setupWindow?.makeKeyAndOrderFront(nil)
    }
}
