import AppKit
import SwiftUI

struct ShortcutRecorder: NSViewRepresentable {
    let hotkeys: Hotkeys
    let command: Int
    let title: String

    func makeNSView(context: Context) -> ShortcutRecordButton {
        let button = ShortcutRecordButton()
        button.bezelStyle = .rounded
        button.target = button
        button.action = #selector(ShortcutRecordButton.toggleRecording)
        updateNSView(button, context: context)
        return button
    }

    func updateNSView(_ button: ShortcutRecordButton, context: Context) {
        button.hotkeys = hotkeys
        button.command = command
        button.setAccessibilityLabel("Record shortcut for \(title)")
        button.refreshTitle()
    }

    static func dismantleNSView(_ button: ShortcutRecordButton, coordinator: ()) {
        button.stopRecording()
    }
}

// A focused native control captures key equivalents before menu commands and
// normal key events before text input or focus traversal.
final class ShortcutRecordButton: NSButton {
    weak var hotkeys: Hotkeys?
    var command = 0
    private(set) var isRecording = false
    private var mouseMonitor: Any?
    override var acceptsFirstResponder: Bool { true }

    @objc func toggleRecording() {
        if isRecording { stopRecording(); return }
        guard let window, window.makeFirstResponder(self), let hotkeys else { return }
        isRecording = true
        hotkeys.error = nil
        // Carbon consumes already-registered combinations. Route those presses
        // to this recorder instead of running a translation while recording.
        hotkeys.onRecordedShortcut = { [weak self] shortcut in self?.finish(shortcut) }
        NotificationCenter.default.addObserver(self, selector: #selector(stopRecording),
                                               name: NSWindow.didResignKeyNotification, object: window)
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            MainActor.assumeIsolated {
                if let self, event.window !== self.window || !self.bounds.contains(self.convert(event.locationInWindow, from: nil)) {
                    self.stopRecording()
                }
            }
            return event
        }
        refreshTitle()
    }

    @objc func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        hotkeys?.onRecordedShortcut = nil
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor); self.mouseMonitor = nil }
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: nil)
        refreshTitle()
    }

    func refreshTitle() {
        title = isRecording ? "Press shortcut…" : "Record Shortcut…"
        setAccessibilityValue(isRecording ? "Waiting for key combination" : hotkeys?.shortcuts[command]?.label ?? "Disabled")
    }

    override func resignFirstResponder() -> Bool {
        stopRecording()
        return super.resignFirstResponder()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        stopRecording()
        super.viewWillMove(toWindow: newWindow)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording, window?.isKeyWindow == true, window?.firstResponder === self else {
            return super.performKeyEquivalent(with: event)
        }
        capture(event)
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }
        capture(event)
    }

    private func capture(_ event: NSEvent) {
        guard !event.isARepeat else { return }
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if event.keyCode == 53, modifiers.isEmpty { stopRecording(); return }
        guard let shortcut = Shortcut(event: event) else { return }
        finish(shortcut)
    }

    private func finish(_ shortcut: Shortcut) {
        guard isRecording else { return }
        stopRecording()
        hotkeys?.set(shortcut, for: command)
        refreshTitle()
    }
}
